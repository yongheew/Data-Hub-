import 'package:flutter/material.dart';

class ChatHistoryPage extends StatelessWidget {
  const ChatHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2F436E),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// TITLE
              const Text(
                "Chat History",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 20),

              /// FILTER PILLS
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: const [
                    _FilterPill(text: "All", selected: true),
                    _FilterPill(text: "Last 24 hrs"),
                    _FilterPill(text: "Last 7 Days"),
                    _FilterPill(text: "Last 30 Days"),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              /// DIVIDER
              Container(height: 1, color: Colors.white24),

              const SizedBox(height: 20),

              /// LIST
              const Expanded(child: _HistoryList()),
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

  const _FilterPill({required this.text, this.selected = false});

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: const [
        _HistoryItem(
          title: "Net Damage",
          subtitle: "Net loosened during evening match",
        ),

        _HistoryItem(
          title: "Rainy Day Issue",
          subtitle: "Slippery entrance after rain",
          showDelete: true,
        ),

        _HistoryItem(
          title: "Tournament Setup",
          subtitle: "Need extra chairs for weekend tournament",
        ),

        _HistoryItem(
          title: "Line Marking Wear",
          subtitle: "Baseline markings fading and hard to see",
        ),

        _HistoryItem(
          title: "Loose Net Post",
          subtitle: "Net post slightly unstable during play",
        ),

        _HistoryItem(
          title: "Lighting Issue",
          subtitle: "Light at Court 2 flickering during evening games",
        ),

        _HistoryItem(
          title: "Ball Quality Issue",
          subtitle: "Several balls cracked during match",
        ),

        _HistoryItem(
          title: "Missing Paddle Report",
          subtitle: "Player reported missing paddle after match",
        ),

        _HistoryItem(
          title: "Court Booking Conflict",
          subtitle: "Double booking reported by staff",
        ),
      ],
    );
  }
}

class _HistoryItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool showDelete;

  const _HistoryItem({
    required this.title,
    required this.subtitle,
    this.showDelete = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// TEXT
          Expanded(
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

          /// DELETE BUTTON
          if (showDelete)
            Container(
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
        ],
      ),
    );
  }
}
