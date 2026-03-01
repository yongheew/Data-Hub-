import * as admin from "firebase-admin";
import { setGlobalOptions } from "firebase-functions/v2";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { VertexAI } from "@google-cloud/vertexai";

admin.initializeApp();
setGlobalOptions({ region: "us-central1" });

// =====================
// Vertex AI setup
// =====================
const PROJECT_ID = process.env.GCLOUD_PROJECT || "datahub-3c396";
const LOCATION = "us-central1";
const MODEL = "gemini-2.5-flash-lite";

const vertex = new VertexAI({ project: PROJECT_ID, location: LOCATION });
const model = vertex.getGenerativeModel({ model: MODEL });

// =====================
// Shared types/helpers
// =====================
type AiResult = {
  summary: string;
  category: string;
  severity: "low" | "medium" | "high";
  actions: string[];
};

type RouteDecision = {
  isIncident: boolean;
  confidence: number; // 0..1
  reason: string;
};

type InventoryItem = {
  id: string;
  name: string;
  brand: string;
  qty: number;
  minQty: number;
  maxQty: number | null; // allow missing
  unitPrice: number | null;
  supplier: string;
  keywords: string[];
};

function safeNum(x: any, fallback = 0): number {
  const n = typeof x === "number" ? x : Number(x);
  return Number.isFinite(n) ? n : fallback;
}

function safeStr(x: any, fallback = ""): string {
  return typeof x === "string" ? x : x == null ? fallback : String(x);
}

// Remove ```json fences and try to extract the first JSON object
function extractJsonObject(text: string): string | null {
  if (!text) return null;

  const cleaned = text.replace(/```json/gi, "```").replace(/```/g, "").trim();

  // Try direct parse first
  try {
    JSON.parse(cleaned);
    return cleaned;
  } catch {
    // continue
  }

  // Extract first {...} block (simple brace matching)
  const start = cleaned.indexOf("{");
  if (start < 0) return null;

  let depth = 0;
  for (let i = start; i < cleaned.length; i++) {
    const ch = cleaned[i];
    if (ch === "{") depth++;
    if (ch === "}") depth--;
    if (depth === 0) {
      const candidate = cleaned.slice(start, i + 1).trim();
      try {
        JSON.parse(candidate);
        return candidate;
      } catch {
        return null;
      }
    }
  }
  return null;
}

function tryParseJson(text: string): AiResult | null {
  try {
    const jsonStr = extractJsonObject(text);
    if (!jsonStr) return null;

    const parsed = JSON.parse(jsonStr);

    if (
      typeof parsed?.summary === "string" &&
      typeof parsed?.category === "string" &&
      (parsed?.severity === "low" ||
        parsed?.severity === "medium" ||
        parsed?.severity === "high") &&
      Array.isArray(parsed?.actions)
    ) {
      return {
        summary: parsed.summary.trim(),
        category: parsed.category.trim(),
        severity: parsed.severity,
        actions: parsed.actions.map((x: any) => String(x).trim()).filter(Boolean),
      };
    }
    return null;
  } catch {
    return null;
  }
}

function tryParseRouteDecision(text: string): RouteDecision | null {
  try {
    const jsonStr = extractJsonObject(text);
    if (!jsonStr) return null;

    const parsed = JSON.parse(jsonStr);
    const isIncident = parsed?.isIncident;
    const confidence = Number(parsed?.confidence);
    const reason = String(parsed?.reason ?? "");

    if (typeof isIncident === "boolean" && Number.isFinite(confidence)) {
      return {
        isIncident,
        confidence: Math.max(0, Math.min(1, confidence)),
        reason: reason.slice(0, 200),
      };
    }
    return null;
  } catch {
    return null;
  }
}

function isNextStepsQuestion(message: string) {
  const m = message.toLowerCase().trim();
  return (
    m === "what should i do" ||
    m === "what should i do?" ||
    m === "what can i do" ||
    m === "what can i do?" ||
    m.includes("what should i do") ||
    m.includes("what can i do") ||
    m.includes("next step") ||
    m.includes("next steps") ||
    m.includes("what now") ||
    m.includes("what now?") ||
    m.includes("what's next") ||
    m.includes("whats next") ||
    m.includes("action") ||
    m.includes("actions")
  );
}

// ✅ Prevent incident-followup from hijacking inventory/PO questions
function looksLikeInventoryQuestion(message: string) {
  const m = message.toLowerCase();
  return (
    m.includes("stock") ||
    m.includes("out of stock") ||
    m.includes("out-of-stock") ||
    m.includes("inventory") ||
    m.includes("supplier") ||
    m.includes("purchase") ||
    m.includes("po") ||
    m.includes("purchase order") ||
    m.includes("order") ||
    m.includes("unit price") ||
    m.includes("subtotal") ||
    m.includes("rm")
  );
}

// =====================
// Inventory helpers (NEW)
// =====================

// tokenize message to match keywords
function extractInventoryTokens(message: string): string[] {
  const raw = message
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, " ")
    .split(/\s+/)
    .map((x) => x.trim())
    .filter(Boolean);

  // remove very common noise words
  const stop = new Set([
    "the",
    "a",
    "an",
    "is",
    "are",
    "and",
    "or",
    "to",
    "of",
    "in",
    "on",
    "for",
    "with",
    "what",
    "how",
    "much",
    "many",
    "do",
    "i",
    "we",
    "you",
    "our",
    "my",
    "your",
    "out",
    "stock", // keep separate logic (we still keep tokens but not needed)
  ]);

  const tokens = raw.filter((t) => !stop.has(t));

  // also include 2-word phrases for better matching
  const bigrams: string[] = [];
  for (let i = 0; i < raw.length - 1; i++) {
    const a = raw[i];
    const b = raw[i + 1];
    if (a && b) {
      const phrase = `${a} ${b}`.trim();
      if (phrase.length >= 3) bigrams.push(phrase);
    }
  }

  // Keep unique, limit to avoid Firestore array-contains-any limit (max 10)
  const uniq: string[] = [];
  const seen = new Set<string>();
  for (const t of [...tokens, ...bigrams]) {
    if (!seen.has(t)) {
      seen.add(t);
      uniq.push(t);
    }
    if (uniq.length >= 10) break;
  }
  return uniq;
}

function parseInventoryDoc(docId: string, data: any): InventoryItem {
  // NOTE: you made a typo maxDty in the console screenshot.
  // We support both maxQty and maxDty.
  const maxQtyRaw =
    data?.maxQty !== undefined ? data.maxQty : data?.maxDty !== undefined ? data.maxDty : null;

  return {
    id: docId,
    name: safeStr(data?.name, docId),
    brand: safeStr(data?.brand, ""),
    qty: safeNum(data?.qty, 0),
    minQty: safeNum(data?.minQty, 0),
    maxQty: maxQtyRaw == null ? null : safeNum(maxQtyRaw, 0),
    unitPrice: data?.unitPrice == null ? null : safeNum(data.unitPrice, 0),
    supplier: safeStr(data?.supplier, ""),
    keywords: Array.isArray(data?.keywords)
      ? data.keywords.map((x: any) => safeStr(x, "")).filter(Boolean)
      : [],
  };
}

async function findInventoryMatches(message: string): Promise<InventoryItem[]> {
  const db = admin.firestore();
  const tokens = extractInventoryTokens(message);

  // If we somehow got no tokens, just return empty
  if (!tokens.length) return [];

  // Firestore array-contains-any supports up to 10 values
  const snap = await db
    .collection("inventory")
    .where("keywords", "array-contains-any", tokens)
    .limit(10)
    .get();

  if (snap.empty) return [];

  const items = snap.docs.map((d) => parseInventoryDoc(d.id, d.data()));

  // Rank: higher overlap = better
  const lowerMsg = message.toLowerCase();
  const score = (it: InventoryItem) => {
    let s = 0;
    for (const kw of it.keywords) {
      if (kw && lowerMsg.includes(kw.toLowerCase())) s += 2;
      if (tokens.includes(kw.toLowerCase())) s += 3;
    }
    if (it.name && lowerMsg.includes(it.name.toLowerCase())) s += 4;
    if (it.brand && lowerMsg.includes(it.brand.toLowerCase())) s += 2;
    return s;
  };

  items.sort((a, b) => score(b) - score(a));
  return items;
}

function formatMoneyRM(n: number | null): string {
  if (n == null || !Number.isFinite(n)) return "—";
  // simple formatting (no Intl needed)
  const fixed = n % 1 === 0 ? n.toFixed(0) : n.toFixed(2);
  return `RM${fixed}`;
}

function buildInventoryReply(message: string, items: InventoryItem[]): string {
  const lower = message.toLowerCase();
  const askOutOfStock = lower.includes("out of stock") || lower.includes("out-of-stock");

  // If multiple matches, present options
  if (items.length > 1) {
    const list = items
      .slice(0, 6)
      .map((it, idx) => {
        const qty = it.qty;
        const max = it.maxQty;
        const maxTxt = max == null ? "—" : String(max);
        return `${idx + 1}) ${it.name} (${it.brand || "—"}) — qty: ${qty}, max: ${maxTxt}`;
      })
      .join("\n");

    return (
      `I found multiple items that match. Which one do you mean?\n\n` +
      `${list}\n\n` +
      `Reply with the number (1-${Math.min(6, items.length)}).`
    );
  }

  const it = items[0];
  const qty = it.qty;
  const min = it.minQty;
  const max = it.maxQty; // may be null
  const supplier = it.supplier || "—";
  const unitPrice = formatMoneyRM(it.unitPrice);

  const isLow = qty <= min;
  const isZero = qty <= 0;

  // reorder target: if max exists, reorder to max; else reorder to min
  const target = max != null ? max : min;
  const reorderQty = Math.max(0, target - qty);

  let statusLine = `Stock for **${it.name}** (${it.brand || "—"}):`;
  let lines: string[] = [];
  lines.push(`• Current qty: **${qty}**`);
  lines.push(`• Min qty: **${min}**`);
  lines.push(`• Max qty: **${max == null ? "—" : max}**`);
  lines.push(`• Unit price: **${unitPrice}**`);
  lines.push(`• Supplier: **${supplier}**`);

  if (askOutOfStock || isZero) {
    lines.push(`\n✅ Status: **OUT OF STOCK**`);
  } else if (isLow) {
    lines.push(`\n⚠️ Status: **LOW STOCK**`);
  } else {
    lines.push(`\n✅ Status: **IN STOCK**`);
  }

  if (reorderQty > 0) {
    lines.push(`• Suggested reorder: **${reorderQty}** (to reach ${target})`);
  } else {
    lines.push(`• Suggested reorder: **0**`);
  }

  return `${statusLine}\n\n${lines.join("\n")}`;
}

// ✅ Only allow “incident follow-up” when the last assistant message was incident-related
async function wasLastAssistantIncident(
  uid: string,
  chatId: string
): Promise<boolean> {
  const messagesRef = messagesRefFor(uid, chatId);

  const snap = await messagesRef
    .where("role", "==", "assistant")
    .orderBy("createdAt", "desc")
    .limit(1)
    .get();

  if (snap.empty) return false;

  const m: any = snap.docs[0].data();
  const kind = String(m.kind ?? "");

  return (
    kind === "incident_confirmation" ||
    kind === "incident_ai_failed" ||
    kind === "incident_followup"
  );
}

// =====================
// Shared incident enrich logic
// =====================
async function enrichIncidentById(incidentId: string): Promise<AiResult> {
  const ref = admin.firestore().collection("incidents").doc(incidentId.trim());
  const snap = await ref.get();

  if (!snap.exists) {
    throw new HttpsError("not-found", "Incident not found");
  }

  const data = snap.data() as any;
  const rawText = (data.rawText ?? "").toString().trim();

  if (!rawText) {
    throw new HttpsError("failed-precondition", "Incident rawText is empty");
  }

  // If already enriched, return existing ai
  if (data.ai?.summary && data.ai?.severity && data.ai?.category) {
    const sev = String(data.ai.severity ?? "").toLowerCase();
    const severity =
      sev === "low" || sev === "medium" || sev === "high"
        ? (sev as "low" | "medium" | "high")
        : "medium";

    return {
      summary: String(data.ai.summary ?? "").trim(),
      category: String(data.ai.category ?? "").trim(),
      severity,
      actions: Array.isArray(data.ai.actions)
        ? data.ai.actions.map((x: any) => String(x).trim()).filter(Boolean)
        : [],
    };
  }

  const prompt = `
You are an assistant that classifies facility incident reports.

Return ONLY valid JSON (no markdown, no backticks) with EXACT keys:
summary (string),
category (string),
severity ("low"|"medium"|"high"),
actions (array of short strings).

Incident text:
"${rawText}"
`.trim();

  const resp = await model.generateContent({
    contents: [{ role: "user", parts: [{ text: prompt }] }],
    generationConfig: { temperature: 0.2, maxOutputTokens: 512 },
  });

  const text =
    resp.response.candidates?.[0]?.content?.parts
      ?.map((p: any) => (p.text ? p.text : ""))
      .join("") ?? "";

  const parsed = tryParseJson(text);

  const ai: AiResult = parsed ?? {
    summary: (text || "No summary generated").slice(0, 200),
    category: "unknown",
    severity: "medium",
    actions: [],
  };

  await ref.update({
    status: "ai_done",
    ai: {
      ...ai,
      model: MODEL,
      processedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
  });

  return ai;
}

// =====================
// Internal: shared refs
// =====================
function messagesRefFor(uid: string, chatId: string) {
  const db = admin.firestore();
  return db
    .collection("users")
    .doc(uid)
    .collection("chats")
    .doc(chatId)
    .collection("messages");
}

// =====================
// Chat metadata helpers (for Chat History UI)
// =====================
function chatDocRef(uid: string, chatId: string) {
  const db = admin.firestore();
  return db.collection("users").doc(uid).collection("chats").doc(chatId);
}

async function ensureChatDoc(uid: string, chatId: string) {
  const ref = chatDocRef(uid, chatId);
  const snap = await ref.get();
  if (!snap.exists) {
    await ref.set(
      {
        title: "New Chat",
        lastMessage: "",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  }
}

function autoTitleFromText(text: string) {
  const t = String(text ?? "").trim();
  if (!t) return "New Chat";
  return t.length > 28 ? `${t.slice(0, 28)}...` : t;
}

async function updateChatMeta(params: {
  uid: string;
  chatId: string;
  lastMessage?: string;
  maybeTitleFromFirstUser?: string;
}) {
  const { uid, chatId, lastMessage, maybeTitleFromFirstUser } = params;
  const ref = chatDocRef(uid, chatId);

  await ensureChatDoc(uid, chatId);

  const snap = await ref.get();
  const data: any = snap.data() ?? {};
  const currentTitle = String(data.title ?? "New Chat");

  const updates: any = {
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  if (typeof lastMessage === "string") {
    updates.lastMessage = lastMessage.trim();
  }

  if (
    maybeTitleFromFirstUser &&
    (currentTitle === "New Chat" || !currentTitle.trim())
  ) {
    updates.title = autoTitleFromText(maybeTitleFromFirstUser);
  }

  await ref.set(updates, { merge: true });
}

// =====================
// store / load last incident per chat
// =====================
async function setLastIncidentId(uid: string, chatId: string, incidentId: string) {
  const db = admin.firestore();
  await db
    .collection("users")
    .doc(uid)
    .collection("chats")
    .doc(chatId)
    .set(
      {
        lastIncidentId: incidentId,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

  // keep chat list updated too
  await ensureChatDoc(uid, chatId);
}

async function getLastIncidentId(uid: string, chatId: string): Promise<string | null> {
  const db = admin.firestore();
  const snap = await db
    .collection("users")
    .doc(uid)
    .collection("chats")
    .doc(chatId)
    .get();

  const id = snap.data()?.lastIncidentId;
  return typeof id === "string" && id.trim() ? id.trim() : null;
}

// =====================
// Route decision (incident vs chat)
// =====================
async function decideRoute(message: string, hasImage: boolean): Promise<RouteDecision> {
  const prompt = `
You are a router for an app that supports BOTH:
(1) Facility incident reporting (maintenance/safety/security issues to log)
(2) Normal chat questions of ANY kind (inventory, purchasing, school, tech, etc.)

Classify the input as:
- INCIDENT REPORT (log it) ONLY if it is a real facility issue that should be tracked.
- Otherwise NORMAL CHAT.

Return ONLY JSON:
{
  "isIncident": true/false,
  "confidence": 0.0-1.0,
  "reason": "short reason"
}

Input:
"${message}"

Attached image: ${hasImage ? "YES" : "NO"}
`.trim();

  const resp = await model.generateContent({
    contents: [{ role: "user", parts: [{ text: prompt }] }],
    generationConfig: { temperature: 0.0, maxOutputTokens: 128 },
  });

  const text =
    resp.response.candidates?.[0]?.content?.parts
      ?.map((p: any) => (p.text ? p.text : ""))
      .join("") ?? "";

  const parsed = tryParseRouteDecision(text);
  return parsed ?? { isIncident: false, confidence: 0.0, reason: "parse_failed" };
}

// =====================
// Create incident + write chat messages
// =====================
async function createIncidentInternal(params: {
  uid: string;
  chatId: string;
  rawText: string;
}): Promise<{ incidentId: string; reply: string; aiFailed?: boolean }> {
  const { uid, chatId, rawText } = params;
  const db = admin.firestore();
  const messagesRef = messagesRefFor(uid, chatId);

  await ensureChatDoc(uid, chatId);

  // Save user message
  await messagesRef.add({
    role: "user",
    text: rawText,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    kind: "incident_user_text",
  });

  await updateChatMeta({
    uid,
    chatId,
    lastMessage: rawText,
    maybeTitleFromFirstUser: rawText,
  });

  // Create incident
  const docRef = await db.collection("incidents").add({
    rawText,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    createdBy: uid,
    status: "ai_running",
  });

  try {
    const ai = await enrichIncidentById(docRef.id);
    await setLastIncidentId(uid, chatId, docRef.id);

    const steps =
      ai.actions && ai.actions.length
        ? ai.actions
            .slice(0, 6)
            .map((a) => `• ${a}`)
            .join("\n")
        : "";

    const reply =
      `Incident logged ✅\n\n` +
      `Summary: ${ai.summary}\n` +
      `Severity: ${ai.severity}\n` +
      `Category: ${ai.category}` +
      (steps ? `\n\nRecommended actions:\n${steps}` : "") +
      `\n`;

    await messagesRef.add({
      role: "assistant",
      text: reply.trim(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      kind: "incident_confirmation",
      incidentId: docRef.id,
      ai: {
        severity: ai.severity,
        category: ai.category,
        summary: ai.summary,
        actions: ai.actions,
      },
    });

    await updateChatMeta({
      uid,
      chatId,
      lastMessage: reply.trim(),
    });

    return { incidentId: docRef.id, reply: reply.trim() };
  } catch (err: any) {
    await docRef.update({
      status: "ai_error",
      aiError: String(err?.message ?? err),
      aiErrorAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const reply =
      `Incident saved ⚠️\n\n` +
      `AI analysis failed.\n` +
      `Reason: ${String(err?.message ?? err).slice(0, 200)}`;

    await messagesRef.add({
      role: "assistant",
      text: reply.trim(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      kind: "incident_ai_failed",
      incidentId: docRef.id,
    });

    await updateChatMeta({
      uid,
      chatId,
      lastMessage: reply.trim(),
    });

    return { incidentId: docRef.id, reply: reply.trim(), aiFailed: true };
  }
}

// =====================
// Follow-up answer generator (no Gemini echo)
// =====================
function buildNextStepsReply(ai: any) {
  const summary = String(ai?.summary ?? "").trim();
  const severity = String(ai?.severity ?? "").trim();
  const category = String(ai?.category ?? "").trim();

  const actionsArr: string[] = Array.isArray(ai?.actions)
    ? ai.actions.map((x: any) => String(x).trim()).filter(Boolean)
    : [];

  const steps =
    actionsArr.length > 0
      ? actionsArr.map((a) => `• ${a}`).join("\n")
      : "• Inspect the area and confirm what’s affected.\n• Take a photo if helpful.\n• If unsafe, block the area and escalate to maintenance.\n• Report exact location and urgency.";

  let reply = `Here’s what you should do next:\n\n${steps}`;

  if (summary) reply += `\n\nNotes: ${summary}`;
  if (severity || category) {
    reply += `\n\n${severity ? `Severity: ${severity}` : ""}${
      severity && category ? " • " : ""
    }${category ? `Category: ${category}` : ""}`;
  }

  return reply.trim();
}

// =====================
// Chat with Gemini + write chat messages
// Supports optional image
// =====================
async function chatWithGeminiInternal(params: {
  uid: string;
  chatId: string;
  message: string;
  imageBase64?: string;
  imageMimeType?: string;
}): Promise<{ reply: string }> {
  const { uid, chatId, message, imageBase64, imageMimeType } = params;
  const db = admin.firestore();
  const messagesRef = messagesRefFor(uid, chatId);

  await ensureChatDoc(uid, chatId);

  // (1) Save user message
  await messagesRef.add({
    role: "user",
    text: message.trim(),
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    kind: imageBase64 ? "user_with_image" : "user_text",
  });

  await updateChatMeta({
    uid,
    chatId,
    lastMessage: message.trim(),
    maybeTitleFromFirstUser: message.trim(),
  });

  // (2) Load last incident (for follow-ups)
  const lastIncidentId = await getLastIncidentId(uid, chatId);

  // ✅ Only do incident follow-up when we are actually in incident context
  if (
    lastIncidentId &&
    isNextStepsQuestion(message) &&
    !looksLikeInventoryQuestion(message) &&
    (await wasLastAssistantIncident(uid, chatId))
  ) {
    const inc = await db.collection("incidents").doc(lastIncidentId).get();
    if (inc.exists) {
      const d: any = inc.data();
      const ai = d.ai ?? {};

      const reply = buildNextStepsReply(ai);

      await messagesRef.add({
        role: "assistant",
        text: reply,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        kind: "incident_followup",
        incidentId: lastIncidentId,
        ai: {
          severity: String(ai.severity ?? ""),
          category: String(ai.category ?? ""),
          summary: String(ai.summary ?? ""),
          actions: Array.isArray(ai.actions) ? ai.actions : [],
        },
      });

      await updateChatMeta({ uid, chatId, lastMessage: reply });

      return { reply };
    }
  }

  // (3) SMALL private context
  let privateContext = "";
  if (lastIncidentId) {
    const inc = await db.collection("incidents").doc(lastIncidentId).get();
    if (inc.exists) {
      const d: any = inc.data();
      const ai = d.ai ?? {};
      const raw = String(d.rawText ?? "").slice(0, 160);

      const sev = String(ai.severity ?? d.severity ?? "");
      const cat = String(ai.category ?? "");
      const sum = String(ai.summary ?? "").slice(0, 160);

      privateContext =
        `PRIVATE CONTEXT (never quote): ` +
        `Last incident: "${raw}". ` +
        (sev ? `Severity=${sev}. ` : "") +
        (cat ? `Category=${cat}. ` : "") +
        (sum ? `Summary="${sum}".` : "");
    }
  }

  // (4) Chat history
  const msgSnap = await messagesRef.orderBy("createdAt", "desc").limit(10).get();
  const history = msgSnap.docs
    .map((d) => d.data() as any)
    .reverse()
    .map((m) => ({
      role: m.role === "user" ? "user" : "model",
      parts: [{ text: String(m.text ?? "") }],
    }));

  // ✅ General-purpose system prompt
  const systemPrompt = `
You are DataHub Assistant.

You can help with ANY topic (general questions, inventory/purchasing, school, tech, etc.)
and you also support facility incident reporting when relevant.

Rules:
- Reply like ChatGPT: direct, helpful, and well-structured.
- NEVER output any "PRIVATE CONTEXT" text.
- Never repeat internal context verbatim.
- Never say things like “this does not correspond to facility operations incidents”.
  If it’s a normal question, just answer it.
- Give the answer first. Use short bullets for steps.
- If info is missing, ask ONLY 1 short question.

If an image is attached:
- Briefly describe what you see.
- Then give best next steps.
`.trim();

  const userParts: any[] = [{ text: message.trim() }];

  if (imageBase64) {
    userParts.push({
      inlineData: {
        mimeType: imageMimeType || "image/jpeg",
        data: imageBase64,
      },
    });
  }

  const systemPlusContext = privateContext
    ? `${systemPrompt}\n\n${privateContext}`
    : systemPrompt;

  const contents = [
    { role: "user", parts: [{ text: systemPlusContext }] },
    ...history,
    { role: "user", parts: userParts },
  ];

  // (7) Call Gemini
  const resp = await model.generateContent({
    contents,
    generationConfig: { temperature: 0.35, maxOutputTokens: 512 },
  });

  let reply =
    resp.response.candidates?.[0]?.content?.parts
      ?.map((p: any) => (p.text ? p.text : ""))
      .join("")
      .trim() || "Sorry, I couldn't generate a reply.";

  // ✅ HARD BLOCK: never allow the old “facility incidents” rejection message
  const low = reply.toLowerCase();
  const bad1 = "does not correspond to any logged facility operations incidents";
  const bad2 = "clarify what facility operations issue";
  if (low.includes(bad1) || low.includes(bad2)) {
    if (looksLikeInventoryQuestion(message)) {
      reply =
        `Tell me the product name and I’ll check stock from your database.`;
    } else {
      reply =
        `Sure — tell me what you want to do and what info you already have, and I’ll help you step-by-step.`;
    }
  }

  // (8) Save assistant reply
  await messagesRef.add({
    role: "assistant",
    text: reply,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    kind: "chat_reply",
  });

  await updateChatMeta({ uid, chatId, lastMessage: reply });

  return { reply };
}

// =====================
// Ensure User Profile
// =====================
export const ensureUserProfile = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Please login first.");
  }

  const uid = request.auth.uid;
  const email = request.auth.token.email ?? null;

  const name =
    typeof request.data?.name === "string" ? request.data.name.trim() : null;
  const gender =
    typeof request.data?.gender === "string" ? request.data.gender.trim() : null;

  const birthDateIso =
    typeof request.data?.birthDate === "string" ? request.data.birthDate : null;

  const birthDate = birthDateIso
    ? admin.firestore.Timestamp.fromDate(new Date(birthDateIso))
    : null;

  const ref = admin.firestore().collection("users").doc(uid);

  const existing = await ref.get();
  const createdAtIfNew = existing.exists
    ? {}
    : { createdAt: admin.firestore.FieldValue.serverTimestamp() };

  await ref.set(
    {
      email,
      ...(name ? { name } : {}),
      ...(gender ? { gender } : {}),
      ...(birthDate ? { birthDate } : {}),
      ...createdAtIfNew,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  return { ok: true, uid };
});

// =====================
// Incident AI Enrichment
// =====================
export const aiEnrichIncident = onCall(async (request) => {
  try {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Please login first.");
    }

    const incidentId = request.data?.incidentId;
    if (typeof incidentId !== "string" || incidentId.trim() === "") {
      throw new HttpsError("invalid-argument", "Missing incidentId");
    }

    const ai = await enrichIncidentById(incidentId.trim());
    return { ok: true, ai };
  } catch (err: any) {
    console.error("aiEnrichIncident error:", err);
    if (err instanceof HttpsError) throw err;
    throw new HttpsError("internal", err?.message ?? "Unknown server error");
  }
});

// =====================
// Create Incident (EXPORTED)
// =====================
export const createIncident = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Please login first.");
  }

  const rawText =
    typeof request.data?.rawText === "string" ? request.data.rawText.trim() : "";

  if (!rawText) {
    throw new HttpsError("invalid-argument", "Missing rawText");
  }

  const uid = request.auth.uid;
  const chatId =
    typeof request.data?.chatId === "string" && request.data.chatId.trim()
      ? request.data.chatId.trim()
      : "default";

  return await createIncidentInternal({ uid, chatId, rawText });
});

// =====================
// Chatbot (EXPORTED)
// =====================
export const chatWithGemini = onCall(async (request) => {
  try {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Please login first.");
    }

    const uid = request.auth.uid;
    const chatId = request.data?.chatId;
    const message = request.data?.message;

    const imageBase64 =
      typeof request.data?.imageBase64 === "string"
        ? request.data.imageBase64
        : undefined;

    const imageMimeType =
      typeof request.data?.imageMimeType === "string"
        ? request.data.imageMimeType
        : undefined;

    if (typeof chatId !== "string" || chatId.trim() === "") {
      throw new HttpsError("invalid-argument", "Missing chatId");
    }
    if (typeof message !== "string" || message.trim() === "") {
      throw new HttpsError("invalid-argument", "Missing message");
    }

    return await chatWithGeminiInternal({
      uid,
      chatId: chatId.trim(),
      message: message.trim(),
      imageBase64,
      imageMimeType,
    });
  } catch (err: any) {
    console.error("chatWithGemini error:", err);
    if (err instanceof HttpsError) throw err;
    throw new HttpsError("internal", err?.message ?? "Unknown server error");
  }
});

// =====================
// One entry point for ALL user messages
// Supports optional image
// =====================
export const processUserMessage = onCall(async (request) => {
  try {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Please login first.");
    }

    const uid = request.auth.uid;

    const chatId =
      typeof request.data?.chatId === "string" && request.data.chatId.trim()
        ? request.data.chatId.trim()
        : "default";

    const message =
      typeof request.data?.message === "string" ? request.data.message.trim() : "";

    const imageBase64 =
      typeof request.data?.imageBase64 === "string"
        ? request.data.imageBase64
        : undefined;

    const imageMimeType =
      typeof request.data?.imageMimeType === "string"
        ? request.data.imageMimeType
        : undefined;

    if (!message) {
      throw new HttpsError("invalid-argument", "Missing message");
    }

    await ensureChatDoc(uid, chatId);

    const hasImage = !!imageBase64;

    // ✅ INVENTORY FAST-PATH (NEW)
    // If it looks like inventory and there is NO image, answer from Firestore first.
    if (looksLikeInventoryQuestion(message) && !hasImage) {
      const items = await findInventoryMatches(message);

      if (items.length > 0) {
        const reply = buildInventoryReply(message, items);

        const messagesRef = messagesRefFor(uid, chatId);

        // Save user msg (as normal chat)
        await messagesRef.add({
          role: "user",
          text: message.trim(),
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          kind: "user_text",
        });

        await updateChatMeta({
          uid,
          chatId,
          lastMessage: message.trim(),
          maybeTitleFromFirstUser: message.trim(),
        });

        // Save assistant reply
        await messagesRef.add({
          role: "assistant",
          text: reply,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          kind: "inventory_reply",
        });

        await updateChatMeta({ uid, chatId, lastMessage: reply });

        return {
          ok: true,
          type: "inventory",
          reply,
        };
      }

      // If looks like inventory but no match found, ask one question
      const ask =
        `I couldn’t find that item in your inventory database.\n\n` +
        `Try: add keywords for it in /inventory, or tell me the exact product name.`;

      const messagesRef = messagesRefFor(uid, chatId);

      await messagesRef.add({
        role: "user",
        text: message.trim(),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        kind: "user_text",
      });

      await updateChatMeta({
        uid,
        chatId,
        lastMessage: message.trim(),
        maybeTitleFromFirstUser: message.trim(),
      });

      await messagesRef.add({
        role: "assistant",
        text: ask,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        kind: "inventory_reply",
      });

      await updateChatMeta({ uid, chatId, lastMessage: ask });

      return { ok: true, type: "inventory", reply: ask };
    }

    // 1) Decide route (incident vs chat)
    const decision = await decideRoute(message, hasImage);

    // 2) Threshold (image slightly increases chance it’s incident)
    const threshold = hasImage ? 0.45 : 0.55;
    const treatAsIncident =
      decision.isIncident && decision.confidence >= threshold;

    if (treatAsIncident) {
      const out = await createIncidentInternal({
        uid,
        chatId,
        rawText: message,
      });

      return {
        ok: true,
        type: "incident",
        incidentId: out.incidentId,
        reply: out.reply,
        confidence: decision.confidence,
        reason: decision.reason,
      };
    }

    const out = await chatWithGeminiInternal({
      uid,
      chatId,
      message,
      imageBase64,
      imageMimeType,
    });

    return {
      ok: true,
      type: "chat",
      reply: out.reply,
      confidence: decision.confidence,
      reason: decision.reason,
    };
  } catch (err: any) {
    console.error("processUserMessage error:", err);
    if (err instanceof HttpsError) throw err;
    throw new HttpsError("internal", err?.message ?? "Unknown server error");
  }
});
