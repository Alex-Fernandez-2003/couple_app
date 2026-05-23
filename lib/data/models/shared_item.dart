class SharedItem {
  final String id;
  final String roomId;
  final String type;
  final String title;
  final String? details;
  final double? price;
  final String? category;
  final bool completed;
  final DateTime updatedAt;

  SharedItem({
    required this.id,
    required this.roomId,
    required this.type,
    required this.title,
    this.details,
    this.price,
    this.category,
    required this.completed,
    required this.updatedAt,
  });

  factory SharedItem.fromMap(Map<String, dynamic> map) {
    final priceValue = map['price'];
    return SharedItem(
      id: map['id'] as String,
      roomId: map['room_id'] as String,
      type: map['type'] as String,
      title: map['title'] as String,
      details: map['details'] as String?,
      price: priceValue is num ? priceValue.toDouble() : null,
      category: map['category'] as String?,
      completed: map['completed'] as bool? ?? false,
      updatedAt: _parseDateTime(map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'room_id': roomId,
      'type': type,
      'title': title,
      'details': details,
      'price': price,
      'category': category,
      'completed': completed,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  SharedItem copyWith({
    String? id,
    String? roomId,
    String? type,
    String? title,
    String? details,
    double? price,
    String? category,
    bool? completed,
    DateTime? updatedAt,
  }) {
    return SharedItem(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      type: type ?? this.type,
      title: title ?? this.title,
      details: details ?? this.details,
      price: price ?? this.price,
      category: category ?? this.category,
      completed: completed ?? this.completed,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

DateTime _parseDateTime(dynamic value) {
  if (value is DateTime) return value;
  if (value is String && value.isNotEmpty) return DateTime.parse(value);
  return DateTime.now();
}
