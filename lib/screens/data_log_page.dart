import 'package:flutter/material.dart';

class DataLogPage extends StatefulWidget {
  const DataLogPage({super.key});

  @override
  State<DataLogPage> createState() => _DataLogPageState();
}

class _DataLogPageState extends State<DataLogPage> {
  int selectedIndex = 0; // 0 = Inventory, 1 = Bookings, 2 = Settings

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
              const Text(
                "Data Log",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
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

              /// TABLE SECTION
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: _buildTable(),
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

  /// INVENTORY TABLE
  Widget _inventoryTable() {
    return DataTable(
      headingTextStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
      dataTextStyle: const TextStyle(color: Colors.white),
      columns: const [
        DataColumn(label: Text("Item")),
        DataColumn(label: Text("Brand")),
        DataColumn(label: Text("Supplier")),
        DataColumn(label: Text("Unit Price")),
        DataColumn(label: Text("Quantity")),
        DataColumn(label: Text("Last Updated")),
      ],
      rows: const [
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
      ],
    );
  }

  /// BOOKINGS TABLE
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

  /// SETTINGS TABLE
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
}
