import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/document.dart';

class DocumentService {
  static const _docsKey = 'accessvault_documents';

  static Future<Directory> _vaultDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'AccessVault'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<List<Document>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_docsKey) ?? [];
    final docs = <Document>[];
    for (final s in raw) {
      try {
        final doc = Document.fromJson(
            Map<String, dynamic>.from(jsonDecode(s) as Map));
        // Skip entries whose file no longer exists on disk
        if (await File(doc.localPath).exists()) {
          docs.add(doc);
        }
      } catch (_) {}
    }
    return docs;
  }

  static Future<void> _saveAll(List<Document> docs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _docsKey,
      docs.map((d) => jsonEncode(d.toJson())).toList(),
    );
  }

  /// Copies [sourcePath] into the vault directory and persists metadata.
  static Future<Document> importFile(String sourcePath) async {
    final dir = await _vaultDir();
    final fileName = p.basename(sourcePath);
    final ext = p.extension(fileName).replaceFirst('.', '');
    final type = documentTypeFromExtension(ext);

    // Avoid collisions by prefixing with timestamp millis
    final destName =
        '${DateTime.now().millisecondsSinceEpoch}_$fileName';
    final destPath = p.join(dir.path, destName);

    await File(sourcePath).copy(destPath);

    final doc = Document(
      id: destName,
      name: fileName,
      localPath: destPath,
      type: type,
      dateAdded: DateTime.now(),
    );

    final existing = await loadAll();
    await _saveAll([...existing, doc]);
    return doc;
  }

  static Future<void> delete(Document doc) async {
    final file = File(doc.localPath);
    if (await file.exists()) {
      try {
        await file.delete();
      } catch (e) {
        debugPrint('Could not delete file: $e');
      }
    }
    final existing = await loadAll();
    await _saveAll(existing.where((d) => d.id != doc.id).toList());
  }
}
