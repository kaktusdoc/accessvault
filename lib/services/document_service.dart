import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/document.dart';
import 'crypto_service.dart';

class DocumentService {
  static const _docsKey = 'accessvault_documents';

  static Future<Directory> _vaultDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'AccessVault'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Scratch directory for plaintext files decrypted for viewing. Never
  /// holds anything longer than necessary — see [clearTempFiles].
  static Future<Directory> _tempDir() async {
    final base = await getTemporaryDirectory();
    final dir = Directory(p.join(base.path, 'AccessVaultOpen'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Best-effort wipe of any decrypted-for-viewing temp files. Call on app
  /// startup (covers a prior session that didn't get to close cleanly) and
  /// when the app is backgrounded/closed.
  static Future<void> clearTempFiles() async {
    try {
      final dir = await _tempDir();
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (e) {
      debugPrint('Could not clear temp files: $e');
    }
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

  /// Encrypts [sourcePath]'s contents into the vault directory and persists
  /// metadata. Requires the vault to be unlocked.
  static Future<Document> importFile(String sourcePath) async {
    final dir = await _vaultDir();
    final fileName = p.basename(sourcePath);
    final ext = p.extension(fileName).replaceFirst('.', '');
    final type = documentTypeFromExtension(ext);

    // Avoid collisions by prefixing with timestamp millis
    final destName =
        '${DateTime.now().millisecondsSinceEpoch}_$fileName';
    final destPath = p.join(dir.path, destName);

    final plainBytes = await File(sourcePath).readAsBytes();
    final cipherBytes = CryptoService.encryptBytes(plainBytes);
    await File(destPath).writeAsBytes(cipherBytes);

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

  /// Encrypts [bytes] and writes them into the vault directory under
  /// [filename], persisting metadata. For files pulled down from the sync
  /// server (which transfers plaintext). Requires the vault to be unlocked.
  static Future<Document> saveDownloadedFile(
      String filename, List<int> bytes) async {
    final dir = await _vaultDir();
    final ext = p.extension(filename).replaceFirst('.', '');
    final type = documentTypeFromExtension(ext);

    final destName = '${DateTime.now().millisecondsSinceEpoch}_$filename';
    final destPath = p.join(dir.path, destName);

    final cipherBytes = CryptoService.encryptBytes(Uint8List.fromList(bytes));
    await File(destPath).writeAsBytes(cipherBytes);

    final doc = Document(
      id: destName,
      name: filename,
      localPath: destPath,
      type: type,
      dateAdded: DateTime.now(),
    );

    final existing = await loadAll();
    await _saveAll([...existing, doc]);
    return doc;
  }

  /// Decrypts [doc]'s on-disk contents and returns the plaintext bytes.
  /// Used for sync upload, where the server expects plaintext.
  static Future<Uint8List> decryptDocument(Document doc) async {
    final cipherBytes = await File(doc.localPath).readAsBytes();
    return CryptoService.decryptBytes(cipherBytes);
  }

  /// Decrypts [doc] into a fresh temp file (named after the original file
  /// so external viewers see the right extension) for "Open". Caller should
  /// attempt to delete the returned file once done with it; any file left
  /// behind is swept up by [clearTempFiles].
  static Future<File> decryptToTempFile(Document doc) async {
    final plainBytes = await decryptDocument(doc);
    final dir = await _tempDir();
    final destName = '${DateTime.now().millisecondsSinceEpoch}_${doc.name}';
    final destPath = p.join(dir.path, destName);
    final file = File(destPath);
    await file.writeAsBytes(plainBytes);
    return file;
  }

  /// Re-encrypts every document on disk from [oldKey] to [newKey], used
  /// when changing the PIN. Decrypts everything first; if any document
  /// fails to decrypt, nothing is written and a [CryptoException] is
  /// thrown, leaving the vault untouched.
  static Future<void> reencryptAll(
      Uint8List oldKey, Uint8List newKey) async {
    final docs = await loadAll();

    final plaintexts = <String, Uint8List>{};
    for (final doc in docs) {
      final cipherBytes = await File(doc.localPath).readAsBytes();
      plaintexts[doc.id] =
          CryptoService.decryptBytesWithKey(cipherBytes, oldKey);
    }

    for (final doc in docs) {
      final plain = plaintexts[doc.id]!;
      final newCipher = CryptoService.encryptBytesWithKey(plain, newKey);
      await File(doc.localPath).writeAsBytes(newCipher);
    }
  }

  static Future<Document> rename(Document doc, String newName) async {
    final updated = doc.copyWith(name: newName);
    final existing = await loadAll();
    final updated2 = existing.map((d) => d.id == doc.id ? updated : d).toList();
    await _saveAll(updated2);
    return updated;
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
