import 'package:uuid/uuid.dart';

class Box {
  final String id;
  final String title;
  final String description;
  final List<MaterialItem> items;
  final DateTime createdAt;
  final DateTime updatedAt;

  Box({
    required this.id,
    required this.title,
    required this.description,
    required this.items,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Box.fromMap(Map<String, dynamic> map) {
    return Box(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String,
      items: _parseMaterialItems(map['items']),
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'items': items.map((item) => item.toMap()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  Box copyWith({
    String? id,
    String? title,
    String? description,
    List<MaterialItem>? items,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Box(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      items: items ?? this.items,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class MaterialItem {
  final String id;
  final String title;
  final bool completed;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MaterialItem({
    required this.id,
    required this.title,
    required this.completed,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MaterialItem.create(String title) {
    final now = DateTime.now();
    return MaterialItem(
      id: const Uuid().v4(),
      title: title,
      completed: false,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory MaterialItem.fromMap(Map<String, dynamic> map) {
    return MaterialItem(
      id: map['id'] as String? ?? const Uuid().v4(),
      title: map['title'] as String,
      completed: map['completed'] as bool? ?? false,
      createdAt: _parseDateTime(map['createdAt']),
      updatedAt: _parseDateTime(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'completed': completed,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  MaterialItem copyWith({
    String? id,
    String? title,
    bool? completed,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MaterialItem(
      id: id ?? this.id,
      title: title ?? this.title,
      completed: completed ?? this.completed,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class BoxTemplate {
  final String id;
  final String title;
  final String description;
  final List<MaterialItem> items;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BoxTemplate({
    required this.id,
    required this.title,
    required this.description,
    required this.items,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BoxTemplate.fromMap(Map<String, dynamic> map) {
    return BoxTemplate(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String,
      items: _parseMaterialItems(map['items']),
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'items': items.map((item) => item.toMap()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  BoxTemplate copyWith({
    String? id,
    String? title,
    String? description,
    List<MaterialItem>? items,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BoxTemplate(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      items: items ?? this.items,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Box toBox(String id) {
    final now = DateTime.now();
    return Box(
      id: id,
      title: title,
      description: description,
      items: items.map((item) => MaterialItem.create(item.title)).toList(),
      createdAt: now,
      updatedAt: now,
    );
  }
}

class MaterialTemplate {
  final String id;
  final String title;
  final List<MaterialItem> items;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MaterialTemplate({
    required this.id,
    required this.title,
    required this.items,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MaterialTemplate.fromMap(Map<String, dynamic> map) {
    return MaterialTemplate(
      id: map['id'] as String,
      title: map['title'] as String,
      items: _parseMaterialItems(map['items']),
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'items': items.map((item) => item.toMap()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  MaterialTemplate copyWith({
    String? id,
    String? title,
    List<MaterialItem>? items,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MaterialTemplate(
      id: id ?? this.id,
      title: title ?? this.title,
      items: items ?? this.items,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  List<MaterialItem> createItems() {
    return items.map((item) => MaterialItem.create(item.title)).toList();
  }
}

List<MaterialItem> _parseMaterialItems(dynamic value) {
  if (value is! List) return [];
  return value.map((item) {
    if (item is String) return MaterialItem.create(item);
    if (item is Map<String, dynamic>) return MaterialItem.fromMap(item);
    if (item is Map) {
      return MaterialItem.fromMap(Map<String, dynamic>.from(item));
    }
    return MaterialItem.create(item.toString());
  }).toList();
}

DateTime _parseDateTime(dynamic value) {
  if (value is DateTime) return value;
  if (value is String && value.isNotEmpty) return DateTime.parse(value);
  return DateTime.now();
}
