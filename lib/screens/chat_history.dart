import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/chat_service.dart';
import 'chat_page.dart';

class ChatHistoryPage extends StatefulWidget {
  const ChatHistoryPage({super.key});

  @override
  State<ChatHistoryPage> createState() => _ChatHistoryPageState();
}

class _ChatHistoryPageState extends State<ChatHistoryPage> {
  int filterIndex = 0; // 0=All, 1=24h, 2=7d, 3=30d

  User? get _user => FirebaseAuth.instance.currentUser;

  Timestamp _cutoff() {
    final now = DateTime.now();
    if (filterIndex == 1) {
      return Timestamp.fromDate(now.subtract(const Duration(hours: 24)));
    }
    if (filterIndex == 2) {
      return Timestamp.fromDate(now.subtract(const Duration(days: 7)));
    }
    if (filterIndex == 3) {
      return Timestamp.fromDate(now.subtract(const Duration(days: 30)));
    }
    return Timestamp.fromDate(DateTime(2000));
  }

  @override
  Widget build(BuildContext context) {
    final u = _user;

    return Scaffold(
      backgroundColor: const Color(0xFF2F436E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2F436E),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Chat History",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// FILTER PILLS
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterPill(
                      text: "All",
                      selected: filterIndex == 0,
                      onTap: () => setState(() => filterIndex = 0),
                    ),
                    _FilterPill(
                      text: "Last 24 hrs",
                      selected: filterIndex == 1,
                      onTap: () => setState(() => filterIndex = 1),
                    ),
                    _FilterPill(
                      text: "Last 7 Days",
                      selected: filterIndex == 2,
                      onTap: () => setState(() => filterIndex = 2),
                    ),
                    _FilterPill(
                      text: "Last 30 Days",
                      selected: filterIndex == 3,
                      onTap: () => setState(() => filterIndex = 3),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              /// DIVIDER
              Container(height: 1, color: Colors.white24),

              const SizedBox(height: 20),

              /// LIST (REAL FIRESTORE)
              Expanded(
                child: u == null
                    ? const Center(
                        child: Text(
                          "Please login first.",
                          style: TextStyle(color: Colors.white),
                        ),
                      )
                    : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: ChatService.streamChats(
                          uid: u.uid,
                          cutoff: _cutoff(),
                        ),
                        builder: (context, snap) {
                          if (snap.hasError) {
                            return Center(
                              child: Text(
                                "Error: ${snap.error}",
                                style: const TextStyle(color: Colors.white70),
                              ),
                            );
                          }
                          if (!snap.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(
                                  color: Colors.white),
                            );
                          }

                          final docs = snap.data!.docs;
                          if (docs.isEmpty) {
                            return const Center(
                              child: Text(
                                "No chat history yet.",
                                style: TextStyle(color: Colors.white70),
                              ),
                            );
                          }

                          return ListView.builder(
                            itemCount: docs.length,
                            itemBuilder: (context, i) {
                              final d = docs[i];
                              final data = d.data();

                              final title =
                                  (data["title"] ?? "Untitled Chat").toString();
                              final subtitle =
                                  (data["lastMessage"] ?? "").toString();

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 24),
                                child: _HistoryItem(
                                  title: title,
                                  subtitle: subtitle.isEmpty ? "—" : subtitle,
                                  showDelete: true,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ChatPage(chatId: d.id),
                                      ),
                                    );
                                  },
                                  onDelete: () async {
                                    final ok = await showDialog<bool>(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        title: const Text("Delete chat?"),
                                        content: const Text(
                                            "This will delete the chat and all messages."),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: const Text("Cancel"),
                                          ),
                                          ElevatedButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            child: const Text("Delete"),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (ok != true) return;

                                    await ChatService.deleteChat(
                                      uid: u.uid,
                                      chatId: d.id,
                                    );
                                  },
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback? onTap;

  const _FilterPill({
    required this.text,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.white24,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: selected ? Colors.black : Colors.white,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _HistoryItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool showDelete;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const _HistoryItem({
    required this.title,
    required this.subtitle,
    this.showDelete = false,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        /// TEXT
        Expanded(
          child: InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ),

        /// DELETE BUTTON
        if (showDelete)
          GestureDetector(
            onTap: onDelete,
            child: Container(
              margin: const EdgeInsets.only(left: 12),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Text(
                "Delete",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
