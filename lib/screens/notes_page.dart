import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  int selectedIndex = 0;

  // Keep your initial default names (will also be created in Firestore if missing)
  final List<String> tabNames = ["Others", "Court", "Paddles"];

  // Controllers per tab
  final Map<int, TextEditingController> controllers = {};

  // Firestore
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // Store tabId per index (so renaming/reordering won’t break)
  final Map<int, String> _tabIdByIndex = {};

  // For dynamic date display (last updated for selected tab)
  Timestamp? _selectedTabUpdatedAt;

  @override
  void initState() {
    super.initState();

    for (var i = 0; i < tabNames.length; i++) {
      controllers[i] = TextEditingController(text: "");
    }

    // Ensure defaults exist in DB and load initial content
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _ensureDefaultTabsExist();
      await _loadSelectedTabContent();
    });
  }

  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String? get _uid => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> _tabsCol(String uid) =>
      _db.collection("users").doc(uid).collection("notesTabs");

  CollectionReference<Map<String, dynamic>> _notesCol(String uid) =>
      _db.collection("users").doc(uid).collection("notes");

  // -----------------------------
  // Firestore: ensure default tabs exist
  // -----------------------------
  Future<void> _ensureDefaultTabsExist() async {
    final uid = _uid;
    if (uid == null) return;

    final col = _tabsCol(uid);

    // Use fixed IDs so we can reliably find them
    final defaults = [
      {"id": "others", "name": "Others"},
      {"id": "court", "name": "Court"},
      {"id": "paddles", "name": "Paddles"},
    ];

    for (final d in defaults) {
      final ref = col.doc(d["id"] as String);
      final snap = await ref.get();
      if (!snap.exists) {
        await ref.set({
          "name": d["name"],
          "createdAt": FieldValue.serverTimestamp(),
          "updatedAt": FieldValue.serverTimestamp(),
        });
      }
    }
  }

  // -----------------------------
  // Firestore: stream tabs list
  // -----------------------------
  Stream<QuerySnapshot<Map<String, dynamic>>> _tabsStream() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();
    return _tabsCol(uid).orderBy("createdAt", descending: false).snapshots();
  }

  // -----------------------------
  // Load selected tab notes into controller
  // -----------------------------
  Future<void> _loadSelectedTabContent() async {
    final uid = _uid;
    if (uid == null) return;

    final tabId = _tabIdByIndex[selectedIndex];
    if (tabId == null) return;

    final snap = await _notesCol(uid)
        .where("tabId", isEqualTo: tabId)
        .orderBy("lineIndex", descending: false)
        .get();

    final lines = snap.docs
        .map((d) => (d.data()["text"] ?? "").toString())
        .where((t) => t.trim().isNotEmpty)
        .toList();

    controllers[selectedIndex]?.text = lines.join("\n");

    // Also load tab updatedAt for dynamic date
    final tabSnap = await _tabsCol(uid).doc(tabId).get();
    final data = tabSnap.data();
    _selectedTabUpdatedAt = data?["updatedAt"] as Timestamp?;
    if (mounted) setState(() {});
  }

  // -----------------------------
  // Save controller text -> Firestore (replace all lines for that tab)
  // -----------------------------
  Future<void> _saveSelectedTabContent(String value) async {
    final uid = _uid;
    if (uid == null) return;

    final tabId = _tabIdByIndex[selectedIndex];
    if (tabId == null) return;

    // Split lines
    final lines = value.split("\n").map((s) => s.trimRight()).toList();

    // Delete previous notes for this tab
    final prev = await _notesCol(uid).where("tabId", isEqualTo: tabId).get();
    final batch = _db.batch();
    for (final d in prev.docs) {
      batch.delete(d.reference);
    }

    // Re-add current lines as separate docs (keeps ordering stable)
    for (int i = 0; i < lines.length; i++) {
      final text = lines[i].trim();
      if (text.isEmpty) continue;

      final ref = _notesCol(uid).doc();
      batch.set(ref, {
        "tabId": tabId,
        "text": text,
        "lineIndex": i,
        "updatedAt": FieldValue.serverTimestamp(),
        "createdAt": FieldValue.serverTimestamp(),
      });
    }

    // Update tab updatedAt (for date display)
    final tabRef = _tabsCol(uid).doc(tabId);
    batch.set(tabRef, {"updatedAt": FieldValue.serverTimestamp()}, SetOptions(merge: true));

    await batch.commit();

    // Refresh date in UI quickly
    final tabSnap = await _tabsCol(uid).doc(tabId).get();
    _selectedTabUpdatedAt = tabSnap.data()?["updatedAt"] as Timestamp?;
    if (mounted) setState(() {});
  }

  // -----------------------------
  // Create new block/tab in Firestore
  // -----------------------------
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

    final uid = _uid;
    if (uid == null) return;

    // Check duplicate (case-insensitive) from Firestore
    final existing = await _tabsCol(uid).get();
    final exists = existing.docs.any((d) {
      final n = (d.data()["name"] ?? "").toString().trim().toLowerCase();
      return n == name.trim().toLowerCase();
    });

    if (exists) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Block name already exists")),
        );
      }
      return;
    }

    // Add tab doc
    final ref = await _tabsCol(uid).add({
      "name": name.trim(),
      "createdAt": FieldValue.serverTimestamp(),
      "updatedAt": FieldValue.serverTimestamp(),
    });

    // After created, select it (we will rebuild indices from stream)
    // We'll set selectedIndex after stream rebuild finds it
    // For now, do nothing; UI will show it
    // You can optionally jump to last tab by setting selectedIndex later.
    if (mounted) setState(() {});
  }

  // -----------------------------
  // Date formatting (NOT hard-coded)
  // -----------------------------
  String _formatDate(Timestamp? ts) {
    final dt = (ts ?? Timestamp.fromDate(DateTime.now())).toDate();
    String two(int n) => n.toString().padLeft(2, "0");
    return "${two(dt.day)}/${two(dt.month)}/${dt.year}";
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),

              /// TOP BUTTONS (dynamic tabs from Firestore)
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _tabsStream(),
                builder: (context, snap) {
                  final uid = _uid;

                  if (uid == null) {
                    return const Text(
                      "Please login first.",
                      style: TextStyle(color: Colors.white),
                    );
                  }

                  final docs = snap.data?.docs ?? [];

                  // Build tabNames + mapping
                  final dynamicTabNames = <String>[];
                  _tabIdByIndex.clear();

                  for (int i = 0; i < docs.length; i++) {
                    final d = docs[i];
                    final name = (d.data()["name"] ?? d.id).toString();
                    dynamicTabNames.add(name);
                    _tabIdByIndex[i] = d.id;
                  }

                  // Safety: clamp selectedIndex
                  if (dynamicTabNames.isNotEmpty && selectedIndex >= dynamicTabNames.length) {
                    selectedIndex = 0;
                  }

                  // Ensure controllers exist for all tabs
                  for (int i = 0; i < dynamicTabNames.length; i++) {
                    controllers.putIfAbsent(i, () => TextEditingController(text: ""));
                  }

                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _addButton(),
                        const SizedBox(width: 10),
                        ...List.generate(dynamicTabNames.length, (i) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: _tabButton(dynamicTabNames[i], i),
                          );
                        }),
                      ],
                    ),
                  );
                },
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
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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

                            /// shows selected tab last updated date (fallback = today)
                            Text(
                              "DATE : ${_formatDate(_selectedTabUpdatedAt)}",
                              style: const TextStyle(
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

                              /// SAVE TO FIRESTORE (so it won't disappear)
                              onChanged: (value) {
                                // Debounce not implemented (keeps it simple),
                                // but we can add debounce later for performance.
                                _saveSelectedTabContent(value);
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
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }

  Widget _tabButton(String text, int index) {
    final bool isSelected = selectedIndex == index;

    return GestureDetector(
      onTap: () async {
        setState(() {
          selectedIndex = index;
        });
        await _loadSelectedTabContent();
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
