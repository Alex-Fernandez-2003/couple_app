part of '../screens/notes_screen.dart';

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
    await _requestRecordingNotificationPermission();

    final path = await _newLocalAttachmentPath('audio.m4a');
    try {
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          androidConfig: AndroidRecordConfig(
            audioSource: AndroidAudioSource.mic,
            service: AndroidService(
              title: 'Grabando clase',
              content: 'La grabación sigue activa aunque bloquees el teléfono.',
            ),
          ),
        ),
        path: path,
      );
      if (!mounted) return;
      setState(() {
        _recording = true;
        _recordingStartedAt = DateTime.now();
      });
    } on PlatformException catch (error) {
      _showSnack(_backgroundRecordingErrorMessage(error));
    } catch (_) {
      _showSnack(
        'No pude iniciar la grabación en segundo plano en este dispositivo.',
      );
    }
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

  Future<void> _toggleAudioReviewed(NoteAudioAttachment attachment) async {
    await ref
        .read(notesProvider.notifier)
        .toggleAudioAttachmentReviewed(widget.noteId, attachment.id);
  }

  Future<void> _reorderAudioAttachments(int oldIndex, int newIndex) async {
    await ref
        .read(notesProvider.notifier)
        .reorderAudioAttachments(widget.noteId, oldIndex, newIndex);
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

  Future<void> _toggleFileReviewed(NoteFileAttachment attachment) async {
    await ref
        .read(notesProvider.notifier)
        .toggleFileAttachmentReviewed(widget.noteId, attachment.id);
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

    final screenSize = MediaQuery.sizeOf(context);
    return AlertDialog(
      title: const Text('Adjuntos'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 560,
          maxHeight: screenSize.height * 0.72,
        ),
        child: SizedBox(
          width: screenSize.width,
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
                Expanded(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      if (audioAttachments.isNotEmpty) ...[
                        const _AttachmentSectionTitle('Audios'),
                        ReorderableListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          onReorderItem: _reorderAudioAttachments,
                          buildDefaultDragHandles: false,
                          itemCount: audioAttachments.length,
                          itemBuilder: (context, index) {
                            final attachment = audioAttachments[index];
                            final isActive = _activeAudioId == attachment.id;
                            final isPlaying =
                                isActive && _playerState == PlayerState.playing;
                            final duration = _effectiveDuration(attachment);
                            final position = isActive
                                ? _currentPosition
                                : _positions[attachment.id] ?? Duration.zero;

                            return _AudioAttachmentTile(
                              key: ValueKey(attachment.id),
                              index: index,
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
                              onToggleReviewed: () =>
                                  _toggleAudioReviewed(attachment),
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
                            onToggleReviewed: () =>
                                _toggleFileReviewed(attachment),
                          ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
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
