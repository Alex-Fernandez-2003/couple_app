class Room {
  final String id;
  final String inviteCode;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String customMessage;
  final String? user1Id;
  final String? user2Id;
  final String? messageForUser1;
  final String? messageForUser2;
  final DateTime? messageUpdatedAt;
  final DateTime? relationshipStartDate;
  final DateTime? periodStartedAt;

  Room({
    required this.id,
    required this.inviteCode,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.customMessage = 'Tu espacio de pareja',
    this.user1Id,
    this.user2Id,
    this.messageForUser1,
    this.messageForUser2,
    this.messageUpdatedAt,
    this.relationshipStartDate,
    this.periodStartedAt,
  });

  factory Room.fromMap(Map<String, dynamic> map) {
    return Room(
      id: map['id'] as String,
      inviteCode: map['invite_code'] as String,
      name: map['name'] as String? ?? 'Nuestro espacio',
      createdAt: _parseDateTime(map['created_at']),
      updatedAt: _parseDateTime(map['last_activity_at'] ?? map['created_at']),
      customMessage:
          (map['custom_message'] as String?) ?? 'Tu espacio de pareja',
      user1Id: map['user1_id'] as String?,
      user2Id: map['user2_id'] as String?,
      messageForUser1: map['message_for_user1'] as String?,
      messageForUser2: map['message_for_user2'] as String?,
      messageUpdatedAt: _parseNullableDateTime(map['message_updated_at']),
      relationshipStartDate: _parseNullableDateTime(
        map['relationship_start_date'],
      ),
      periodStartedAt: _parseNullableDateTime(map['period_started_at']),
    );
  }

  Room copyWith({
    String? id,
    String? inviteCode,
    String? name,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? customMessage,
    String? user1Id,
    String? user2Id,
    String? messageForUser1,
    String? messageForUser2,
    DateTime? messageUpdatedAt,
    DateTime? relationshipStartDate,
    DateTime? periodStartedAt,
    bool clearRelationshipStartDate = false,
    bool clearPeriodStartedAt = false,
  }) {
    return Room(
      id: id ?? this.id,
      inviteCode: inviteCode ?? this.inviteCode,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      customMessage: customMessage ?? this.customMessage,
      user1Id: user1Id ?? this.user1Id,
      user2Id: user2Id ?? this.user2Id,
      messageForUser1: messageForUser1 ?? this.messageForUser1,
      messageForUser2: messageForUser2 ?? this.messageForUser2,
      messageUpdatedAt: messageUpdatedAt ?? this.messageUpdatedAt,
      relationshipStartDate: clearRelationshipStartDate
          ? null
          : relationshipStartDate ?? this.relationshipStartDate,
      periodStartedAt: clearPeriodStartedAt
          ? null
          : periodStartedAt ?? this.periodStartedAt,
    );
  }
}

DateTime _parseDateTime(dynamic value) {
  if (value is DateTime) return value;
  if (value is String && value.isNotEmpty) return DateTime.parse(value);
  return DateTime.now();
}

DateTime? _parseNullableDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String && value.isNotEmpty) return DateTime.parse(value);
  return null;
}
