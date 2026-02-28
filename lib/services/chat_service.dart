import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class ChatService {
  static final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'us-central1');

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Ensure chat doc exists (so chat history can show it)
  static Future<void> ensureChatExists({
    required String uid,
    required String chatId,
  }) async {
    final ref = _db.collection("users").doc(uid).collection("chats").doc(chatId);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        "title": "New Chat",
        "lastMessage": "",
        "createdAt": FieldValue.serverTimestamp(),
        "updatedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  /// Create a new chat session and return chatId
  static Future<String> createChat({required String uid}) async {
    final ref = _db.collection("users").doc(uid).collection("chats").doc();
    await ref.set({
      "title": "New Chat",
      "lastMessage": "",
      "createdAt": FieldValue.serverTimestamp(),
      "updatedAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return ref.id;
  }

  /// Stream chat history list
  static Stream<QuerySnapshot<Map<String, dynamic>>> streamChats({
    required String uid,
    required Timestamp cutoff,
  }) {
    return _db
        .collection("users")
        .doc(uid)
        .collection("chats")
        .where("updatedAt", isGreaterThanOrEqualTo: cutoff)
        .orderBy("updatedAt", descending: true)
        .snapshots();
  }

  /// Delete chat + all messages
  ///
  /// ✅ Fixed: use batched deletes (faster + avoids slow loop on many docs)
  static Future<void> deleteChat({
    required String uid,
    required String chatId,
  }) async {
    final chatRef =
        _db.collection("users").doc(uid).collection("chats").doc(chatId);

    while (true) {
      final msgs = await chatRef
          .collection("messages")
          .orderBy("createdAt", descending: true)
          .limit(200)
          .get();

      if (msgs.docs.isEmpty) break;

      final batch = _db.batch();
      for (final d in msgs.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
    }

    await chatRef.delete();
  }

  /// Sends a message to backend.
  /// Backend decides: incident vs chat (NO keyword detection in Flutter).
  ///
  /// Optional:
  /// - imageBytes + imageMimeType
  static Future<String> sendChat(
    String message, {
    required String chatId,
    Uint8List? imageBytes,
    String? imageMimeType,
  }) async {
    final trimmed = message.trim();

    final finalText =
        (trimmed.isEmpty && imageBytes != null) ? "Report this image." : trimmed;

    if (finalText.isEmpty) return "Please type something.";

    final payload = <String, dynamic>{
      "message": finalText,
      "chatId": chatId,
    };

    if (imageBytes != null) {
      payload["imageBase64"] = base64Encode(imageBytes);
      final mime = (imageMimeType ?? "").trim();
      payload["imageMimeType"] = mime.isNotEmpty ? mime : "image/jpeg";
    }

    try {
      final callable = _functions.httpsCallable('processUserMessage');
      final res = await callable.call(payload);

      final data = res.data;
      final reply = (data?["reply"] as String?)?.trim();

      if (reply != null && reply.isNotEmpty) return reply;
      return "Sent ✅";
    } on FirebaseFunctionsException catch (e) {
      final code = e.code.toLowerCase();
      final msg = (e.message ?? "").toLowerCase();

      final looksLikeMissing =
          code.contains("not-found") || msg.contains("not found");

      // ✅ ONLY fallback when processUserMessage is missing / not deployed
      if (looksLikeMissing) {
        return _fallbackChatWithGemini(finalText, payload: payload);
      }

      // ❌ Do NOT fallback for other errors (prevents double writes)
      return "Chat error ❌\n${e.message ?? e.code}";
    } catch (e) {
      // ❌ Do NOT fallback on unknown errors either
      return "Chat error ❌\n$e";
    }
  }

  static Future<String> _fallbackChatWithGemini(
    String message, {
    Map<String, dynamic>? payload,
  }) async {
    try {
      final callable = _functions.httpsCallable('chatWithGemini');

      final res = await callable.call(
        payload ??
            <String, dynamic>{
              "message": message,
              "chatId": "default",
            },
      );

      return (res.data?["reply"] as String?)?.trim() ?? "No reply";
    } on FirebaseFunctionsException catch (e) {
      return "Chat error ❌\n${e.message ?? e.code}";
    } catch (e) {
      return "Chat error ❌\n$e";
    }
  }
}
