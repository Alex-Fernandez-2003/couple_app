part of '../screens/notes_screen.dart';

class _AttachmentSectionTitle extends StatelessWidget {
  const _AttachmentSectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Color(0xFF2D3748),
        ),
      ),
    );
  }
}

class _FileAttachmentTile extends StatelessWidget {
  const _FileAttachmentTile({
    required this.attachment,
    required this.onOpen,
    required this.onShare,
    required this.onRename,
    required this.onDelete,
    required this.onToggleReviewed,
  });

  final NoteFileAttachment attachment;
  final VoidCallback onOpen;
  final VoidCallback onShare;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onToggleReviewed;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(
              value: attachment.isReviewed,
              onChanged: (_) => onToggleReviewed(),
              activeColor: const Color(0xFFFD8392),
            ),
            _FileAttachmentPreview(attachment: attachment),
          ],
        ),
        title: Text(
          attachment.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${_formatFileSize(attachment.sizeBytes)} · ${_formatDateTime(attachment.createdAt)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: onOpen,
        trailing: Wrap(
          spacing: 2,
          children: [
            IconButton(
              icon: const Icon(Icons.ios_share_outlined),
              tooltip: 'Compartir',
              onPressed: onShare,
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'open') onOpen();
                if (value == 'share') onShare();
                if (value == 'rename') onRename();
                if (value == 'delete') onDelete();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'open', child: Text('Abrir')),
                PopupMenuItem(value: 'share', child: Text('Compartir')),
                PopupMenuItem(value: 'rename', child: Text('Renombrar')),
                PopupMenuItem(value: 'delete', child: Text('Eliminar')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FileAttachmentPreview extends StatelessWidget {
  const _FileAttachmentPreview({required this.attachment});

  final NoteFileAttachment attachment;

  @override
  Widget build(BuildContext context) {
    if (attachment.type == NoteFileAttachmentType.image) {
      final file = File(attachment.path);
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            file,
            width: 52,
            height: 52,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                _buildIcon(Icons.broken_image_outlined),
          ),
        );
      }
      return _buildIcon(Icons.broken_image_outlined);
    }

    return _buildIcon(Icons.picture_as_pdf_outlined, color: Colors.redAccent);
  }

  Widget _buildIcon(IconData icon, {Color? color}) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFFFD8392).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color ?? const Color(0xFFFD8392)),
    );
  }
}

class _AttachmentRenameDialog extends StatefulWidget {
  const _AttachmentRenameDialog({
    required this.title,
    required this.initialName,
    required this.hintText,
  });

  final Widget title;
  final String initialName;
  final String hintText;

  @override
  State<_AttachmentRenameDialog> createState() =>
      _AttachmentRenameDialogState();
}

class _AttachmentRenameDialogState extends State<_AttachmentRenameDialog> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _close([String? value]) {
    _focusNode.unfocus();
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: widget.title,
      content: TextField(
        controller: _controller,
        focusNode: _focusNode,
        decoration: InputDecoration(
          labelText: 'Nombre',
          hintText: widget.hintText,
        ),
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _close(_controller.text.trim()),
      ),
      actions: [
        TextButton(onPressed: _close, child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: () => _close(_controller.text.trim()),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
