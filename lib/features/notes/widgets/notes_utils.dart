part of '../screens/notes_screen.dart';

String _formatDateTime(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final year = date.year.toString();
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$day/$month/$year $hour:$minute';
}

String _formatAudioDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

String _formatAudioTime(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

List<Note> _filterNotes(
  List<Note> notes,
  List<NoteCategory> categories,
  String query,
) {
  if (query.isEmpty) return notes;
  final categoryById = {
    for (final category in categories) category.id: category.name,
  };

  return notes.where((note) {
    final categoryName = note.categoryId == null
        ? 'Sin categoría'
        : categoryById[note.categoryId] ?? 'Sin categoría';
    final searchable = [
      note.title,
      note.content,
      categoryName,
      for (final attachment in note.audioAttachments) ...[
        attachment.customName ?? _basename(attachment.path),
        _basename(attachment.path),
        _formatDateTime(attachment.createdAt),
      ],
      for (final attachment in note.fileAttachments) ...[
        attachment.name,
        _basename(attachment.path),
      ],
    ].join(' ').toLowerCase();
    return searchable.contains(query);
  }).toList();
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

String _backgroundRecordingErrorMessage(PlatformException error) {
  final rawMessage = [
    error.code,
    error.message,
    error.details?.toString(),
  ].whereType<String>().join(' ').toLowerCase();

  if (rawMessage.contains('foreground') ||
      rawMessage.contains('service') ||
      rawMessage.contains('background')) {
    return 'Android no permitió iniciar la grabación en segundo plano. Revisa permisos de micrófono, notificaciones y batería para esta app.';
  }

  if (rawMessage.contains('permission') ||
      rawMessage.contains('record_audio')) {
    return 'No hay permiso suficiente para grabar audio. Revisa el permiso de micrófono de la app.';
  }

  return 'No pude iniciar la grabación en segundo plano en este dispositivo.';
}

Future<void> _requestRecordingNotificationPermission() async {
  if (!Platform.isAndroid) return;
  if (!_recordingNotificationsInitialized) {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _recordingNotifications.initialize(settings);
    _recordingNotificationsInitialized = true;
  }

  await _recordingNotifications
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.requestNotificationsPermission();
}

String _formatSpeed(double speed) {
  return speed == speed.roundToDouble()
      ? speed.toInt().toString()
      : speed.toStringAsFixed(1);
}
