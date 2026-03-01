import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:http/http.dart' as http;

class ChatPage extends StatefulWidget {
  final String chatId;

  const ChatPage({
    super.key,
    required this.chatId,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late final String _chatId;

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
    return _messagesRef(uid)
        .orderBy("createdAt", descending: false)
        .snapshots();
  }

  @override
  void initState() {
    super.initState();
    _chatId = widget.chatId;

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
    if (!_speechReady) return;

    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }

    final started = await _speech.listen(
      onResult: (res) {
        if (!mounted) return;

        // Append dictation to existing text
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Image pick failed: $e")));
    }
  }

  String _guessMimeType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith(".png")) return "image/png";
    if (lower.endsWith(".webp")) return "image/webp";
    return "image/jpeg";
  }

  /// ✅ WEB: use Firebase callable (HTTPS, no mixed content)
  Future<void> _sendViaFirebaseCallable({
    required String message,
    Uint8List? imageBytes,
    String? imageMimeType,
  }) async {
    // Your functions are in us-central1
    final functions = FirebaseFunctions.instanceFor(region: "us-central1");
    final callable = functions.httpsCallable("processUserMessage");

    final String? imageBase64 =
        imageBytes == null ? null : base64Encode(imageBytes);

    // IMPORTANT: your backend expects keys:
    // chatId, message, imageBase64?, imageMimeType?
    await callable.call({
      "chatId": _chatId,
      "message": message,
      if (imageBase64 != null) "imageBase64": imageBase64,
      if (imageMimeType != null) "imageMimeType": imageMimeType,
    });

    // NOTE: your backend writes user+assistant messages itself.
    // So we DO NOT write messages here for web.
  }

  /// ✅ MOBILE/DESKTOP: keep your Flask AI flow (HTTP)
  Future<void> _sendViaFlaskAndSave({
    required User u,
    required String message,
    Uint8List? imageBytes,
    String? imageMimeType,
  }) async {
    // 1) Save user message
    await _messagesRef(u.uid).add({
      "role": "user",
      "text": message,
      "createdAt": FieldValue.serverTimestamp(),
      "kind": imageBytes != null ? "user_with_image" : "user_text",
    });

    // 2) Call Flask backend (your original behavior)
    final response = await http.post(
      Uri.parse(flaskUrl),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "user_name": u.displayName ?? u.email ?? "User",
        "issue_text": message,
        // If your Flask supports image, you can add:
        // "image_base64": imageBytes == null ? null : base64Encode(imageBytes),
        // "image_mime": imageMimeType,
      }),
    );

    String aiReply = "No response from AI.";
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      aiReply = (data is Map && data["user_message"] != null)
          ? data["user_message"].toString()
          : aiReply;
    } else {
      aiReply = "Error: ${response.statusCode}";
    }

    // 3) Save assistant reply
    await _messagesRef(u.uid).add({
      "role": "assistant",
      "text": aiReply,
      "createdAt": FieldValue.serverTimestamp(),
      "kind": "chat_reply",
    });
  }

  Future<void> _send() async {
    if (_sending) return;

    final u = _user;
    if (u == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Please login first.")));
      return;
    }

    final text = _messageCtrl.text.trim();
    final hasImage = _pickedImage != null;
    if (text.isEmpty && !hasImage) return;

    setState(() => _sending = true);

    // Clear input immediately (ChatGPT-like)
    _messageCtrl.clear();

    // Snapshot image then clear preview immediately
    final imgToSend = _pickedImage;
    setState(() => _pickedImage = null);

    try {
      Uint8List? imageBytes;
      String? imageMimeType;

      if (imgToSend != null) {
        imageBytes = await imgToSend.readAsBytes();
        imageMimeType = _guessMimeType(imgToSend.name);
      }

      if (kIsWeb) {
        // ✅ WEB FIX: do NOT call http:// (mixed content). Use Firebase callable.
        await _sendViaFirebaseCallable(
          message: text,
          imageBytes: imageBytes,
          imageMimeType: imageMimeType,
        );
      } else {
        // ✅ Keep your original Flask behavior off-web
        await _sendViaFlaskAndSave(
          u: u,
          message: text,
          imageBytes: imageBytes,
          imageMimeType: imageMimeType,
        );
      }

      await Future.delayed(const Duration(milliseconds: 250));
      _scrollToBottom();
    } catch (e) {
      // If Flask failed AFTER user msg saved, you were getting “only user msg appears”.
      // We fix that by writing an assistant error message (non-web path).
      if (!kIsWeb) {
        try {
          await _messagesRef(u.uid).add({
            "role": "assistant",
            "text":
                "Send failed: $e\n\nTip: If you're testing on Chrome, Flask HTTP will be blocked. Use the Firebase function route.",
            "createdAt": FieldValue.serverTimestamp(),
            "kind": "chat_reply",
          });
        } catch (_) {
          // ignore
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Send failed: $e")));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    if (!_scrollCtrl.hasClients) return;
    _scrollCtrl.animateTo(
      _scrollCtrl.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
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
                        if (!snap.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(color: Colors.white),
                          );
                        }

                        final docs = snap.data!.docs;

                        WidgetsBinding.instance.addPostFrameCallback(
                          (_) => _scrollToBottom(),
                        );

                        return ListView.builder(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.all(20),
                          itemCount: docs.length,
                          itemBuilder: (context, i) {
                            final m = docs[i].data();
                            final role = (m["role"] ?? "").toString();
                            final text = (m["text"] ?? "").toString();
                            final isUser = role == "user";

                            return Align(
                              alignment: isUser
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                padding: const EdgeInsets.all(16),
                                constraints: const BoxConstraints(maxWidth: 340),
                                decoration: BoxDecoration(
                                  color: isUser ? Colors.black : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: isUser
                                    ? Text(
                                        text,
                                        style: const TextStyle(color: Colors.white),
                                      )
                                    : MarkdownBody(
                                        data: text,
                                        selectable: true,
                                      ),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),

            // ✅ image preview
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
                  IconButton(
                    icon: Icon(
                      _listening ? Icons.mic : Icons.mic_none,
                      color: Colors.white70,
                    ),
                    onPressed: _sending ? null : _toggleMic,
                  ),
                  IconButton(
                    icon: const Icon(Icons.image_outlined, color: Colors.white70),
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
