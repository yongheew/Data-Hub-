import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DataLogPage extends StatefulWidget {
  const DataLogPage({super.key});

  @override
  State<DataLogPage> createState() => _DataLogPageState();
}

class _DataLogPageState extends State<DataLogPage> {
  int selectedIndex = 0; // 0 = Inventory, 1 = Bookings, 2 = Settings

  Stream<QuerySnapshot<Map<String, dynamic>>> _inventoryStream() {
    return FirebaseFirestore.instance
        .collection("inventory")
        .orderBy("updatedAt", descending: true)
        .limit(50)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _incidentsStream() {
    return FirebaseFirestore.instance
        .collection("incidents")
        .orderBy("createdAt", descending: true)
        .limit(20)
        .snapshots();
  }

  /// ✅ Go back (pop if possible, else go Home)
  void _goBack(BuildContext context) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      // fallback if this page is the root
      Navigator.pushReplacementNamed(context, "/home");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2F436E),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// ✅ HEADER ROW WITH BACK BUTTON + TITLE
              Row(
                children: [
                  IconButton(
                    onPressed: () => _goBack(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    tooltip: "Back",
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    "Data Log",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              /// TOP BUTTONS
              Row(
                children: [
                  _circleButton(),
                  const SizedBox(width: 10),
                  _tabButton("Inventory", 0),
                  const SizedBox(width: 10),
                  _tabButton("Bookings", 1),
                  const SizedBox(width: 10),
                  _tabButton("Settings", 2),
                ],
              ),

              const SizedBox(height: 20),

              /// TABLE + INCIDENTS SECTION
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: _buildTable(),
                      ),
                      const SizedBox(height: 26),

                      // ✅ Incidents are always shown (so they "come back")
                      const Text(
                        "Recent Incidents",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: _incidentsTable(),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _circleButton() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.add, color: Colors.black),
    );
  }

  Widget _tabButton(String text, int index) {
    bool isSelected = selectedIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedIndex = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white24,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(color: isSelected ? Colors.black : Colors.white),
        ),
      ),
    );
  }

  Widget _buildTable() {
    if (selectedIndex == 0) return _inventoryTable();
    if (selectedIndex == 1) return _bookingTable();
    return _settingsTable();
  }

  /// INVENTORY TABLE (Firestore, fallback to your demo rows)
  Widget _inventoryTable() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _inventoryStream(),
      builder: (context, snap) {
        final headingStyle = const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        );
        final dataStyle = const TextStyle(color: Colors.white);

        if (snap.hasError) {
          return Text("Inventory error: ${snap.error}",
              style: const TextStyle(color: Colors.white));
        }

        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        final docs = snap.data!.docs;

        // If no inventory docs, show your demo rows (so UI doesn’t look empty)
        final rows = <DataRow>[];
        if (docs.isEmpty) {
          rows.addAll(const [
            DataRow(
              cells: [
                DataCell(Text("Paddle")),
                DataCell(Text("Franklin")),
                DataCell(Text("SportPro")),
                DataCell(Text("RM700")),
                DataCell(Text("0")),
                DataCell(Text("2/2/2026")),
              ],
            ),
            DataRow(
              cells: [
                DataCell(Text("Ball")),
                DataCell(Text("Krux")),
                DataCell(Text("ProSports")),
                DataCell(Text("RM7")),
                DataCell(Text("100")),
                DataCell(Text("2/2/2026")),
              ],
            ),
          ]);
        } else {
          for (final d in docs) {
            final m = d.data();

            final item = (m["item"] ?? "").toString();
            final brand = (m["brand"] ?? "").toString();
            final supplier = (m["supplier"] ?? "").toString();

            final unitPrice = (m["unitPrice"] ?? m["price"] ?? "").toString();
            final qty = (m["quantity"] ?? m["qty"] ?? "").toString();

            String lastUpdated = "";
            final ts = m["updatedAt"] ?? m["lastUpdated"];
            if (ts is Timestamp) {
              final dt = ts.toDate();
              lastUpdated = "${dt.day}/${dt.month}/${dt.year}";
            } else {
              lastUpdated = ts?.toString() ?? "";
            }

            rows.add(
              DataRow(
                cells: [
                  DataCell(Text(item)),
                  DataCell(Text(brand)),
                  DataCell(Text(supplier)),
                  DataCell(Text(unitPrice)),
                  DataCell(Text(qty)),
                  DataCell(Text(lastUpdated)),
                ],
              ),
            );
          }
        }

        return DataTable(
          headingTextStyle: headingStyle,
          dataTextStyle: dataStyle,
          columns: const [
            DataColumn(label: Text("Item")),
            DataColumn(label: Text("Brand")),
            DataColumn(label: Text("Supplier")),
            DataColumn(label: Text("Unit Price")),
            DataColumn(label: Text("Quantity")),
            DataColumn(label: Text("Last Updated")),
          ],
          rows: rows,
        );
      },
    );
  }

  /// BOOKINGS TABLE (kept as your demo)
  Widget _bookingTable() {
    return DataTable(
      headingTextStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
      dataTextStyle: const TextStyle(color: Colors.white),
      columns: const [
        DataColumn(label: Text("Booking ID")),
        DataColumn(label: Text("Court")),
        DataColumn(label: Text("Date")),
        DataColumn(label: Text("Time")),
        DataColumn(label: Text("Name")),
        DataColumn(label: Text("Price")),
        DataColumn(label: Text("Notes")),
      ],
      rows: const [
        DataRow(
          cells: [
            DataCell(Text("100")),
            DataCell(Text("1")),
            DataCell(Text("2/2/26")),
            DataCell(Text("7PM-9PM")),
            DataCell(Text("Nicky")),
            DataCell(Text("RM100")),
            DataCell(Text("Unpaid")),
          ],
        ),
      ],
    );
  }

  /// SETTINGS TABLE (kept as your demo)
  Widget _settingsTable() {
    return DataTable(
      headingTextStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
      dataTextStyle: const TextStyle(color: Colors.white),
      columns: const [
        DataColumn(label: Text("Court")),
        DataColumn(label: Text("Type")),
        DataColumn(label: Text("Non-Peak Rate")),
        DataColumn(label: Text("Peak Rate")),
      ],
      rows: const [
        DataRow(
          cells: [
            DataCell(Text("1")),
            DataCell(Text("Standard")),
            DataCell(Text("RM35")),
            DataCell(Text("RM50")),
          ],
        ),
        DataRow(
          cells: [
            DataCell(Text("7")),
            DataCell(Text("VIP")),
            DataCell(Text("RM40")),
            DataCell(Text("RM55")),
          ],
        ),
      ],
    );
  }

  /// ✅ INCIDENTS TABLE (Firestore)
  Widget _incidentsTable() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _incidentsStream(),
      builder: (context, snap) {
        final headingStyle = const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        );
        final dataStyle = const TextStyle(color: Colors.white);

        if (snap.hasError) {
          return Text("Incidents error: ${snap.error}",
              style: const TextStyle(color: Colors.white));
        }

        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Text(
            "No incidents found yet.",
            style: TextStyle(color: Colors.white70),
          );
        }

        final rows = <DataRow>[];

        for (final d in docs) {
          final m = d.data();
          final raw = (m["rawText"] ?? m["title"] ?? "").toString();

          final ai = m["ai"];
          final status = (m["status"] ?? "").toString();

          String severity = "unknown";
          String category = "unknown";
          String summary = "Generating…";

          if (ai is Map<String, dynamic>) {
            final s = (ai["severity"] ?? "").toString().trim();
            final c = (ai["category"] ?? "").toString().trim();
            final sum = (ai["summary"] ?? "").toString().trim();

            if (s.isNotEmpty) severity = s;
            if (c.isNotEmpty) category = c;
            if (sum.isNotEmpty) summary = sum;
          } else {
            // no ai yet
            summary = status.isNotEmpty ? status : "ai_running";
          }

          rows.add(
            DataRow(
              cells: [
                DataCell(Text(raw)),
                DataCell(Text(_cap(severity))),
                DataCell(Text(_cap(category))),
                DataCell(Text(summary)),
                DataCell(Text(d.id)),
              ],
            ),
          );
        }

        return DataTable(
          headingTextStyle: headingStyle,
          dataTextStyle: dataStyle,
          columns: const [
            DataColumn(label: Text("Incident")),
            DataColumn(label: Text("Severity")),
            DataColumn(label: Text("Category")),
            DataColumn(label: Text("AI Summary")),
            DataColumn(label: Text("ID")),
          ],
          rows: rows,
        );
      },
    );
  }

  String _cap(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}
