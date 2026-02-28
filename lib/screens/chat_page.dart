import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:http/http.dart' as http;

import '../services/chat_service.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  static const String _chatId = "default";

  final TextEditingController _messageCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final String flaskUrl = "http://corebrain.duckdns.org:5050/process_incident";

  bool _sending = false;

  // Image
  final ImagePicker _picker = ImagePicker();
  XFile? _pickedImage;

  // Speech
  late stt.SpeechToText _speech;
  bool _speechReady = false;
  bool _listening = false;

  User? get _user => FirebaseAuth.instance.currentUser;

  CollectionReference<Map<String, dynamic>> _messagesRef(String uid) {
    return FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .collection("chats")
        .doc(_chatId)
        .collection("messages");
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _messagesStream(String uid) {
    return _messagesRef(
      uid,
    ).orderBy("createdAt", descending: false).snapshots();
  }

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      final ok = await _speech.initialize();
      if (mounted) setState(() => _speechReady = ok);
    } catch (_) {
      if (mounted) setState(() => _speechReady = false);
    }
  }

  Future<void> _toggleMic() async {
    if (!_speechReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Microphone not available on this device/browser."),
        ),
      );
      return;
    }

    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }

    final started = await _speech.listen(
      onResult: (res) {
        if (!mounted) return;

        // Put dictated text into input (append)
        final current = _messageCtrl.text.trim();
        final newText = res.recognizedWords.trim();
        if (newText.isEmpty) return;

        _messageCtrl.text = current.isEmpty ? newText : "$current $newText";
        _messageCtrl.selection = TextSelection.fromPosition(
          TextPosition(offset: _messageCtrl.text.length),
        );
      },
      listenMode: stt.ListenMode.dictation,
      partialResults: true,
    );

    if (mounted) setState(() => _listening = started);
  }

  Future<void> _pickImage() async {
    try {
      final img = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
      );
      if (!mounted) return;
      setState(() => _pickedImage = img);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Image pick failed: $e")));
    }
  }

  String _guessMimeType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith(".png")) return "image/png";
    if (lower.endsWith(".webp")) return "image/webp";
    return "image/jpeg";
  }

  Future<void> _send() async {
    if (_sending) return;

    final u = _user;
    if (u == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please login first.")));
      return;
    }

    final text = _messageCtrl.text.trim();
    final hasImage = _pickedImage != null;

    if (text.isEmpty && !hasImage) return;

    setState(() => _sending = true);

    // Clear input UI immediately (like ChatGPT)
    _messageCtrl.clear();

    // Snapshot the image, then clear preview immediately
    final imgToSend = _pickedImage;
    setState(() => _pickedImage = null);

    try {
      Uint8List? imageBytes;
      String? imageMimeType;

      if (imgToSend != null) {
        imageBytes = await imgToSend.readAsBytes();
        imageMimeType = _guessMimeType(imgToSend.name);
      }

      // ✅ Send to backend (backend writes user+assistant)
      // Save user message to Firestore
      await _messagesRef(u.uid).add({
        "role": "user",
        "text": text,
        "createdAt": FieldValue.serverTimestamp(),
      });

      // Send HTTP request to AI backend (Plan 1 style)
      final response = await http.post(
        Uri.parse(flaskUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_name": u.displayName ?? u.email ?? "User",
          "issue_text": text,
        }),
      );

      String aiReply = "No response from AI.";
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        aiReply = data['user_message'] ?? aiReply;
      } else {
        aiReply = "Error: ${response.statusCode}";
      }

      // Save AI response to Firestore
      await _messagesRef(u.uid).add({
        "role": "assistant",
        "text": aiReply,
        "createdAt": FieldValue.serverTimestamp(),
      });

      await Future.delayed(const Duration(milliseconds: 250));
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Send failed: $e")));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  bool _isIncidentKind(String kind) {
    return kind == "incident_confirmation" ||
        kind == "incident_ai_failed" ||
        kind == "incident_followup";
  }

  void _scrollToBottom() {
    if (!_scrollCtrl.hasClients) return;
    _scrollCtrl.animateTo(
      _scrollCtrl.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  bool _isPermissionDenied(Object? error) {
    if (error is FirebaseException) return error.code == "permission-denied";
    final msg = error.toString();
    return msg.contains("permission-denied") ||
        msg.contains("Missing or insufficient permissions");
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    _scrollCtrl.dispose();
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final u = _user;

    return Scaffold(
      backgroundColor: const Color(0xFF2F436E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2F436E),
        foregroundColor: Colors.white,
        title: const Text("Chat"),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: u == null
                  ? const Center(
                      child: Text(
                        "Please login first.",
                        style: TextStyle(color: Colors.white),
                      ),
                    )
                  : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _messagesStream(u.uid),
                      builder: (context, snap) {
                        if (snap.hasError) {
                          final isPermission = _isPermissionDenied(snap.error);
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isPermission
                                        ? Icons.lock_outline
                                        : Icons.error_outline,
                                    color: Colors.white70,
                                    size: 46,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    isPermission
                                        ? "No access to chat data"
                                        : "Something went wrong",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    isPermission
                                        ? "This is usually Firestore rules.\nPublish the rules, then restart the app."
                                        : "Please try again.",
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  ElevatedButton(
                                    onPressed: () => setState(() {}),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: const Color(0xFF2F436E),
                                    ),
                                    child: const Text("Retry"),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        if (!snap.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          );
                        }

                        final docs = snap.data!.docs;
                        if (docs.isEmpty) {
                          return const Center(
                            child: Text(
                              "Ask AI anything...",
                              style: TextStyle(color: Colors.white70),
                            ),
                          );
                        }

                        WidgetsBinding.instance.addPostFrameCallback(
                          (_) => _scrollToBottom(),
                        );

                        return ListView.builder(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 20,
                          ),
                          itemCount: docs.length,
                          itemBuilder: (context, i) {
                            final m = docs[i].data();
                            final role = (m["role"] ?? "").toString();
                            final text = (m["text"] ?? "").toString();
                            final kind = (m["kind"] ?? "").toString();

                            final isUser = role == "user";

                            // ✅ If user has image message saved (optional)
                            if (kind == "user_with_image" && isUser) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: _UserBubble(text: text),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                              );
                            }

                            // ✅ PDF Card support
                            if (kind == "po_pdf" || kind == "pdf") {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: _PdfCard(
                                      fileName: (m["fileName"] ?? "PO.pdf")
                                          .toString(),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                              );
                            }

                            // ✅ Incident reply card (pretty)
                            if (!isUser && _isIncidentKind(kind)) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: _IncidentCard(message: m),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                              );
                            }

                            // Default chat bubbles
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Align(
                                  alignment: isUser
                                      ? Alignment.centerRight
                                      : Alignment.centerLeft,
                                  child: isUser
                                      ? _UserBubble(text: text)
                                      : _AiMarkdownBubble(text: text),
                                ),
                                const SizedBox(height: 16),
                              ],
                            );
                          },
                        );
                      },
                    ),
            ),

            // ✅ picked image preview (like chat apps)
            if (_pickedImage != null)
              Container(
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.image, color: Colors.white70),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _pickedImage!.name,
                        style: const TextStyle(color: Colors.white70),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _pickedImage = null),
                      icon: const Icon(Icons.close, color: Colors.white70),
                    ),
                  ],
                ),
              ),

            // INPUT BAR
            Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white70),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.white70),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _messageCtrl,
                      style: const TextStyle(color: Colors.white),
                      cursorColor: Colors.white,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sending ? null : _send(),
                      decoration: const InputDecoration(
                        hintText: "Ask AI anything...",
                        hintStyle: TextStyle(color: Colors.white70),
                        border: InputBorder.none,
                      ),
                    ),
                  ),

                  // Send
                  IconButton(
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white70,
                            ),
                          )
                        : const Icon(Icons.send, color: Colors.white70),
                    onPressed: _sending ? null : _send,
                  ),

                  // Mic (dictation)
                  IconButton(
                    icon: Icon(
                      _listening ? Icons.mic : Icons.mic_none,
                      color: Colors.white70,
                    ),
                    onPressed: _sending ? null : _toggleMic,
                  ),

                  // Image
                  IconButton(
                    icon: const Icon(
                      Icons.image_outlined,
                      color: Colors.white70,
                    ),
                    onPressed: _sending ? null : _pickImage,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// USER BUBBLE
class _UserBubble extends StatelessWidget {
  final String text;
  const _UserBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 14),
      ),
    );
  }
}

/// ✅ AI bubble with Markdown rendering (like ChatGPT)
class _AiMarkdownBubble extends StatelessWidget {
  final String text;
  const _AiMarkdownBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 340),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: MarkdownBody(
        data: text.trim(),
        selectable: true,
        styleSheet: MarkdownStyleSheet(
          p: const TextStyle(fontSize: 14, height: 1.5, color: Colors.black87),
          strong: const TextStyle(fontWeight: FontWeight.w700),
          h3: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          listBullet: const TextStyle(fontSize: 14),
        ),
      ),
    );
  }
}

/// ✅ INCIDENT CARD (clean + nice + small ID at bottom-right)
class _IncidentCard extends StatelessWidget {
  final Map<String, dynamic> message;
  const _IncidentCard({required this.message});

  @override
  Widget build(BuildContext context) {
    final incidentId = (message["incidentId"] ?? "").toString();

    final ai = (message["ai"] is Map) ? (message["ai"] as Map) : {};
    final severity = (ai["severity"] ?? "unknown").toString();
    final category = (ai["category"] ?? "unknown").toString();
    final summary = (ai["summary"] ?? "").toString();

    final rawActions = ai["actions"];
    final List<String> actions = (rawActions is List)
        ? rawActions.map((e) => e.toString()).toList()
        : (rawActions is String && rawActions.trim().isNotEmpty)
        ? [rawActions.trim()]
        : [];

    final kind = (message["kind"] ?? "").toString();
    final isFailed = kind == "incident_ai_failed";
    final isFollowup = kind == "incident_followup";

    return Container(
      constraints: const BoxConstraints(maxWidth: 360),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isFollowup
                ? "Next steps"
                : (isFailed ? "Incident saved ⚠️" : "Incident logged ✅"),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [_chip("Severity: $severity"), _chip(category)],
          ),
          if (summary.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              summary,
              style: const TextStyle(color: Colors.black87, height: 1.4),
            ),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              "Recommended actions",
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            ...actions
                .take(6)
                .map(
                  (a) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text("• $a"),
                  ),
                ),
          ],
          if (incidentId.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Spacer(),
                Text(
                  "ID: $incidentId",
                  style: const TextStyle(fontSize: 11, color: Colors.black45),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12)),
    );
  }
}

/// PDF CARD (kept)
class _PdfCard extends StatelessWidget {
  final String fileName;
  const _PdfCard({required this.fileName});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 340),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: const Text(
              "PDF",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              fileName,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

/// INPUT BAR
class _ChatInputBar extends StatelessWidget {
  const _ChatInputBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white70),
      ),
      child: Row(
        children: const [
          Icon(Icons.auto_awesome, color: Colors.white70),
          SizedBox(width: 12),
          Expanded(
            child: Text("", style: TextStyle(color: Colors.white)),
          ),
          Icon(Icons.mic_none, color: Colors.white70),
          SizedBox(width: 16),
          Icon(Icons.image_outlined, color: Colors.white70),
        ],
      ),
    );
  }
}
