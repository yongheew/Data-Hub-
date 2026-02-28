import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';

class ChatService {
  static final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'us-central1');

  static const String _chatId = "default";

  /// Sends a message to backend.
  /// Backend decides: incident vs chat (NO keyword detection in Flutter).
  ///
  /// Optional:
  /// - imageBytes + imageMimeType
  static Future<String> sendChat(
    String message, {
    Uint8List? imageBytes,
    String? imageMimeType,
  }) async {
    final trimmed = message.trim();

    final finalText =
        (trimmed.isEmpty && imageBytes != null) ? "Report this image." : trimmed;

    if (finalText.isEmpty) return "Please type something.";

    final payload = <String, dynamic>{
      "message": finalText,
      "chatId": _chatId,
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
              "chatId": _chatId,
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