import 'dart:async';

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

  // Default tabs (ensured in Firestore)
  final List<String> tabNames = ["Others", "Court", "Paddles"];

  // Controllers per tab index
  final Map<int, TextEditingController> controllers = {};

  // Firestore + Auth
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // Mapping index -> tabId (from notesTabs docs)
  final Map<int, String> _tabIdByIndex = {};

  // Store updatedAt per tabId (from tabs stream)
  final Map<String, Timestamp?> _tabUpdatedAtById = {};

  // For date display (selected tab updatedAt)
  Timestamp? _selectedTabUpdatedAt;

  // Editor focus (avoid overwriting while typing)
  final FocusNode _editorFocus = FocusNode();

  // Debounce save
  Timer? _saveDebounce;

  // Migration flags
  final Set<String> _migratedTabIds = {};
  final Set<String> _migrationStarted = {};

  // Cache per tabId so switching is instant and no “blank flash”
  final Map<String, String> _cachedTextByTabId = {};

  // Active tab streaming subscription (THIS is the key fix)
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _linesSub;
  String? _activeTabId;

  String? get _uid => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> _tabsCol(String uid) =>
      _db.collection("users").doc(uid).collection("notesTabs");

  // NEW structure: users/{uid}/notesTabs/{tabId}/lines/{lineId}
  CollectionReference<Map<String, dynamic>> _linesCol(String uid, String tabId) =>
      _db
          .collection("users")
          .doc(uid)
          .collection("notesTabs")
          .doc(tabId)
          .collection("lines");

  // OLD structure: users/{uid}/notes
  CollectionReference<Map<String, dynamic>> _oldNotesCol(String uid) =>
      _db.collection("users").doc(uid).collection("notes");

  @override
  void initState() {
    super.initState();

    for (var i = 0; i < tabNames.length; i++) {
      controllers[i] = TextEditingController(text: "");
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _ensureDefaultTabsExist();
    });
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _linesSub?.cancel();
    _editorFocus.dispose();
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // -----------------------------
  // Ensure default tabs exist
  // -----------------------------
  Future<void> _ensureDefaultTabsExist() async {
    final uid = _uid;
    if (uid == null) return;

    final col = _tabsCol(uid);

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
      } else {
        await ref.set({
          "name": (snap.data()?["name"] ?? d["name"]),
          "createdAt": snap.data()?["createdAt"] ?? FieldValue.serverTimestamp(),
          "updatedAt": snap.data()?["updatedAt"] ?? FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }
  }

  // -----------------------------
  // Tabs stream
  // -----------------------------
  Stream<QuerySnapshot<Map<String, dynamic>>> _tabsStream() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();
    return _tabsCol(uid).orderBy("createdAt", descending: false).snapshots();
  }

  // -----------------------------
  // Start + maintain active tab listener (NO MORE “must switch tabs”)
  // -----------------------------
  void _activateTab(String tabId) {
    if (_activeTabId == tabId) return;
    _activeTabId = tabId;

    // show cached immediately (if any)
    final cached = _cachedTextByTabId[tabId];
    final ctrl = controllers[selectedIndex];
    if (cached != null && ctrl != null && !_editorFocus.hasFocus) {
      if (ctrl.text != cached) ctrl.text = cached;
    }

    // kick migration in background (doesn't block UI)
    _startMigrationIfNeeded(tabId);

    // cancel previous listener
    _linesSub?.cancel();

    final uid = _uid;
    if (uid == null) return;

    // subscribe to lines for this tab and keep controller updated
    _linesSub = _linesCol(uid, tabId)
        .orderBy("lineIndex", descending: false)
        .snapshots()
        .listen((snap) {
      // build joined text
      final lines = snap.docs.map((d) => (d.data()["text"] ?? "").toString()).toList();
      final joined = lines.join("\n");

      // cache it
      _cachedTextByTabId[tabId] = joined;

      // only push into UI if this tab is still active
      if (_activeTabId != tabId) return;

      // update controller if user not typing
      final currentCtrl = controllers[selectedIndex];
      if (currentCtrl == null) return;

      if (!_editorFocus.hasFocus && currentCtrl.text != joined) {
        currentCtrl.text = joined;
      }
    });
  }

  // -----------------------------
  // Background migration (old /notes -> new subcollection)
  // -----------------------------
  void _startMigrationIfNeeded(String tabId) {
    if (_migratedTabIds.contains(tabId)) return;
    if (_migrationStarted.contains(tabId)) return;

    _migrationStarted.add(tabId);

    migrateOldNotesIfNeeded(tabId).catchError(() {
      // ignore; UI still works
    });
  }

  Future<void> _migrateOldNotesIfNeeded(String tabId) async {
    final uid = _uid;
    if (uid == null) return;

    if (_migratedTabIds.contains(tabId)) return;

    // If new already has lines -> done
    final newSnap = await _linesCol(uid, tabId).limit(1).get();
    if (newSnap.docs.isNotEmpty) {
      _migratedTabIds.add(tabId);
      return;
    }

    // Read old notes for this tab (NO orderBy to avoid index)
    final oldSnap = await _oldNotesCol(uid).where("tabId", isEqualTo: tabId).get();
    if (oldSnap.docs.isEmpty) {
      _migratedTabIds.add(tabId);
      return;
    }

    final oldDocs = oldSnap.docs.map((d) {
      final m = d.data();
      return {
        "text": (m["text"] ?? "").toString(),
        "lineIndex": (m["lineIndex"] is int) ? (m["lineIndex"] as int) : 0,
        "createdAt": m["createdAt"],
        "updatedAt": m["updatedAt"],
      };
    }).toList();

    oldDocs.sort((a, b) => (a["lineIndex"] as int).compareTo(b["lineIndex"] as int));

    final batch = _db.batch();
    for (final row in oldDocs) {
      final ref = _linesCol(uid, tabId).doc();
      batch.set(ref, {
        "text": row["text"],
        "lineIndex": row["lineIndex"],
        "createdAt": row["createdAt"] ?? FieldValue.serverTimestamp(),
        "updatedAt": row["updatedAt"] ?? FieldValue.serverTimestamp(),
      });
    }

    batch.set(
      _tabsCol(uid).doc(tabId),
      {"updatedAt": FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );

    await batch.commit();
    _migratedTabIds.add(tabId);
  }

  // -----------------------------
  // Save editor -> new lines subcollection (replace all lines)
  // -----------------------------
  Future<void> _saveSelectedTabContent(String value) async {
    final uid = _uid;
    if (uid == null) return;

    final tabId = _tabIdByIndex[selectedIndex];
    if (tabId == null) return;

    // cache immediately so UI never “goes blank”
    _cachedTextByTabId[tabId] = value;

    final lines = value.split("\n").map((s) => s.trimRight()).toList();

    final prev = await _linesCol(uid, tabId).get();
    final batch = _db.batch();
    for (final d in prev.docs) {
      batch.delete(d.reference);
    }

    int idx = 0;
    for (int i = 0; i < lines.length; i++) {
      final text = lines[i].trim();
      if (text.isEmpty) continue;

      final ref = _linesCol(uid, tabId).doc();
      batch.set(ref, {
        "text": text,
        "lineIndex": idx,
        "createdAt": FieldValue.serverTimestamp(),
        "updatedAt": FieldValue.serverTimestamp(),
      });
      idx++;
    }

    batch.set(
      _tabsCol(uid).doc(tabId),
      {"updatedAt": FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  void _onEditorChanged(String value) {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 500), () {
      _saveSelectedTabContent(value);
    });
  }

  // -----------------------------
  // Create new tab
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
            decoration: const InputDecoration(hintText: "Enter name"),
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

    await _tabsCol(uid).add({
      "name": name.trim(),
      "createdAt": FieldValue.serverTimestamp(),
      "updatedAt": FieldValue.serverTimestamp(),
    });
  }

  // -----------------------------
  // Date formatting
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
      appBar: AppBar(
        backgroundColor: const Color(0xFF2F436E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
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

              // Tabs row
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

                  if (snap.hasError) {
                    return Text(
                      "Tabs error: ${snap.error}",
                      style: const TextStyle(color: Colors.white),
                    );
                  }

                  if (!snap.hasData) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  }

                  final docs = snap.data!.docs;

                  final dynamicTabNames = <String>[];
                  _tabIdByIndex.clear();
                  _tabUpdatedAtById.clear();

                  for (int i = 0; i < docs.length; i++) {
                    final d = docs[i];
                    final data = d.data();
                    final name = (data["name"] ?? d.id).toString();
                    dynamicTabNames.add(name);
                    _tabIdByIndex[i] = d.id;
                    _tabUpdatedAtById[d.id] = data["updatedAt"] as Timestamp?;
                  }

                  if (dynamicTabNames.isNotEmpty && selectedIndex >= dynamicTabNames.length) {
                    selectedIndex = 0;
                  }

                  // Ensure controllers exist
                  for (int i = 0; i < dynamicTabNames.length; i++) {
                    controllers.putIfAbsent(i, () => TextEditingController(text: ""));
                  }

                  // Update date for selected tab
                  final currentTabId = _tabIdByIndex[selectedIndex];
                  _selectedTabUpdatedAt =
                      currentTabId == null ? null : _tabUpdatedAtById[currentTabId];

                  // IMPORTANT: activate the selected tab stream AFTER this build frame
                  if (currentTabId != null) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      _activateTab(currentTabId);
                    });
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

              // Note card
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F2F2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      // Header bar with date
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: const BoxDecoration(
                          color: Color(0xFFE6E6E6),
                          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: const [
                                CircleAvatar(radius: 3, backgroundColor: Colors.black),
                                SizedBox(width: 6),
                                CircleAvatar(radius: 3, backgroundColor: Colors.black),
                                SizedBox(width: 6),
                                CircleAvatar(radius: 3, backgroundColor: Colors.black),
                              ],
                            ),
                            Text(
                              "DATE : ${_formatDate(_selectedTabUpdatedAt)}",
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),

                      // Editor (always visible)
                      Expanded(
                        child: CustomPaint(
                          painter: _LinePainter(),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: TextField(
                              focusNode: _editorFocus,
                              controller: controllers[selectedIndex],
                              maxLines: null,
                              expands: true,
                              keyboardType: TextInputType.multiline,
                              style: const TextStyle(fontSize: 14, color: Colors.black87),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                isCollapsed: true,
                              ),
                              onChanged: _onEditorChanged,
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
        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }

  Widget _tabButton(String text, int index) {
    final bool isSelected = selectedIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedIndex = index;
        });

        final tabId = _tabIdByIndex[index];
        if (tabId != null) {
          // update date immediately
          setState(() {
            _selectedTabUpdatedAt = _tabUpdatedAtById[tabId];
          });

          // activate stream for this tab (will populate immediately when snapshot arrives)
          _activateTab(tabId);
        }
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
