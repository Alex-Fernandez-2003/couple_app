import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import '../../../data/models/note.dart';
import '../../../data/providers.dart';

class NotesScreen extends ConsumerWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(notesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notas'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_outlined),
            tooltip: 'Gestionar categorías',
            onPressed: () => _showCategoriesDialog(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Nueva nota',
            onPressed: () => _showNoteDialog(context, ref),
          ),
        ],
      ),
      body: notesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          error: error,
          onRetry: () => ref.invalidate(notesProvider),
        ),
        data: (state) {
          if (state.notes.isEmpty) {
            return _EmptyState(
              icon: Icons.note_outlined,
              title: 'Tu diario personal',
              message:
                  'Un espacio para tus pensamientos, recuerdos y materias importantes.',
              actionLabel: 'Escribir primera nota',
              onAction: () => _showNoteDialog(context, ref),
            );
          }

          return _GroupedNotesList(
            notes: state.notes,
            categories: state.categories,
            onEdit: (note) => _showNoteDialog(context, ref, note: note),
            onDelete: (note) => _showDeleteNoteConfirmation(context, ref, note),
            onAttachments: (note) => _showAttachmentsDialog(context, ref, note),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNoteDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nota'),
        backgroundColor: const Color(0xFFFD8392),
        foregroundColor: Colors.white,
      ),
    );
  }
}

void _showNoteDialog(BuildContext context, WidgetRef ref, {Note? note}) {
  final state = ref.read(notesProvider).value ?? const NotesState.empty();
  showDialog(
    context: context,
    builder: (context) => _NoteDialog(
      title: note == null ? 'Nueva nota' : 'Editar nota',
      categories: state.categories,
      initialTitle: note?.title,
      initialContent: note?.content,
      initialCategoryId: note?.categoryId,
      onSave: (values) async {
        final notifier = ref.read(notesProvider.notifier);
        if (note == null) {
          await notifier.addNote(
            values.title,
            values.content,
            categoryId: values.categoryId,
          );
        } else {
          await notifier.updateNote(
            note.copyWith(
              title: values.title,
              content: values.content,
              categoryId: values.categoryId,
              clearCategory: values.categoryId == null,
            ),
          );
        }
      },
    ),
  );
}

void _showCategoriesDialog(BuildContext context, WidgetRef ref) {
  showDialog(
    context: context,
    builder: (context) => _CategoriesDialog(ref: ref),
  );
}

void _showAttachmentsDialog(BuildContext context, WidgetRef ref, Note note) {
  showDialog(
    context: context,
    builder: (context) => _NoteAttachmentsDialog(noteId: note.id),
  );
}

void _showDeleteNoteConfirmation(
  BuildContext context,
  WidgetRef ref,
  Note note,
) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Eliminar nota'),
      content: Text('¿Eliminar "${note.title}"?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () async {
            await ref.read(notesProvider.notifier).deleteNote(note.id);
            if (context.mounted) Navigator.of(context).pop();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text('Eliminar'),
        ),
      ],
    ),
  );
}

class _GroupedNotesList extends StatelessWidget {
  const _GroupedNotesList({
    required this.notes,
    required this.categories,
    required this.onEdit,
    required this.onDelete,
    required this.onAttachments,
  });

  final List<Note> notes;
  final List<NoteCategory> categories;
  final ValueChanged<Note> onEdit;
  final ValueChanged<Note> onDelete;
  final ValueChanged<Note> onAttachments;

  @override
  Widget build(BuildContext context) {
    final categoryById = {
      for (final category in categories) category.id: category,
    };
    final grouped = <String?, List<Note>>{};
    for (final note in notes) {
      grouped.putIfAbsent(note.categoryId, () => []).add(note);
    }

    final categoryIds = [
      ...categories
          .where((category) => grouped.containsKey(category.id))
          .map((category) => category.id),
      if (grouped.containsKey(null)) null,
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: categoryIds.length,
      itemBuilder: (context, index) {
        final categoryId = categoryIds[index];
        final categoryName = categoryId == null
            ? 'Sin categoría'
            : categoryById[categoryId]?.name ?? 'Sin categoría';
        final categoryNotes = grouped[categoryId] ?? const <Note>[];

        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  categoryName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748),
                  ),
                ),
              ),
              for (final note in categoryNotes)
                _NoteCard(
                  note: note,
                  categoryName: categoryName,
                  onEdit: () => onEdit(note),
                  onDelete: () => onDelete(note),
                  onAttachments: () => onAttachments(note),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.note,
    required this.categoryName,
    required this.onEdit,
    required this.onDelete,
    required this.onAttachments,
  });

  final Note note;
  final String categoryName;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAttachments;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(
          note.title,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(note.content, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _SmallLabel(icon: Icons.folder_outlined, text: categoryName),
                _SmallLabel(
                  icon: Icons.schedule,
                  text: 'Creada: ${_formatDate(note.createdAt)}',
                ),
                if (note.audioAttachments.isNotEmpty)
                  _SmallLabel(
                    icon: Icons.mic_none,
                    text: '${note.audioAttachments.length} audios',
                  ),
                if (note.fileAttachments.isNotEmpty)
                  _SmallLabel(
                    icon: Icons.attach_file,
                    text: '${note.fileAttachments.length} archivos',
                  ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') onEdit();
            if (value == 'attachments') onAttachments();
            if (value == 'delete') onDelete();
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'edit', child: Text('Editar')),
            PopupMenuItem(value: 'attachments', child: Text('Adjuntos')),
            PopupMenuItem(value: 'delete', child: Text('Eliminar')),
          ],
        ),
        onTap: onAttachments,
      ),
    );
  }
}

class _NoteAttachmentsDialog extends ConsumerStatefulWidget {
  const _NoteAttachmentsDialog({required this.noteId});

  final String noteId;

  @override
  ConsumerState<_NoteAttachmentsDialog> createState() =>
      _NoteAttachmentsDialogState();
}

class _NoteAttachmentsDialogState
    extends ConsumerState<_NoteAttachmentsDialog> {
  final _recorder = AudioRecorder();
  final _audioPlayer = AudioPlayer();
  final _imagePicker = ImagePicker();
  final Map<String, Duration> _positions = {};
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _durationSubscription;
  StreamSubscription<PlayerState>? _stateSubscription;
  StreamSubscription<void>? _completeSubscription;
  bool _recording = false;
  DateTime? _recordingStartedAt;
  String? _activeAudioId;
  Duration _currentPosition = Duration.zero;
  Duration _currentDuration = Duration.zero;
  PlayerState _playerState = PlayerState.stopped;
  double _speed = 1;

  @override
  void initState() {
    super.initState();
    _positionSubscription = _audioPlayer.onPositionChanged.listen((position) {
      final activeId = _activeAudioId;
      if (activeId == null || !mounted) return;
      setState(() {
        _currentPosition = position;
        _positions[activeId] = position;
      });
    });
    _durationSubscription = _audioPlayer.onDurationChanged.listen((duration) {
      if (!mounted) return;
      setState(() {
        _currentDuration = duration;
      });
    });
    _stateSubscription = _audioPlayer.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() {
        _playerState = state;
      });
    });
    _completeSubscription = _audioPlayer.onPlayerComplete.listen((_) {
      final activeId = _activeAudioId;
      if (!mounted) return;
      setState(() {
        if (activeId != null) _positions[activeId] = Duration.zero;
        _currentPosition = Duration.zero;
        _playerState = PlayerState.completed;
      });
    });
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _stateSubscription?.cancel();
    _completeSubscription?.cancel();
    _recorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    if (_recording) {
      final path = await _recorder.stop();
      final startedAt = _recordingStartedAt;
      setState(() {
        _recording = false;
        _recordingStartedAt = null;
      });
      if (path == null) return;
      final measuredDuration = await _readAudioDuration(path);
      final fallbackDuration = startedAt == null
          ? Duration.zero
          : DateTime.now().difference(startedAt);
      await _addAudioAttachment(
        path: path,
        customName: 'Audio ${_formatDate(DateTime.now())}',
        duration: measuredDuration ?? fallbackDuration,
        alreadySaved: true,
      );
      return;
    }

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      _showSnack('No hay permiso para grabar audio.');
      return;
    }

    final path = await _newLocalAttachmentPath('audio.m4a');
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: path,
    );
    setState(() {
      _recording = true;
      _recordingStartedAt = DateTime.now();
    });
  }

  Future<void> _pickAudio() async {
    final picked = await FilePicker.platform.pickFiles(type: FileType.audio);
    final path = picked?.files.single.path;
    if (path == null) return;
    await _addAudioAttachment(
      path: path,
      customName: _basename(path),
      duration: await _readAudioDuration(path) ?? Duration.zero,
    );
  }

  Future<void> _showFileAttachmentOptions() async {
    final type = await showModalBottomSheet<NoteFileAttachmentType>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('Adjuntar imagen'),
              onTap: () =>
                  Navigator.of(context).pop(NoteFileAttachmentType.image),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('Adjuntar PDF'),
              onTap: () =>
                  Navigator.of(context).pop(NoteFileAttachmentType.pdf),
            ),
          ],
        ),
      ),
    );
    if (type == null) return;
    if (type == NoteFileAttachmentType.image) {
      await _pickImageAttachment();
    } else {
      await _pickPdfAttachment();
    }
  }

  Future<void> _pickImageAttachment() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
      maxWidth: 2400,
    );
    if (picked == null) return;
    await _addFileAttachment(
      sourcePath: picked.path,
      type: NoteFileAttachmentType.image,
    );
  }

  Future<void> _pickPdfAttachment() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    final path = picked?.files.single.path;
    if (path == null) return;
    await _addFileAttachment(
      sourcePath: path,
      type: NoteFileAttachmentType.pdf,
    );
  }

  Future<void> _addFileAttachment({
    required String sourcePath,
    required NoteFileAttachmentType type,
  }) async {
    try {
      final savedPath = await _copyAttachmentToLocalStorage(sourcePath);
      final file = File(savedPath);
      final attachment = NoteFileAttachment(
        id: const Uuid().v4(),
        type: type,
        path: savedPath,
        name: _basename(sourcePath),
        sizeBytes: await file.length(),
        createdAt: DateTime.now(),
      );
      await ref
          .read(notesProvider.notifier)
          .addFileAttachment(widget.noteId, attachment);
    } catch (error) {
      _showSnack('No se pudo guardar el archivo: $error');
    }
  }

  Future<void> _addAudioAttachment({
    required String path,
    required Duration duration,
    String? customName,
    bool alreadySaved = false,
  }) async {
    try {
      final savedPath = alreadySaved
          ? path
          : await _copyAudioToLocalStorage(path);
      final attachment = NoteAudioAttachment(
        id: const Uuid().v4(),
        path: savedPath,
        duration: duration,
        createdAt: DateTime.now(),
        customName: customName,
      );
      await ref
          .read(notesProvider.notifier)
          .addAudioAttachment(widget.noteId, attachment);
    } catch (error) {
      _showSnack('No se pudo guardar el audio: $error');
    }
  }

  Future<void> _deleteAudioAttachment(NoteAudioAttachment attachment) async {
    if (_activeAudioId == attachment.id) {
      await _audioPlayer.stop();
      setState(() {
        _activeAudioId = null;
        _currentPosition = Duration.zero;
        _currentDuration = Duration.zero;
      });
    }
    _positions.remove(attachment.id);
    await ref
        .read(notesProvider.notifier)
        .deleteAudioAttachment(widget.noteId, attachment.id);
  }

  Future<void> _shareAudioAttachment(NoteAudioAttachment attachment) async {
    final name = attachment.customName ?? _basename(attachment.path);
    await _shareLocalFile(
      path: attachment.path,
      name: name,
      mimeType: _mimeTypeForPath(attachment.path, fallback: 'audio/*'),
    );
  }

  Future<void> _renameAudioAttachment(NoteAudioAttachment attachment) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _AttachmentRenameDialog(
        title: const Text('Renombrar audio'),
        initialName: attachment.customName ?? _basename(attachment.path),
        hintText: 'Repaso periodoncia...',
      ),
    );
    if (name == null) return;
    if (!mounted) return;
    await ref
        .read(notesProvider.notifier)
        .renameAudioAttachment(
          widget.noteId,
          attachment.id,
          name.isEmpty ? null : name,
        );
  }

  Future<void> _openFileAttachment(NoteFileAttachment attachment) async {
    final result = await OpenFilex.open(attachment.path);
    if (result.type != ResultType.done) {
      _showSnack('No se pudo abrir el archivo.');
    }
  }

  Future<void> _renameFileAttachment(NoteFileAttachment attachment) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _AttachmentRenameDialog(
        title: const Text('Renombrar archivo'),
        initialName: attachment.name,
        hintText: 'Radiología clase 3.pdf',
      ),
    );
    if (name == null || name.isEmpty) return;
    if (!mounted) return;
    await ref
        .read(notesProvider.notifier)
        .renameFileAttachment(widget.noteId, attachment.id, name);
  }

  Future<void> _deleteFileAttachment(NoteFileAttachment attachment) async {
    await ref
        .read(notesProvider.notifier)
        .deleteFileAttachment(widget.noteId, attachment.id);
  }

  Future<void> _shareFileAttachment(NoteFileAttachment attachment) async {
    await _shareLocalFile(
      path: attachment.path,
      name: attachment.name,
      mimeType: _mimeTypeForFileAttachment(attachment),
    );
  }

  Future<void> _shareLocalFile({
    required String path,
    required String name,
    String? mimeType,
  }) async {
    final file = File(path);
    if (!await file.exists()) {
      _showSnack('No se encontró el archivo para compartir.');
      return;
    }

    try {
      await SharePlus.instance.share(
        ShareParams(
          title: name,
          files: [XFile(path, name: name, mimeType: mimeType)],
          fileNameOverrides: [name],
        ),
      );
    } catch (error) {
      _showSnack('No se pudo compartir el archivo: $error');
    }
  }

  Future<Duration?> _readAudioDuration(String path) async {
    final player = AudioPlayer();
    try {
      await player.setSourceDeviceFile(path);
      return await player.getDuration();
    } catch (_) {
      return null;
    } finally {
      await player.dispose();
    }
  }

  Future<void> _togglePlayback(NoteAudioAttachment attachment) async {
    final isActive = _activeAudioId == attachment.id;
    final isPlaying = isActive && _playerState == PlayerState.playing;

    if (isPlaying) {
      await _audioPlayer.pause();
      return;
    }

    if (isActive && _playerState == PlayerState.paused) {
      await _audioPlayer.resume();
      await _audioPlayer.setPlaybackRate(_speed);
      return;
    }

    await _audioPlayer.stop();
    final savedPosition = _positions[attachment.id] ?? Duration.zero;
    setState(() {
      _activeAudioId = attachment.id;
      _currentPosition = savedPosition;
      _currentDuration = attachment.duration;
    });
    await _audioPlayer.play(DeviceFileSource(attachment.path));
    await _audioPlayer.setPlaybackRate(_speed);
    if (savedPosition > Duration.zero &&
        savedPosition < _effectiveDuration(attachment)) {
      await _audioPlayer.seek(savedPosition);
    }
  }

  Future<void> _seekActive(Duration position) async {
    final activeId = _activeAudioId;
    if (activeId == null) return;
    await _audioPlayer.seek(position);
    setState(() {
      _currentPosition = position;
      _positions[activeId] = position;
    });
  }

  Future<void> _setSpeed(double speed) async {
    setState(() {
      _speed = speed;
    });
    await _audioPlayer.setPlaybackRate(speed);
  }

  Future<void> _openExternally(NoteAudioAttachment attachment) async {
    final result = await OpenFilex.open(attachment.path);
    if (result.type != ResultType.done) {
      _showSnack('No se pudo abrir el audio.');
    }
  }

  Duration _effectiveDuration(NoteAudioAttachment attachment) {
    if (_activeAudioId == attachment.id && _currentDuration > Duration.zero) {
      return _currentDuration;
    }
    return attachment.duration;
  }

  Future<String> _copyAudioToLocalStorage(String sourcePath) async {
    return _copyAttachmentToLocalStorage(sourcePath);
  }

  Future<String> _copyAttachmentToLocalStorage(String sourcePath) async {
    final targetPath = await _newLocalAttachmentPath(_basename(sourcePath));
    await File(sourcePath).copy(targetPath);
    return targetPath;
  }

  Future<String> _newLocalAttachmentPath(String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    final attachmentsDirectory = Directory(
      '${directory.path}/note_attachments',
    );
    if (!await attachmentsDirectory.exists()) {
      await attachmentsDirectory.create(recursive: true);
    }
    final extension = _extension(fileName);
    final suffix = extension.isEmpty ? '' : '.$extension';
    return '${attachmentsDirectory.path}/${DateTime.now().millisecondsSinceEpoch}$suffix';
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final notesState = ref.watch(notesProvider).value;
    final note = notesState?.notes
        .where((note) => note.id == widget.noteId)
        .cast<Note?>()
        .firstWhere((note) => note != null, orElse: () => null);
    final audioAttachments =
        note?.audioAttachments ?? const <NoteAudioAttachment>[];
    final fileAttachments =
        note?.fileAttachments ?? const <NoteFileAttachment>[];
    final hasAttachments =
        audioAttachments.isNotEmpty || fileAttachments.isNotEmpty;

    return AlertDialog(
      title: const Text('Adjuntos'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _toggleRecording,
                  icon: Icon(_recording ? Icons.stop : Icons.mic),
                  label: Text(_recording ? 'Detener' : 'Grabar audio'),
                ),
                OutlinedButton.icon(
                  onPressed: _pickAudio,
                  icon: const Icon(Icons.attach_file),
                  label: const Text('Adjuntar audio'),
                ),
                OutlinedButton.icon(
                  onPressed: _showFileAttachmentOptions,
                  icon: const Icon(Icons.note_add_outlined),
                  label: const Text('Adjuntar archivo'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (!hasAttachments)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Aún no hay adjuntos en esta nota.',
                  textAlign: TextAlign.center,
                ),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    if (audioAttachments.isNotEmpty) ...[
                      const _AttachmentSectionTitle('Audios'),
                      for (final attachment in audioAttachments)
                        Builder(
                          builder: (context) {
                            final isActive = _activeAudioId == attachment.id;
                            final isPlaying =
                                isActive && _playerState == PlayerState.playing;
                            final duration = _effectiveDuration(attachment);
                            final position = isActive
                                ? _currentPosition
                                : _positions[attachment.id] ?? Duration.zero;

                            return _AudioAttachmentTile(
                              attachment: attachment,
                              isActive: isActive,
                              isPlaying: isPlaying,
                              position: position,
                              duration: duration,
                              speed: _speed,
                              onPlayPause: () => _togglePlayback(attachment),
                              onSeek: isActive ? _seekActive : null,
                              onSpeedChanged: _setSpeed,
                              onOpenExternal: () => _openExternally(attachment),
                              onShare: () => _shareAudioAttachment(attachment),
                              onRename: () =>
                                  _renameAudioAttachment(attachment),
                              onDelete: () =>
                                  _deleteAudioAttachment(attachment),
                            );
                          },
                        ),
                    ],
                    if (fileAttachments.isNotEmpty) ...[
                      const _AttachmentSectionTitle('Archivos'),
                      for (final attachment in fileAttachments)
                        _FileAttachmentTile(
                          attachment: attachment,
                          onOpen: () => _openFileAttachment(attachment),
                          onShare: () => _shareFileAttachment(attachment),
                          onRename: () => _renameFileAttachment(attachment),
                          onDelete: () => _deleteFileAttachment(attachment),
                        ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}

class _AttachmentSectionTitle extends StatelessWidget {
  const _AttachmentSectionTitle(this.text);

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
  });

  final NoteFileAttachment attachment;
  final VoidCallback onOpen;
  final VoidCallback onShare;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: _FileAttachmentPreview(attachment: attachment),
        title: Text(
          attachment.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${_formatFileSize(attachment.sizeBytes)} · ${_formatDate(attachment.createdAt)}',
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

class _AudioAttachmentTile extends StatelessWidget {
  const _AudioAttachmentTile({
    required this.attachment,
    required this.isActive,
    required this.isPlaying,
    required this.position,
    required this.duration,
    required this.speed,
    required this.onPlayPause,
    required this.onSpeedChanged,
    required this.onOpenExternal,
    required this.onShare,
    required this.onRename,
    required this.onDelete,
    this.onSeek,
  });

  final NoteAudioAttachment attachment;
  final bool isActive;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final double speed;
  final VoidCallback onPlayPause;
  final ValueChanged<Duration>? onSeek;
  final ValueChanged<double> onSpeedChanged;
  final VoidCallback onOpenExternal;
  final VoidCallback onShare;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final maxSeconds = duration.inSeconds <= 0
        ? 1.0
        : duration.inSeconds.toDouble();
    final currentSeconds = position.inSeconds
        .clamp(0, maxSeconds.toInt())
        .toDouble();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton.filledTonal(
                  onPressed: onPlayPause,
                  icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                  tooltip: isPlaying ? 'Pausar' : 'Reproducir',
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        attachment.customName ?? _basename(attachment.path),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_formatDuration(duration)} · ${_formatDate(attachment.createdAt)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.ios_share_outlined),
                  tooltip: 'Compartir',
                  onPressed: onShare,
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'open') onOpenExternal();
                    if (value == 'share') onShare();
                    if (value == 'rename') onRename();
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'open', child: Text('Abrir externo')),
                    PopupMenuItem(value: 'share', child: Text('Compartir')),
                    PopupMenuItem(value: 'rename', child: Text('Renombrar')),
                    PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: const Color(0xFFFD8392),
                thumbColor: const Color(0xFFFD8392),
                inactiveTrackColor: const Color(
                  0xFFFD8392,
                ).withValues(alpha: 0.18),
              ),
              child: Slider(
                value: currentSeconds,
                min: 0,
                max: maxSeconds,
                onChanged: onSeek == null
                    ? null
                    : (value) => onSeek!(Duration(seconds: value.round())),
              ),
            ),
            Row(
              children: [
                Text(
                  _formatDuration(position),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const Spacer(),
                Text(
                  _formatDuration(duration),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final value in const [0.5, 1.0, 1.5, 2.0])
                  ChoiceChip(
                    label: Text('${_formatSpeed(value)}x'),
                    selected: isActive && speed == value,
                    onSelected: (_) => onSpeedChanged(value),
                    selectedColor: const Color(
                      0xFFFD8392,
                    ).withValues(alpha: 0.18),
                    checkmarkColor: const Color(0xFFFD8392),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallLabel extends StatelessWidget {
  const _SmallLabel({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.grey),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}

class _NoteDialog extends StatefulWidget {
  const _NoteDialog({
    required this.title,
    required this.categories,
    required this.onSave,
    this.initialTitle,
    this.initialContent,
    this.initialCategoryId,
  });

  final String title;
  final List<NoteCategory> categories;
  final String? initialTitle;
  final String? initialContent;
  final String? initialCategoryId;
  final Future<void> Function(_NoteValues values) onSave;

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  String? _categoryId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _contentController = TextEditingController(text: widget.initialContent);
    _categoryId = widget.initialCategoryId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (title.isEmpty) return;

    setState(() {
      _saving = true;
    });

    try {
      await widget.onSave(
        _NoteValues(title: title, content: content, categoryId: _categoryId),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $error')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Título',
                hintText: 'Título de la nota',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _contentController,
              decoration: const InputDecoration(
                labelText: 'Contenido opcional',
                hintText: 'Escribe tu nota aquí...',
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              initialValue: _categoryId,
              decoration: const InputDecoration(labelText: 'Categoría'),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Sin categoría'),
                ),
                for (final category in widget.categories)
                  DropdownMenuItem<String?>(
                    value: category.id,
                    child: Text(category.name),
                  ),
              ],
              onChanged: (value) {
                setState(() {
                  _categoryId = value;
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}

class _CategoriesDialog extends ConsumerWidget {
  const _CategoriesDialog({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef widgetRef) {
    final state = ref.watch(notesProvider).value ?? const NotesState.empty();

    return AlertDialog(
      title: const Text('Categorías'),
      content: SizedBox(
        width: double.maxFinite,
        child: state.categories.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Aún no tienes categorías. Crea una para ordenar tus notas.',
                  textAlign: TextAlign.center,
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                itemCount: state.categories.length,
                itemBuilder: (context, index) {
                  final category = state.categories[index];
                  final count = state.notes
                      .where((note) => note.categoryId == category.id)
                      .length;
                  return ListTile(
                    title: Text(category.name),
                    subtitle: Text('$count notas'),
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Editar categoría',
                          onPressed: () =>
                              _showCategoryNameDialog(context, ref, category),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Eliminar categoría',
                          onPressed: () => _showDeleteCategoryDialog(
                            context,
                            ref,
                            category,
                            count,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () => _showCategoryNameDialog(context, ref),
          icon: const Icon(Icons.add),
          label: const Text('Crear'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}

void _showCategoryNameDialog(
  BuildContext context,
  WidgetRef ref, [
  NoteCategory? category,
]) {
  showDialog(
    context: context,
    builder: (context) => _CategoryNameDialog(
      initialName: category?.name,
      title: category == null ? 'Nueva categoría' : 'Editar categoría',
      onSave: (name) async {
        final notifier = ref.read(notesProvider.notifier);
        if (category == null) {
          await notifier.addCategory(name);
        } else {
          await notifier.updateCategory(category.copyWith(name: name));
        }
      },
    ),
  );
}

void _showDeleteCategoryDialog(
  BuildContext context,
  WidgetRef ref,
  NoteCategory category,
  int noteCount,
) {
  DeleteCategoryMode mode = DeleteCategoryMode.moveToUncategorized;
  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text('Eliminar ${category.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Esta categoría tiene $noteCount notas.'),
            const SizedBox(height: 12),
            _DeleteModeTile(
              selected: mode == DeleteCategoryMode.moveToUncategorized,
              title: const Text('Mover notas a Sin categoría'),
              onTap: () =>
                  setState(() => mode = DeleteCategoryMode.moveToUncategorized),
            ),
            _DeleteModeTile(
              selected: mode == DeleteCategoryMode.deleteNotes,
              title: const Text('Eliminar notas asociadas'),
              onTap: () =>
                  setState(() => mode = DeleteCategoryMode.deleteNotes),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              await ref
                  .read(notesProvider.notifier)
                  .deleteCategory(category.id, mode: mode);
              if (context.mounted) Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    ),
  );
}

class _DeleteModeTile extends StatelessWidget {
  const _DeleteModeTile({
    required this.selected,
    required this.title,
    required this.onTap,
  });

  final bool selected;
  final Widget title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        selected ? Icons.check_circle : Icons.radio_button_unchecked,
        color: selected ? const Color(0xFFFD8392) : Colors.grey,
      ),
      title: title,
      onTap: onTap,
    );
  }
}

class _CategoryNameDialog extends StatefulWidget {
  const _CategoryNameDialog({
    required this.title,
    required this.onSave,
    this.initialName,
  });

  final String title;
  final String? initialName;
  final Future<void> Function(String name) onSave;

  @override
  State<_CategoryNameDialog> createState() => _CategoryNameDialogState();
}

class _CategoryNameDialogState extends State<_CategoryNameDialog> {
  late final TextEditingController _nameController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() {
      _saving = true;
    });

    try {
      await widget.onSave(name);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $error')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _nameController,
        decoration: const InputDecoration(
          labelText: 'Nombre',
          hintText: 'Materia, viaje, ideas...',
        ),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

class _NoteValues {
  final String title;
  final String content;
  final String? categoryId;

  const _NoteValues({
    required this.title,
    required this.content,
    this.categoryId,
  });
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFFD8392).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(icon, size: 64, color: const Color(0xFFFD8392)),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF718096),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add),
              label: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: $error', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) {
  final now = DateTime.now();
  final difference = now.difference(date);

  if (difference.inDays == 0) {
    return 'hoy';
  } else if (difference.inDays == 1) {
    return 'ayer';
  } else if (difference.inDays < 7) {
    return 'hace ${difference.inDays} días';
  } else {
    return '${date.day}/${date.month}/${date.year}';
  }
}

String _basename(String path) {
  return path.split(RegExp(r'[/\\]')).last;
}

String _extension(String path) {
  final name = _basename(path);
  final index = name.lastIndexOf('.');
  if (index == -1 || index == name.length - 1) return '';
  return name.substring(index + 1).toLowerCase();
}

String? _mimeTypeForFileAttachment(NoteFileAttachment attachment) {
  return switch (attachment.type) {
    NoteFileAttachmentType.image => _mimeTypeForPath(
      attachment.path,
      fallback: 'image/*',
    ),
    NoteFileAttachmentType.pdf => 'application/pdf',
  };
}

String? _mimeTypeForPath(String path, {String? fallback}) {
  return switch (_extension(path)) {
    'aac' => 'audio/aac',
    'm4a' => 'audio/mp4',
    'mp3' => 'audio/mpeg',
    'ogg' => 'audio/ogg',
    'wav' => 'audio/wav',
    'webm' => 'audio/webm',
    'heic' => 'image/heic',
    'jpeg' || 'jpg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    'pdf' => 'application/pdf',
    _ => fallback,
  };
}

String _formatDuration(Duration duration) {
  final totalSeconds = duration.inSeconds;
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

String _formatFileSize(int bytes) {
  if (bytes <= 0) return 'Tamaño desconocido';
  const kb = 1024;
  const mb = kb * 1024;
  if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(1)} MB';
  if (bytes >= kb) return '${(bytes / kb).toStringAsFixed(1)} KB';
  return '$bytes B';
}

String _formatSpeed(double speed) {
  return speed == speed.roundToDouble()
      ? speed.toInt().toString()
      : speed.toStringAsFixed(1);
}
