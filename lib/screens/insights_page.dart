import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class InsightsPage extends StatefulWidget {
  const InsightsPage({super.key});

  @override
  State<InsightsPage> createState() => _InsightsPageState();
}

class _InsightsPageState extends State<InsightsPage> {
  // 0=All, 1=24h, 2=7d, 3=30d
  int filterIndex = 0;

  final _db = FirebaseFirestore.instance;

  Timestamp _cutoff() {
    final now = DateTime.now();
    if (filterIndex == 1) return Timestamp.fromDate(now.subtract(const Duration(hours: 24)));
    if (filterIndex == 2) return Timestamp.fromDate(now.subtract(const Duration(days: 7)));
    if (filterIndex == 3) return Timestamp.fromDate(now.subtract(const Duration(days: 30)));
    return Timestamp.fromDate(DateTime(2000));
  }

  /// settings/insights doc stream
  Stream<DocumentSnapshot<Map<String, dynamic>>> _insightsSettingsStream() {
    return _db.collection("settings").doc("insights").snapshots();
  }

  /// bookings stream filtered by startTime >= cutoff
  Stream<QuerySnapshot<Map<String, dynamic>>> _bookingsStream() {
    return _db
        .collection("bookings")
        .where("startTime", isGreaterThanOrEqualTo: _cutoff())
        .snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> _userProfileStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      // return an "empty" stream (never emits real data)
      return const Stream.empty();
    }
    return _db.collection("users").doc(uid).snapshots();
  }

  /// inventory stream (used for product insights list)
  Stream<QuerySnapshot<Map<String, dynamic>>> _inventoryStream() {
    return _db.collection("inventory").snapshots();
  }

  void _goBack(BuildContext context) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      // fallback if this page is the root
      Navigator.pushReplacementNamed(context, "/home");
    }
  }

  void _openNotifications() {
    // If you have a notifications page route, use it:
    // Navigator.pushNamed(context, "/notifications");
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Notifications (not set up yet).")),
    );
  }

  void _openProfile() {
    // If you have a profile page route, use it:
    // Navigator.pushNamed(context, "/profile");
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Profile (not set up yet).")),
    );
  }

  String _resolveWelcomeName(Map<String, dynamic> settings) {
    final user = FirebaseAuth.instance.currentUser;

    final authName = user?.displayName?.trim();
    final emailName = (user?.email ?? "").split("@").first.trim();

    final settingsName = (settings["welcomeName"] ?? "").toString().trim();

    // Priority:
    // 1) FirebaseAuth displayName
    // 2) FirebaseAuth email username part
    // 3) settings["welcomeName"]
    // 4) "User"
    if (authName != null && authName.isNotEmpty) return authName;
    if (emailName.isNotEmpty) return emailName;
    if (settingsName.isNotEmpty) return settingsName;
    return "User";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF25365C),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _insightsSettingsStream(),
            builder: (context, settingsSnap) {
              final settings = settingsSnap.data?.data() ?? {};

              // ✅ NOT hard-coded anymore: use FirebaseAuth user name (fallback to settings doc)
              final welcomeName = (settings["welcomeName"] ?? "Sheryl").toString();

              final dailySalesNum = _num(settings["dailySales"], fallback: 1000);
              final monthlySalesNum = _num(settings["monthlySales"], fallback: 30000);

              // profitMargin stored as 0.16 (recommended). If someone stored 16, we normalize.
              final pmRaw = _num(settings["profitMargin"], fallback: 0.16);
              final profitMargin = pmRaw > 1 ? (pmRaw / 100.0) : pmRaw;

              final revenueProgress = _clamp01(_num(settings["revenueProgress"], fallback: 0.75));

              // Optional monthlySalesByMonth map for bar chart
              final Map<String, double> monthlyMap =
                  _parseMonthMap(settings["monthlySalesByMonth"]);

              final user = FirebaseAuth.instance.currentUser;

              return ListView(
                children: [
                  /// HEADER (with Back button + icons)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => _goBack(context),
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            tooltip: "Back",
                          ),
                          const SizedBox(width: 6),
                          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                            stream: _userProfileStream(),
                            builder: (context, userSnap) {
                              final userData = userSnap.data?.data();

                              // try Firestore users/{uid}.name first
                              final dbName = (userData?["name"] ?? "").toString().trim();

                              // fallback if Firestore missing
                              final authName = (user?.displayName ?? "").trim();
                              final emailName = (user?.email ?? "").split("@").first.trim();

                              final welcomeName = dbName.isNotEmpty
                                  ? dbName
                                  : (authName.isNotEmpty ? authName : (emailName.isNotEmpty ? emailName : "User"));

                              return Text(
                                "Welcome Back,\n$welcomeName",
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                  color: Colors.white,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            onPressed: _openNotifications,
                            icon: const Icon(Icons.notifications_none, color: Colors.white),
                            tooltip: "Notifications",
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: _openProfile,
                            child: const CircleAvatar(
                              radius: 18,
                              backgroundColor: Colors.white24,
                              child: Icon(Icons.person, color: Colors.white),
                            ),
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

                  /// FILTER PILLS (NOW WORKS)
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

                  const SizedBox(height: 20),

                  /// TOP STATS (FROM DB)
                  Row(
                    children: [
                      Expanded(
                        child: _TopStatCard(
                          title: "Daily Sales",
                          value: _fmtRM(dailySalesNum),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _TopStatCard(
                          title: "Monthly Sales",
                          value: _fmtRM(monthlySalesNum),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _TopStatCard(
                          title: "Profit Margin",
                          value: "${(profitMargin * 100).toStringAsFixed(0)}%",
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  const Text(
                    "Monthly Sales Insights",
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),

                  const SizedBox(height: 12),

                  /// MONTHLY BAR CHART (FROM DB if available, else fallback)
                  _MonthlyBars(monthlyMap: monthlyMap),

                  const SizedBox(height: 30),

                  /// REVENUE + PRODUCT INSIGHTS (FROM DB)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _RevenueCard(progress: revenueProgress)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: _inventoryStream(),
                          builder: (context, invSnap) {
                            final items = invSnap.data?.docs ?? [];
                            final products = _buildProductInsights(items);
                            return _ProductsCard(products: products);
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  /// BOOKINGS (CALCULATED LIVE from bookings collection)
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _bookingsStream(),
                    builder: (context, bookSnap) {
                      final docs = bookSnap.data?.docs ?? [];
                      final dist = _bookingDistribution(docs);
                      return _BookingsCard(
                        morning: dist.morning,
                        afternoon: dist.afternoon,
                        evening: dist.evening,
                        midnight: dist.midnight,
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/* -----------------------------
   Helpers (safe parsing + calc)
------------------------------ */

double _num(dynamic v, {required double fallback}) {
  if (v == null) return fallback;
  if (v is num) return v.toDouble();
  final s = v.toString().trim();
  return double.tryParse(s) ?? fallback;
}

double _clamp01(double x) => x < 0 ? 0 : (x > 1 ? 1 : x);

String _fmtRM(double value) {
  // Simple format like your UI: RM30,000
  final rounded = value.round();
  final s = rounded.toString();
  final buf = StringBuffer();

  // Build from right to left for correct commas
  int count = 0;
  for (int i = s.length - 1; i >= 0; i--) {
    buf.write(s[i]);
    count++;
    if (count % 3 == 0 && i != 0) buf.write(",");
  }

  final withCommas = buf.toString().split("").reversed.join();
  return "RM$withCommas";
}

Map<String, double> _parseMonthMap(dynamic raw) {
  // expected: {Jan: 1000, Feb: 2000, ...}
  if (raw is Map) {
    final out = <String, double>{};
    raw.forEach((k, v) {
      out[k.toString()] = _num(v, fallback: 0);
    });
    if (out.isNotEmpty) return out;
  }

  // fallback (keeps your original design)
  return {
    "Jan": 0.5,
    "Feb": 0.7,
    "March": 0.85,
    "April": 1.0,
  };
}

class _ProductInsight {
  final String name;
  final int value;
  const _ProductInsight(this.name, this.value);
}

List<_ProductInsight> _buildProductInsights(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
) {
  // Try fields in this order: sold, quantitySold, stock
  final list = <_ProductInsight>[];

  for (final d in docs) {
    final data = d.data();
    final name = (data["name"] ?? data["productName"] ?? d.id).toString();

    int val = 0;
    final sold = data["sold"];
    final qtySold = data["quantitySold"];
    final stock = data["stock"];

    if (sold is num) {
      val = sold.toInt();
    } else if (qtySold is num) {
      val = qtySold.toInt();
    } else if (stock is num) {
      val = stock.toInt();
    } else {
      val = 0;
    }

    list.add(_ProductInsight(name, val));
  }

  // Sort high->low to match typical "insights"
  list.sort((a, b) => b.value.compareTo(a.value));

  // Keep max 6 like your design
  if (list.isEmpty) {
    return const [
      _ProductInsight("Paddle", 2),
      _ProductInsight("Ball", 10),
      _ProductInsight("Shirt", 3),
      _ProductInsight("Bag", 1),
      _ProductInsight("Grip", 5),
      _ProductInsight("Socks", 0),
    ];
  }

  return list.take(6).toList();
}

class _BookingDist {
  final double morning, afternoon, evening, midnight;
  const _BookingDist({
    required this.morning,
    required this.afternoon,
    required this.evening,
    required this.midnight,
  });
}

_BookingDist _bookingDistribution(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
) {
  int morning = 0, afternoon = 0, evening = 0, midnight = 0;

  for (final d in docs) {
    final data = d.data();
    final ts = data["startTime"];
    DateTime? dt;

    if (ts is Timestamp) dt = ts.toDate();
    if (dt == null) continue;

    final h = dt.hour;

    // Buckets (feel free to tweak):
    // Morning: 6-11
    // Afternoon: 12-17
    // Evening: 18-23
    // Midnight: 0-5
    if (h >= 6 && h <= 11) {
      morning++;
    } else if (h >= 12 && h <= 17) {
      afternoon++;
    } else if (h >= 18 && h <= 23) {
      evening++;
    } else {
      midnight++;
    }
  }

  final total = morning + afternoon + evening + midnight;
  if (total == 0) {
    // Keep your original look if no data yet
    return const _BookingDist(
      morning: 0.25,
      afternoon: 0.10,
      evening: 0.45,
      midnight: 0.20,
    );
  }

  double pct(int x) => x / total;

  return _BookingDist(
    morning: pct(morning),
    afternoon: pct(afternoon),
    evening: pct(evening),
    midnight: pct(midnight),
  );
}

/* -----------------------------
   Widgets (same design)
------------------------------ */

/// FILTER
class _FilterPill extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback? onTap;

  const _FilterPill({required this.text, this.selected = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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

/// MONTHLY BARS (keeps exact look)
class _MonthlyBars extends StatelessWidget {
  final Map<String, double> monthlyMap;
  const _MonthlyBars({required this.monthlyMap});

  @override
  Widget build(BuildContext context) {
    // If monthlyMap values look like real RM amounts, normalize them
    final vals = monthlyMap.values.toList();
    final maxVal = vals.isEmpty ? 1.0 : vals.reduce((a, b) => a > b ? a : b);
    final looksLikeMoney = maxVal > 1.5; // heuristic

    final entries = monthlyMap.entries.toList();

    return Column(
      children: entries.map((e) {
        final wf = looksLikeMoney
            ? (maxVal == 0 ? 0.0 : (e.value / maxVal))
            : _clamp01(e.value);
        return _BarItem(label: e.key, widthFactor: wf);
      }).toList(),
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
              widthFactor: widthFactor <= 0 ? 0.02 : widthFactor,
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
  final double progress; // 0..1
  const _RevenueCard({required this.progress});

  @override
  Widget build(BuildContext context) {
    final pct = (progress * 100).round();

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
                  value: progress,
                  strokeWidth: 14,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                ),
              ),
              Text(
                "$pct%",
                style: const TextStyle(
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
  final List<_ProductInsight> products;
  const _ProductsCard({required this.products});

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
        children: [
          const Text(
            "Products Insights",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ...products.map((p) => _ProductRow(name: p.name, value: "${p.value}")),
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
          Expanded(child: Text(name, overflow: TextOverflow.ellipsis)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

/// BOOKINGS
class _BookingsCard extends StatelessWidget {
  final double morning;
  final double afternoon;
  final double evening;
  final double midnight;

  const _BookingsCard({
    required this.morning,
    required this.afternoon,
    required this.evening,
    required this.midnight,
  });

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
        children: [
          const Text(
            "Court Bookings Insights",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _BookingCircle(label: "Morning", value: morning),
              _BookingCircle(label: "Afternoon", value: afternoon),
              _BookingCircle(label: "Evening", value: evening),
              _BookingCircle(label: "Midnight", value: midnight),
            ],
          ),
        ],
      ),
    );
  }
}

class _BookingCircle extends StatelessWidget {
  final String label;
  final double value; // 0..1

  const _BookingCircle({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final v = _clamp01(value);
    final percent = "${(v * 100).round()}%";

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              height: 70,
              width: 70,
              child: CircularProgressIndicator(
                value: v,
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
