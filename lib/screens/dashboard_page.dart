import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DashboardPage extends StatelessWidget {
  DashboardPage({super.key});

  // ✅ KEEP: same function, same logic
  Future<String> _loadNameOrEmail() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return "";

    try {
      final snap = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .get();

      final data = snap.data();
      final name = (data?["name"] ?? "").toString().trim();
      if (name.isNotEmpty) return name;
    } catch (_) {
      // ignore
    }

    return user.email ?? "";
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFEDEDED),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2F436E),
        foregroundColor: Colors.white,
        title: const Text("Dashboard"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/login',
                  (_) => false,
                );
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ✅ KEEP: FutureBuilder, but improved states
              FutureBuilder<String>(
                future: _loadNameOrEmail(),
                builder: (context, snap) {
                  final fallback = user?.email ?? "";

                  if (snap.connectionState == ConnectionState.waiting) {
                    return Row(
                      children: const [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 10),
                        Text(
                          "Loading profile...",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    );
                  }

                  if (snap.hasError) {
                    return Text(
                      "Welcome $fallback",
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  }

                  final display = (snap.data ?? fallback).trim();
                  return Text(
                    "Welcome $display",
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                },
              ),
              const SizedBox(height: 30),

              _DashboardButton(
                title: "Chat",
                onTap: () => Navigator.pushNamed(context, '/chat'),
              ),
              const SizedBox(height: 16),

              _DashboardButton(
                title: "Data Log",
                onTap: () => Navigator.pushNamed(context, '/data-log'),
              ),
              const SizedBox(height: 16),

              _DashboardButton(
                title: "Insights",
                onTap: () => Navigator.pushNamed(context, '/insights'),
              ),
              const SizedBox(height: 16),

              _DashboardButton(
                title: "Chat History",
                onTap: () => Navigator.pushNamed(context, '/chat-history'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardButton extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const _DashboardButton({
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2F436E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          title,
          style: const TextStyle(fontSize: 16, color: Colors.white),
        ),
      ),
    );
  }
}