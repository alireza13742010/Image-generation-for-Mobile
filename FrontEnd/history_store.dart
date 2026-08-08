import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'history_entry.dart';

/// Reads/writes generation history to the device's app-documents folder,
/// which Android/iOS keep around across app restarts (and even app
/// updates) — unlike in-memory state, which is lost on exit.
class HistoryStore {
  static const _indexFileName = 'history_index.json';

  Future<Directory> _historyDir() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${docsDir.path}/zimage_history');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<List<HistoryEntry>> load() async {
    final dir = await _historyDir();
    final indexFile = File('${dir.path}/$_indexFileName');
    if (!await indexFile.exists()) return [];

    final raw = await indexFile.readAsString();
    if (raw.trim().isEmpty) return [];

    final list = jsonDecode(raw) as List<dynamic>;
    final entries = list
        .map((e) => HistoryEntry.fromJson(e as Map<String, dynamic>))
        .toList();
    // Newest first.
    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return entries;
  }

  Future<HistoryEntry> add({
    required String prompt,
    required int steps,
    required double guidanceScale,
    required Uint8List imageBytes,
  }) async {
    final dir = await _historyDir();
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final fileName = '$id.png';

    final imageFile = File('${dir.path}/$fileName');
    await imageFile.writeAsBytes(imageBytes);

    final entry = HistoryEntry(
      id: id,
      prompt: prompt,
      steps: steps,
      guidanceScale: guidanceScale,
      imageFileName: fileName,
      createdAt: DateTime.now(),
    );

    final current = await load();
    current.insert(0, entry);
    await _writeIndex(dir, current);

    return entry;
  }

  Future<File> imageFile(HistoryEntry entry) async {
    final dir = await _historyDir();
    return File('${dir.path}/${entry.imageFileName}');
  }

  Future<void> _writeIndex(Directory dir, List<HistoryEntry> entries) async {
    final indexFile = File('${dir.path}/$_indexFileName');
    final raw = jsonEncode(entries.map((e) => e.toJson()).toList());
    await indexFile.writeAsString(raw);
  }
}