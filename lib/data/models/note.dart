enum NoteAttachmentType { audio, image, pdf }

enum NoteFileAttachmentType { image, pdf }

class NoteAudioAttachment {
  final String id;
  final String path;
  final Duration duration;
  final DateTime createdAt;
  final String? customName;
  final bool isReviewed;

  const NoteAudioAttachment({
    required this.id,
    required this.path,
    required this.duration,
    required this.createdAt,
    this.customName,
    this.isReviewed = false,
  });

  factory NoteAudioAttachment.fromMap(Map<String, dynamic> map) {
    return NoteAudioAttachment(
      id: map['id'] as String,
      path: map['path'] as String,
      duration: Duration(milliseconds: map['durationMs'] as int? ?? 0),
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
      customName: map['customName'] as String?,
      isReviewed: map['isReviewed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'path': path,
      'durationMs': duration.inMilliseconds,
      'createdAt': createdAt.toIso8601String(),
      'customName': customName,
      'isReviewed': isReviewed,
    };
  }

  NoteAudioAttachment copyWith({
    String? path,
    Duration? duration,
    DateTime? createdAt,
    String? customName,
    bool? isReviewed,
    bool clearCustomName = false,
  }) {
    return NoteAudioAttachment(
      id: id,
      path: path ?? this.path,
      duration: duration ?? this.duration,
      createdAt: createdAt ?? this.createdAt,
      customName: clearCustomName ? null : customName ?? this.customName,
      isReviewed: isReviewed ?? this.isReviewed,
    );
  }
}

class NoteFileAttachment {
  final String id;
  final NoteFileAttachmentType type;
  final String path;
  final String name;
  final int sizeBytes;
  final DateTime createdAt;
  final bool isReviewed;

  const NoteFileAttachment({
    required this.id,
    required this.type,
    required this.path,
    required this.name,
    required this.sizeBytes,
    required this.createdAt,
    this.isReviewed = false,
  });

  factory NoteFileAttachment.fromMap(Map<String, dynamic> map) {
    final rawType = map['type'] as String? ?? 'image';
    return NoteFileAttachment(
      id: map['id'] as String,
      type: NoteFileAttachmentType.values.firstWhere(
        (type) => type.name == rawType,
        orElse: () => NoteFileAttachmentType.image,
      ),
      path: map['path'] as String,
      name: map['name'] as String? ?? 'Adjunto',
      sizeBytes: map['sizeBytes'] as int? ?? 0,
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
      isReviewed: map['isReviewed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'path': path,
      'name': name,
      'sizeBytes': sizeBytes,
      'createdAt': createdAt.toIso8601String(),
      'isReviewed': isReviewed,
    };
  }

  NoteFileAttachment copyWith({
    NoteFileAttachmentType? type,
    String? path,
    String? name,
    int? sizeBytes,
    DateTime? createdAt,
    bool? isReviewed,
  }) {
    return NoteFileAttachment(
      id: id,
      type: type ?? this.type,
      path: path ?? this.path,
      name: name ?? this.name,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      createdAt: createdAt ?? this.createdAt,
      isReviewed: isReviewed ?? this.isReviewed,
    );
  }
}

class NoteAttachment {
  final String id;
  final NoteAttachmentType type;
  final String path;
  final String name;
  final DateTime createdAt;
  final bool isReviewed;

  const NoteAttachment({
    required this.id,
    required this.type,
    required this.path,
    required this.name,
    required this.createdAt,
    this.isReviewed = false,
  });

  factory NoteAttachment.fromMap(Map<String, dynamic> map) {
    final rawType = map['type'] as String? ?? 'image';
    return NoteAttachment(
      id: map['id'] as String,
      type: NoteAttachmentType.values.firstWhere(
        (type) => type.name == rawType,
        orElse: () => NoteAttachmentType.image,
      ),
      path: map['path'] as String,
      name: map['name'] as String? ?? 'Adjunto',
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
      isReviewed: map['isReviewed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'path': path,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'isReviewed': isReviewed,
    };
  }
}

class Note {
  final String id;
  final String title;
  final String content;
  final String? categoryId;
  final List<NoteAudioAttachment> audioAttachments;
  final List<NoteFileAttachment> fileAttachments;
  final List<NoteAttachment> attachments;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isFavorite;

  Note({
    required this.id,
    required this.title,
    required this.content,
    this.categoryId,
    this.audioAttachments = const [],
    this.fileAttachments = const [],
    this.attachments = const [],
    required this.createdAt,
    required this.updatedAt,
    this.isFavorite = false,
  });

  factory Note.fromMap(Map<String, dynamic> map) {
    final attachmentsJson = map['attachments'] as List<dynamic>? ?? const [];
    final attachments = attachmentsJson
        .map(
          (attachment) => NoteAttachment.fromMap(
            Map<String, dynamic>.from(attachment as Map),
          ),
        )
        .toList();
    final audioAttachmentsJson =
        map['audioAttachments'] as List<dynamic>? ?? const [];
    final audioAttachments = [
      ...audioAttachmentsJson.map(
        (attachment) => NoteAudioAttachment.fromMap(
          Map<String, dynamic>.from(attachment as Map),
        ),
      ),
      ...attachments
          .where((attachment) => attachment.type == NoteAttachmentType.audio)
          .map(
            (attachment) => NoteAudioAttachment(
              id: attachment.id,
              path: attachment.path,
              duration: Duration.zero,
              createdAt: attachment.createdAt,
              customName: attachment.name,
              isReviewed: attachment.isReviewed,
            ),
          ),
    ];
    final fileAttachmentsJson =
        map['fileAttachments'] as List<dynamic>? ?? const [];
    final fileAttachments = [
      ...fileAttachmentsJson.map(
        (attachment) => NoteFileAttachment.fromMap(
          Map<String, dynamic>.from(attachment as Map),
        ),
      ),
      ...attachments
          .where(
            (attachment) =>
                attachment.type == NoteAttachmentType.image ||
                attachment.type == NoteAttachmentType.pdf,
          )
          .map(
            (attachment) => NoteFileAttachment(
              id: attachment.id,
              type: attachment.type == NoteAttachmentType.pdf
                  ? NoteFileAttachmentType.pdf
                  : NoteFileAttachmentType.image,
              path: attachment.path,
              name: attachment.name,
              sizeBytes: 0,
              createdAt: attachment.createdAt,
              isReviewed: attachment.isReviewed,
            ),
          ),
    ];
    return Note(
      id: map['id'] as String,
      title: map['title'] as String,
      content: map['content'] as String,
      categoryId: map['categoryId'] as String?,
      audioAttachments: audioAttachments,
      fileAttachments: fileAttachments,
      attachments: const [],
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      isFavorite: map['isFavorite'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'categoryId': categoryId,
      'audioAttachments': audioAttachments
          .map((attachment) => attachment.toMap())
          .toList(growable: false),
      'fileAttachments': fileAttachments
          .map((attachment) => attachment.toMap())
          .toList(growable: false),
      'attachments': attachments
          .map((attachment) => attachment.toMap())
          .toList(growable: false),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isFavorite': isFavorite,
    };
  }

  Note copyWith({
    String? id,
    String? title,
    String? content,
    String? categoryId,
    List<NoteAudioAttachment>? audioAttachments,
    List<NoteFileAttachment>? fileAttachments,
    List<NoteAttachment>? attachments,
    bool clearCategory = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isFavorite,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      categoryId: clearCategory ? null : categoryId ?? this.categoryId,
      audioAttachments: audioAttachments ?? this.audioAttachments,
      fileAttachments: fileAttachments ?? this.fileAttachments,
      attachments: attachments ?? this.attachments,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}

class NoteCategory {
  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;

  const NoteCategory({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
  });

  factory NoteCategory.fromMap(Map<String, dynamic> map) {
    return NoteCategory(
      id: map['id'] as String,
      name: map['name'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  NoteCategory copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NoteCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
