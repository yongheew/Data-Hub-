import 'package:flutter/material.dart';

class ChatPage extends StatelessWidget {
  const ChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2F436E),
      body: SafeArea(
        child: Column(
          children: [
            /// CHAT MESSAGES
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 20,
                ),
                children: const [
                  /// USER MESSAGE
                  Align(
                    alignment: Alignment.centerRight,
                    child: _UserBubble(
                      text:
                          "The Franklin paddles are out of stock.\nWhat should I do?",
                    ),
                  ),

                  SizedBox(height: 16),

                  /// AI RESPONSE
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _AiBubble(
                      text:
                          "Let me check the current inventory status for Franklin paddles.\n"
                          "Current stock: 0\n"
                          "Maximum stock level: 8\n\n"
                          "Since the stock is empty, here’s a recommended purchase plan based on the preset maximum stock level.\n\n"
                          "Required purchase quantity: 8 paddles\n\n"
                          "Supplier details:\n"
                          "PicklePro Sports Supplies\n"
                          "Whatsapp : 012-3456789\n"
                          "Email : pickleprosports@gmail.com\n"
                          "· Unit price: RM700\n"
                          "· Subtotal: RM5600\n"
                          "Estimated total cost: RM5600\n\n"
                          "Would you like to confirm? Once confirmed, a Purchase Order (PO) will be generated automatically. In the meantime, please inform customers that the paddles are temporarily out of stock. Ask customers to leave their contact number, and let them know the court will contact them as soon as the paddles are back in stock.",
                    ),
                  ),

                  SizedBox(height: 20),

                  /// USER CONFIRM
                  Align(
                    alignment: Alignment.centerRight,
                    child: _UserBubble(text: "Yes, please proceed."),
                  ),

                  SizedBox(height: 16),

                  /// AI CONFIRMATION
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _AiBubble(
                      text:
                          "The Purchase Order (PO) has been generated successfully. Please send the PO to PicklePro Sports Supplies via:\n"
                          "· Email: pickleprosports@gmail.com\n"
                          "· WhatsApp: 012-3456789",
                    ),
                  ),

                  SizedBox(height: 16),

                  /// PDF CARD
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _PdfCard(
                      fileName: "PO_PickleProSports_20260202_PO-2026-001.pdf",
                    ),
                  ),

                  SizedBox(height: 30),
                ],
              ),
            ),

            /// INPUT BAR
            Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white70),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.white70),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: TextField(
                      style: TextStyle(color: Colors.white),
                      cursorColor: Colors.white,
                      decoration: InputDecoration(
                        hintText: "Ask AI anything...",
                        hintStyle: TextStyle(color: Colors.white70),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const Icon(Icons.mic_none, color: Colors.white70),
                  const SizedBox(width: 16),
                  const Icon(Icons.image_outlined, color: Colors.white70),
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

/// AI BUBBLE
class _AiBubble extends StatelessWidget {
  final String text;

  const _AiBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          height: 1.5,
          color: Colors.black87,
        ),
      ),
    );
  }
}

/// PDF CARD
class _PdfCard extends StatelessWidget {
  final String fileName;

  const _PdfCard({required this.fileName});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(8),
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
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
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
