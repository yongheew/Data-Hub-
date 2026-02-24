import 'package:flutter/material.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2F436E),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ListView(
            children: [
              // HEADER
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Welcome Back,\nSheryl",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Row(
                    children: const [
                      Icon(Icons.notifications_none, color: Colors.white),
                      SizedBox(width: 16),
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.white24,
                        child: Icon(Icons.person, color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 24),

              const Text(
                "Operational Overview",
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),

              const SizedBox(height: 16),

              // FILTERS
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

              const SizedBox(height: 24),

              // MAIN CARD
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4C6CB3), Color(0xFF3A5AA8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Operational Signals",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      "Repeated Issues: 12",
                      style: TextStyle(color: Colors.white, fontSize: 15),
                    ),
                    SizedBox(height: 6),
                    Text(
                      "Unresolved issues: 5",
                      style: TextStyle(color: Colors.white, fontSize: 15),
                    ),
                    SizedBox(height: 6),
                    Text(
                      "High-Risk Locations: 3",
                      style: TextStyle(color: Colors.white, fontSize: 15),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // STATS CARDS
              Row(
                children: const [
                  Expanded(
                    child: _StatCard(
                      title: "Repeated\nIssues",
                      value: "50%",
                      subtitle: "Recurring Occurrences",
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: _StatCard(
                      title: "New\nIssues",
                      value: "30%",
                      subtitle: "First-time Occurrences",
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              const Text(
                "Metrics Overview",
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),

              const SizedBox(height: 16),

              Row(
                children: const [
                  Expanded(
                    child: _MetricCard(
                      title: "1.8 hrs",
                      subtitle: "Average Resolution Time",
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _MetricCard(
                      title: "75%",
                      subtitle: "Recurrence Rate",
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _MetricCard(
                      title: "50%",
                      subtitle: "Operational Stability Index",
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // BUTTON
              Container(
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Center(
                  child: Text(
                    "View Active Issues",
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
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

  const _FilterPill({required this.text, this.selected = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
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

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;

  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Text(
            value,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String subtitle;

  const _MetricCard({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
    );
  }
}
