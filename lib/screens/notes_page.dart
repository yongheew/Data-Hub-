import 'package:flutter/material.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  int selectedIndex = 0; // 0 = Others, 1 = Court, 2 = Paddles

  final Map<int, List<String>> notes = {
    0: [
      "Erica : Aircon Remote Missing",
      "Calvin : Supplier will come over later at 5PM",
    ],
    1: [],
    2: [],
  };

  final Map<int, TextEditingController> controllers = {};

  @override
  void initState() {
    super.initState();
    for (var key in notes.keys) {
      controllers[key] = TextEditingController(text: notes[key]!.join("\n"));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2F436E),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Notes",
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
                  _addButton(),
                  const SizedBox(width: 10),
                  _tabButton("Others", 0),
                  const SizedBox(width: 10),
                  _tabButton("Court", 1),
                  const SizedBox(width: 10),
                  _tabButton("Paddles", 2),
                ],
              ),

              const SizedBox(height: 20),

              /// NOTE CARD
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F2F2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      /// HEADER BAR
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: const BoxDecoration(
                          color: Color(0xFFE6E6E6),
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(20),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: const [
                                CircleAvatar(
                                  radius: 3,
                                  backgroundColor: Colors.black,
                                ),
                                SizedBox(width: 6),
                                CircleAvatar(
                                  radius: 3,
                                  backgroundColor: Colors.black,
                                ),
                                SizedBox(width: 6),
                                CircleAvatar(
                                  radius: 3,
                                  backgroundColor: Colors.black,
                                ),
                              ],
                            ),
                            const Text(
                              "DATE : 02/02/2026",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      /// LINED PAPER
                      Expanded(
                        child: CustomPaint(
                          painter: _LinePainter(),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: TextField(
                              controller: controllers[selectedIndex],
                              maxLines: null,
                              expands: true,
                              keyboardType: TextInputType.multiline,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                isCollapsed: true,
                              ),
                              onChanged: (value) {
                                notes[selectedIndex] = value.split("\n");
                              },
                            ),
                          ),
                        ),
                      ),
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

  Widget _addButton() {
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
    final bool isSelected = selectedIndex == index;

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
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1;

    const double spacing = 26;

    for (double y = spacing; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
