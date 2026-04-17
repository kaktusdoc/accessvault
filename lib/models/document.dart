import 'package:flutter/material.dart';

enum DocumentType { pdf, image, word, spreadsheet, generic }

DocumentType documentTypeFromExtension(String ext) {
  switch (ext.toLowerCase()) {
    case 'pdf':
      return DocumentType.pdf;
    case 'jpg':
    case 'jpeg':
    case 'png':
    case 'gif':
    case 'webp':
    case 'bmp':
      return DocumentType.image;
    case 'doc':
    case 'docx':
    case 'txt':
    case 'rtf':
      return DocumentType.word;
    case 'xls':
    case 'xlsx':
    case 'csv':
      return DocumentType.spreadsheet;
    default:
      return DocumentType.generic;
  }
}

class Document {
  final String id;
  final String name;
  final String localPath;
  final DocumentType type;
  final DateTime dateAdded;

  const Document({
    required this.id,
    required this.name,
    required this.localPath,
    required this.type,
    required this.dateAdded,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'localPath': localPath,
        'type': type.name,
        'dateAdded': dateAdded.toIso8601String(),
      };

  Document copyWith({String? name, String? localPath}) => Document(
        id: id,
        name: name ?? this.name,
        localPath: localPath ?? this.localPath,
        type: type,
        dateAdded: dateAdded,
      );

  factory Document.fromJson(Map<String, dynamic> json) => Document(
        id: json['id'] as String,
        name: json['name'] as String,
        localPath: json['localPath'] as String,
        type: DocumentType.values.byName(json['type'] as String),
        dateAdded: DateTime.parse(json['dateAdded'] as String),
      );

  static Document? tryFromJson(Map<String, dynamic> json) {
    try {
      return Document.fromJson(json);
    } catch (_) {
      return null;
    }
  }
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
