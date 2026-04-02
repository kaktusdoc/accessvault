import 'package:flutter/material.dart';
import '../models/document.dart';

class DocumentTile extends StatelessWidget {
  final Document document;

  const DocumentTile({super.key, required this.document});

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '$diff days ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final type = document.type;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: type.color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(type.icon, color: type.color, size: 24),
      ),
      title: Text(
        document.name,
        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${type.label} • ${_formatDate(document.date)}',
        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
      ),
      trailing: Icon(Icons.chevron_right, color: Colors.grey[600], size: 20),
      onTap: () {},
    );
  }
}
