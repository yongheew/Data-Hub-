import 'package:flutter/material.dart';

class InsightsPage extends StatelessWidget {
  const InsightsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF25365C),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ListView(
            children: [
              /// HEADER
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Welcome Back,\nSheryl",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
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
                "Operation Insights",
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),

              const SizedBox(height: 16),

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

              const SizedBox(height: 20),

              /// TOP STATS
              Row(
                children: const [
                  Expanded(
                    child: _TopStatCard(title: "Daily Sales", value: "RM1000"),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _TopStatCard(
                      title: "Monthly Sales",
                      value: "RM30,000",
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _TopStatCard(title: "Profit Margin", value: "16%"),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              const Text(
                "Monthly Sales Insights",
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),

              const SizedBox(height: 12),

              /// SIMPLE BAR CHART MOCK
              Column(
                children: const [
                  _BarItem(label: "Jan", widthFactor: 0.5),
                  _BarItem(label: "Feb", widthFactor: 0.7),
                  _BarItem(label: "March", widthFactor: 0.85),
                  _BarItem(label: "April", widthFactor: 1),
                ],
              ),

              const SizedBox(height: 30),

              /// REVENUE + PRODUCT INSIGHTS
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Expanded(child: _RevenueCard()),
                  SizedBox(width: 16),
                  Expanded(child: _ProductsCard()),
                ],
              ),

              const SizedBox(height: 30),

              /// BOOKINGS
              const _BookingsCard(),
            ],
          ),
        ),
      ),
    );
  }
}

/// FILTER
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

/// TOP STAT CARD
class _TopStatCard extends StatelessWidget {
  final String title;
  final String value;

  const _TopStatCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

/// BAR ITEM
class _BarItem extends StatelessWidget {
  final String label;
  final double widthFactor;

  const _BarItem({required this.label, required this.widthFactor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: widthFactor,
              child: Container(
                height: 22,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C8EF5), Color(0xFF8FA8FF)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// REVENUE CARD
class _RevenueCard extends StatelessWidget {
  const _RevenueCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C8EF5), Color(0xFF4F6EDB)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Text(
            "Revenue Insights",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 20),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: 120,
                width: 120,
                child: CircularProgressIndicator(
                  value: 0.75,
                  strokeWidth: 14,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                ),
              ),
              const Text(
                "75%",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// PRODUCTS CARD
class _ProductsCard extends StatelessWidget {
  const _ProductsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.white, Color(0xFFF2F4FF)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            "Products Insights",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          _ProductRow(name: "Paddle", value: "2"),
          _ProductRow(name: "Ball", value: "10"),
          _ProductRow(name: "Shirt", value: "3"),
          _ProductRow(name: "Bag", value: "1"),
          _ProductRow(name: "Grip", value: "5"),
          _ProductRow(name: "Socks", value: "0"),
        ],
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  final String name;
  final String value;

  const _ProductRow({required this.name, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(name),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

/// BOOKINGS
class _BookingsCard extends StatelessWidget {
  const _BookingsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: const [
          Text(
            "Court Bookings Insights",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _BookingCircle(label: "Morning", percent: "25%"),
              _BookingCircle(label: "Afternoon", percent: "10%"),
              _BookingCircle(label: "Evening", percent: "45%"),
              _BookingCircle(label: "Midnight", percent: "20%"),
            ],
          ),
        ],
      ),
    );
  }
}

class _BookingCircle extends StatelessWidget {
  final String label;
  final String percent;

  const _BookingCircle({required this.label, required this.percent});

  double _convertPercent() {
    return double.parse(percent.replaceAll("%", "")) / 100;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              height: 70,
              width: 70,
              child: CircularProgressIndicator(
                value: _convertPercent(),
                strokeWidth: 8,
                backgroundColor: Colors.grey.shade300,
                valueColor: const AlwaysStoppedAnimation(Color(0xFF2F436E)),
              ),
            ),
            Text(percent, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 6),
        Text(label),
      ],
    );
  }
}
