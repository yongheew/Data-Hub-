import 'package:flutter/material.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  int selectedIndex = 0;

  final List<String> tabNames = ["Others", "Court", "Paddles"];

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
    for (var i = 0; i < tabNames.length; i++) {
      controllers[i] =
          TextEditingController(text: notes[i]?.join("\n") ?? "");
    }
  }

  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _showCreateTabDialog() async {
    final controller = TextEditingController();

    final String? name = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Create new block"),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: "Enter name",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.isEmpty) return;
                Navigator.pop(context, text);
              },
              child: const Text("Create"),
            ),
          ],
        );
      },
    );

    if (name == null) return;

    final exists =
        tabNames.any((t) => t.toLowerCase() == name.toLowerCase());
    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Block name already exists")),
      );
      return;
    }

    setState(() {
      final newIndex = tabNames.length;

      tabNames.add(name);
      notes[newIndex] = [];
      controllers[newIndex] = TextEditingController(text: "");

      selectedIndex = newIndex;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2F436E),

      /// ✅ APP BAR WITH BACK BUTTON
      appBar: AppBar(
        backgroundColor: const Color(0xFF2F436E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          "Notes",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),

      body: SafeArea(
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),

              /// TOP BUTTONS
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _addButton(),
                    const SizedBox(width: 10),
                    ...List.generate(tabNames.length, (i) {
                      return Padding(
                        padding:
                            const EdgeInsets.only(right: 10),
                        child: _tabButton(tabNames[i], i),
                      );
                    }),
                  ],
                ),
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
                        padding:
                            const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10),
                        decoration:
                            const BoxDecoration(
                          color: Color(0xFFE6E6E6),
                          borderRadius:
                              BorderRadius.vertical(
                            top: Radius.circular(20),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment
                                  .spaceBetween,
                          children: [
                            Row(
                              children: const [
                                CircleAvatar(
                                  radius: 3,
                                  backgroundColor:
                                      Colors.black,
                                ),
                                SizedBox(width: 6),
                                CircleAvatar(
                                  radius: 3,
                                  backgroundColor:
                                      Colors.black,
                                ),
                                SizedBox(width: 6),
                                CircleAvatar(
                                  radius: 3,
                                  backgroundColor:
                                      Colors.black,
                                ),
                              ],
                            ),
                            const Text(
                              "DATE : 02/02/2026",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight:
                                    FontWeight.w500,
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
                            padding:
                                const EdgeInsets
                                    .symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: TextField(
                              controller:
                                  controllers[
                                      selectedIndex],
                              maxLines: null,
                              expands: true,
                              keyboardType:
                                  TextInputType
                                      .multiline,
                              style:
                                  const TextStyle(
                                fontSize: 14,
                                color:
                                    Colors.black87,
                              ),
                              decoration:
                                  const InputDecoration(
                                border:
                                    InputBorder
                                        .none,
                                isCollapsed:
                                    true,
                              ),
                              onChanged:
                                  (value) {
                                notes[
                                        selectedIndex] =
                                    value.split(
                                        "\n");
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
    return GestureDetector(
      onTap: _showCreateTabDialog,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child:
            const Icon(Icons.add, color: Colors.black),
      ),
    );
  }

  Widget _tabButton(String text, int index) {
    final bool isSelected =
        selectedIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedIndex = index;
        });
      },
      child: Container(
        padding:
            const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white
              : Colors.white24,
          borderRadius:
              BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected
                ? Colors.black
                : Colors.white,
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

    for (double y = spacing;
        y < size.height;
        y += spacing) {
      canvas.drawLine(
          Offset(0, y),
          Offset(size.width, y),
          paint);
    }
  }

  @override
  bool shouldRepaint(
          covariant CustomPainter oldDelegate) =>
      false;
}
