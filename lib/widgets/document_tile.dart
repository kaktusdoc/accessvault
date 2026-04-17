import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import '../models/document.dart';

class DocumentTile extends StatefulWidget {
  final Document document;
  final VoidCallback onDelete;
  final VoidCallback? onTap;

  const DocumentTile({
    super.key,
    required this.document,
    required this.onDelete,
    this.onTap,
  });

  @override
  State<DocumentTile> createState() => _DocumentTileState();
}

class _DocumentTileState extends State<DocumentTile> {
  bool _hovered = false;

  static bool get _isDesktop =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '$diff days ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete document?'),
        content: Text('"${widget.document.name}" will be removed from the vault.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB71C1C)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) widget.onDelete();
  }

  void _showContextMenu(Offset globalPosition) {
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    showMenu(
      context: context,
      position: RelativeRect.fromRect(
        globalPosition & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem(
          onTap: _confirmDelete,
          child: const Row(
            children: [
              Icon(Icons.delete_outline_rounded,
                  size: 18, color: Color(0xFFEF9A9A)),
              SizedBox(width: 10),
              Text('Delete', style: TextStyle(color: Color(0xFFEF9A9A))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTile() {
    final type = widget.document.type;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: type.color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(type.icon, color: type.color, size: 24),
      ),
      title: Text(
        widget.document.name,
        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${type.label} • ${_formatDate(widget.document.dateAdded)}',
        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
      ),
      trailing: _isDesktop
          ? AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: _hovered
                  ? IconButton(
                      key: const ValueKey('delete'),
                      icon: const Icon(Icons.delete_outline_rounded,
                          size: 20, color: Color(0xFFEF9A9A)),
                      tooltip: 'Delete',
                      onPressed: _confirmDelete,
                    )
                  : Icon(
                      key: const ValueKey('chevron'),
                      Icons.chevron_right,
                      color: Colors.grey[600],
                      size: 20,
                    ),
            )
          : Icon(Icons.chevron_right, color: Colors.grey[600], size: 20),
      onTap: widget.onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isDesktop) {
      return MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onSecondaryTapUp: (details) =>
              _showContextMenu(details.globalPosition),
          child: _buildTile(),
        ),
      );
    }

    // Mobile: swipe-to-delete
    return Dismissible(
      key: ValueKey(widget.document.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: const Color(0xFFB71C1C),
        child: const Icon(Icons.delete_rounded, color: Colors.white, size: 26),
      ),
      confirmDismiss: (_) async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete document?'),
            content: Text(
                '"${widget.document.name}" will be removed from the vault.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFB71C1C)),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        return confirmed ?? false;
      },
      onDismissed: (_) => widget.onDelete(),
      child: _buildTile(),
    );
  }
}
