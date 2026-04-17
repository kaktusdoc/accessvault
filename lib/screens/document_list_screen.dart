import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../models/document.dart';
import '../services/document_service.dart';
import '../widgets/document_tile.dart';
import 'document_detail_screen.dart';
import 'settings_screen.dart';

class DocumentListScreen extends StatefulWidget {
  const DocumentListScreen({super.key});

  @override
  State<DocumentListScreen> createState() => _DocumentListScreenState();
}

class _DocumentListScreenState extends State<DocumentListScreen> {
  List<Document> _documents = [];
  bool _loading = true;
  bool _refreshing = false;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final docs = await DocumentService.loadAll();
    if (!mounted) return;
    setState(() {
      _documents = docs;
      _loading = false;
      _refreshing = false;
    });
  }

  Future<void> _onRefresh() async {
    setState(() => _refreshing = true);
    await _load();
  }

  Future<void> _importDocument() async {
    setState(() => _importing = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp',
          'txt', 'doc', 'docx', 'rtf',
          'xls', 'xlsx', 'csv',
        ],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;

      final sourcePath = result.files.single.path;
      if (sourcePath == null) return;

      final doc = await DocumentService.importFile(sourcePath);
      if (!mounted) return;
      setState(() => _documents = [..._documents, doc]);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${doc.name}" added to vault'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Import failed: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFB71C1C),
        ),
      );
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _openDetail(Document doc) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DocumentDetailScreen(document: doc),
      ),
    );
    // Reload in case the user renamed the document
    _load();
  }

  Future<void> _deleteDocument(Document doc) async {
    await DocumentService.delete(doc);
    if (!mounted) return;
    setState(() => _documents = _documents.where((d) => d.id != doc.id).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'AccessVault',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: _refreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _refreshing ? null : _onRefresh,
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    '${_documents.length} document${_documents.length == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: _documents.isEmpty
                      ? _EmptyState(onImport: _importDocument)
                      : RefreshIndicator(
                          onRefresh: _onRefresh,
                          child: ListView.separated(
                            itemCount: _documents.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1, indent: 76),
                            itemBuilder: (context, index) {
                              final doc = _documents[index];
                              return DocumentTile(
                                key: ValueKey(doc.id),
                                document: doc,
                                onTap: () => _openDetail(doc),
                                onDelete: () => _deleteDocument(doc),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _importing ? null : _importDocument,
        tooltip: 'Import document',
        child: _importing
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.add_rounded),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onImport;
  const _EmptyState({required this.onImport});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open_rounded, size: 64, color: Colors.grey[700]),
          const SizedBox(height: 16),
          Text(
            'No documents yet',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w500,
                color: Colors.grey[500]),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to import your first file',
            style: TextStyle(fontSize: 13, color: Colors.grey[700]),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onImport,
            icon: const Icon(Icons.upload_file_rounded),
            label: const Text('Import document'),
          ),
        ],
      ),
    );
  }
}
