import 'package:flutter/material.dart';

enum DocumentType { pdf, image, word, spreadsheet, generic }

class Document {
  final String name;
  final DocumentType type;
  final DateTime date;

  const Document({required this.name, required this.type, required this.date});
}

extension DocumentTypeDisplay on DocumentType {
  String get label {
    switch (this) {
      case DocumentType.pdf:
        return 'PDF';
      case DocumentType.image:
        return 'Image';
      case DocumentType.word:
        return 'Document';
      case DocumentType.spreadsheet:
        return 'Spreadsheet';
      case DocumentType.generic:
        return 'File';
    }
  }

  IconData get icon {
    switch (this) {
      case DocumentType.pdf:
        return Icons.picture_as_pdf_rounded;
      case DocumentType.image:
        return Icons.image_rounded;
      case DocumentType.word:
        return Icons.article_rounded;
      case DocumentType.spreadsheet:
        return Icons.table_chart_rounded;
      case DocumentType.generic:
        return Icons.insert_drive_file_rounded;
    }
  }

  Color get color {
    switch (this) {
      case DocumentType.pdf:
        return const Color(0xFFE53935);
      case DocumentType.image:
        return const Color(0xFF1E88E5);
      case DocumentType.word:
        return const Color(0xFF1565C0);
      case DocumentType.spreadsheet:
        return const Color(0xFF2E7D32);
      case DocumentType.generic:
        return const Color(0xFF757575);
    }
  }
}
