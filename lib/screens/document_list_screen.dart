import 'package:flutter/material.dart';
import '../models/document.dart';
import '../widgets/document_tile.dart';

class DocumentListScreen extends StatefulWidget {
  const DocumentListScreen({super.key});

  @override
  State<DocumentListScreen> createState() => _DocumentListScreenState();
}

class _DocumentListScreenState extends State<DocumentListScreen> {
  bool _refreshing = false;

  // Placeholder documents — replace with real data later
  final List<Document> _documents = [
    Document(name: 'Passport Scan', type: DocumentType.image, date: DateTime.now()),
    Document(name: 'Tax Return 2024', type: DocumentType.pdf, date: DateTime.now().subtract(const Duration(days: 2))),
    Document(name: 'Employment Contract', type: DocumentType.word, date: DateTime.now().subtract(const Duration(days: 5))),
    Document(name: 'Bank Statements Q1', type: DocumentType.spreadsheet, date: DateTime.now().subtract(const Duration(days: 10))),
    Document(name: 'Insurance Policy', type: DocumentType.pdf, date: DateTime.now().subtract(const Duration(days: 14))),
    Document(name: 'Medical Records', type: DocumentType.generic, date: DateTime.now().subtract(const Duration(days: 20))),
    Document(name: 'Property Deed', type: DocumentType.pdf, date: DateTime.now().subtract(const Duration(days: 30))),
    Document(name: 'Driver License Photo', type: DocumentType.image, date: DateTime.now().subtract(const Duration(days: 45))),
  ];

  Future<void> _onRefresh() async {
    setState(() => _refreshing = true);
    await Future.delayed(const Duration(milliseconds: 800));
    setState(() => _refreshing = false);
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
              // TODO: navigate to settings
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              '${_documents.length} documents',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _onRefresh,
              child: ListView.separated(
                itemCount: _documents.length,
                separatorBuilder: (_, __) => const Divider(height: 1, indent: 76),
                itemBuilder: (context, index) =>
                    DocumentTile(document: _documents[index]),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: add document
        },
        tooltip: 'Add document',
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}
