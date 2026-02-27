import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

void main() {
  runApp(const SmartNoteApp());
}

// 1. MODEL & JSON SERIALIZATION
class Note {
  String id;
  String title;
  String content;
  DateTime dateTime;

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.dateTime,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'dateTime': dateTime.toIso8601String(),
  };

  factory Note.fromJson(Map<String, dynamic> json) => Note(
    id: json['id'],
    title: json['title'],
    content: json['content'],
    dateTime: DateTime.parse(json['dateTime']),
  );
}

class SmartNoteApp extends StatelessWidget {
  const SmartNoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Note',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.amber),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

// 2. MÀN HÌNH CHÍNH (HOME SCREEN)
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Note> _allNotes = [];
  List<Note> _filteredNotes = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  // Local Storage: Đọc dữ liệu
  Future<void> _loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final String? notesJson = prefs.getString('notes_data');
    if (notesJson != null) {
      final List<dynamic> decoded = jsonDecode(notesJson);
      setState(() {
        _allNotes = decoded.map((item) => Note.fromJson(item)).toList();
        _allNotes.sort((a, b) => b.dateTime.compareTo(a.dateTime));
        _filteredNotes = _allNotes;
      });
    }
  }

  // Local Storage: Lưu dữ liệu
  Future<void> _saveNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(_allNotes.map((n) => n.toJson()).toList());
    await prefs.setString('notes_data', encoded);
  }

  void _filterNotes(String query) {
    setState(() {
      _filteredNotes = _allNotes
          .where((n) => n.title.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  void _deleteNote(int index) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc chắn muốn xóa ghi chú này không?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Xóa', style: TextStyle(color: Colors.red))),
        ],
      ),
    ) ?? false;

    if (confirm) {
      setState(() {
        _allNotes.removeWhere((n) => n.id == _filteredNotes[index].id);
        _filterNotes(_searchController.text);
      });
      _saveNotes();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Note - Phạm Văn Tài - 2005'), // ĐỊNH DANH BẮT BUỘC
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // Thanh tìm kiếm
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              onChanged: _filterNotes,
              decoration: InputDecoration(
                hintText: 'Tìm kiếm tiêu đề...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          // Danh sách Ghi chú (Grid 2 cột)
          Expanded(
            child: _filteredNotes.isEmpty
                ? _buildEmptyState()
                : MasonryGridView.count(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              itemCount: _filteredNotes.length,
              itemBuilder: (context, index) {
                final note = _filteredNotes[index];
                return _buildNoteCard(note, index);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToEdit(null),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.note_alt_outlined, size: 80, color: Colors.grey.withOpacity(0.5)),
          const SizedBox(height: 16),
          const Text("Bạn chưa có ghi chú nào, hãy tạo mới nhé!", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildNoteCard(Note note, int index) {
    return Dismissible(
      key: Key(note.id),
      direction: DismissDirection.horizontal,
      background: Container(
        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(15)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        _deleteNote(index);
        return false; // Không xóa ngay để đợi confirm dialog
      },
      child: GestureDetector(
        onTap: () => _navigateToEdit(note),
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(note.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Text(note.content, style: TextStyle(color: Colors.grey[700], fontSize: 14), maxLines: 3, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 12),
                Text(DateFormat('dd/MM/yyyy HH:mm').format(note.dateTime), style: const TextStyle(fontSize: 10, color: Colors.blueGrey)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToEdit(Note? note) async {
    await Navigator.push(context, MaterialPageRoute(builder: (context) => EditNoteScreen(note: note)));
    _loadNotes(); // Tự động Refresh khi Back
  }
}

// 3. MÀN HÌNH SOẠN THẢO (AUTO-SAVE)
class EditNoteScreen extends StatefulWidget {
  final Note? note;
  const EditNoteScreen({super.key, this.note});

  @override
  State<EditNoteScreen> createState() => _EditNoteScreenState();
}

class _EditNoteScreenState extends State<EditNoteScreen> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  bool _isModified = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _contentController = TextEditingController(text: widget.note?.content ?? '');
  }

  Future<void> _handleAutoSave() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty && content.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final String? notesJson = prefs.getString('notes_data');
    List<Note> notes = [];
    if (notesJson != null) {
      final List<dynamic> decoded = jsonDecode(notesJson);
      notes = decoded.map((item) => Note.fromJson(item)).toList();
    }

    if (widget.note == null) {
      // Tạo mới
      notes.add(Note(id: DateTime.now().toString(), title: title.isEmpty ? "Không tiêu đề" : title, content: content, dateTime: DateTime.now()));
    } else {
      // Cập nhật
      int idx = notes.indexWhere((n) => n.id == widget.note!.id);
      if (idx != -1) {
        notes[idx].title = title;
        notes[idx].content = content;
        notes[idx].dateTime = DateTime.now();
      }
    }

    await prefs.setString('notes_data', jsonEncode(notes.map((n) => n.toJson()).toList()));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) await _handleAutoSave(); // AUTO-SAVE KHI BACK
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(elevation: 0, backgroundColor: Colors.white),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              TextField(
                controller: _titleController,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(hintText: 'Tiêu đề', border: InputBorder.none),
              ),
              const Divider(),
              Expanded(
                child: TextField(
                  controller: _contentController,
                  maxLines: null,
                  decoration: const InputDecoration(hintText: 'Nội dung ghi chú...', border: InputBorder.none),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}