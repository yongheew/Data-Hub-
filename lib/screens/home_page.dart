import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Future<String> _getUserName() async {
    final user = FirebaseAuth.instance.currentUser;

    // If not logged in yet (or auth state not ready), fallback
    if (user == null) return "User";

    // Try Firestore: users/{uid}
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = doc.data();
      final name = data?['name'];

      if (name is String && name.trim().isNotEmpty) {
        return name.trim();
      }
    } catch (_) {
      // Ignore here; we’ll fallback below (permission denied / missing doc / etc.)
    }

    // Fallbacks
    final display = user.displayName;
    if (display != null && display.trim().isNotEmpty) return display.trim();

    final email = user.email;
    if (email != null && email.trim().isNotEmpty) return email.trim();

    return "User";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2F436E),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 40),

              // Robot Icon
              const Icon(
                Icons.smart_toy_outlined,
                size: 110,
                color: Colors.white,
              ),

              const SizedBox(height: 24),

              // Greeting (dynamic)
              FutureBuilder<String>(
                future: _getUserName(),
                builder: (context, snapshot) {
                  final name = (snapshot.data == null || snapshot.data!.isEmpty)
                      ? "User"
                      : snapshot.data!;
                  return Text(
                    "Hello, $name",
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  );
                },
              ),

              const SizedBox(height: 8),

              const Text(
                "What can i help you with?",
                style: TextStyle(fontSize: 18, color: Colors.white70),
              ),

              const SizedBox(height: 40),

              // Grid Buttons
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 20,
                  crossAxisSpacing: 20,
                  childAspectRatio: 1,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            Navigator.pushNamed(context, '/chat-history');
                          },
                          child: const _HomeCard(
                            icon: Icons.arrow_outward,
                            title: "Chat\nHistory",
                          ),
                        ),
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(28),
                        onTap: () {
                          Navigator.pushNamed(context, '/dashboard');
                        },
                        child: const _HomeCard(
                          icon: Icons.circle_outlined,
                          title: "Dashboard",
                        ),
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(28),
                        onTap: () {
                          Navigator.pushNamed(context, '/insights');
                        },
                        child: const _HomeCard(
                          icon: Icons.auto_graph_outlined,
                          title: "Insights",
                        ),
                      ),
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            Navigator.pushNamed(context, '/data-log');
                          },
                          child: const _HomeCard(
                            icon: Icons.crop_square,
                            title: "Data Log",
                          ),
                        ),
                      ),
                    ),
                    const _HomeCard(
                      icon: Icons.change_history_outlined,
                      title: "Notes",
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Bottom Input Bar
              Container(
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white70),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
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
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeCard extends StatelessWidget {
  final IconData icon;
  final String title;

  const _HomeCard({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF8A9AB6), Color(0xFFD6C7D8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 26),
          const Spacer(),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Color(0xFF2F436E),
            ),
          ),
        ],
      ),
    );
  }
}
