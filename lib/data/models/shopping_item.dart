class ShoppingItem {
  final String id;
  final String title;
  final String? notes;
  final double? price;
  final String? category;
  final String? categoryId;
  final bool completed;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ShoppingItem({
    required this.id,
    required this.title,
    this.notes,
    this.price,
    this.category,
    this.categoryId,
    required this.completed,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ShoppingItem.fromMap(Map<String, dynamic> map) {
    final priceValue = map['price'];
    return ShoppingItem(
      id: map['id'] as String,
      title: map['title'] as String,
      notes: map['notes'] as String?,
      price: priceValue is num ? priceValue.toDouble() : null,
      category: map['category'] as String?,
      categoryId: map['categoryId'] as String?,
      completed: map['completed'] as bool? ?? false,
      createdAt: _parseDateTime(map['createdAt']),
      updatedAt: _parseDateTime(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'notes': notes,
      'price': price,
      'category': category,
      'categoryId': categoryId,
      'completed': completed,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  ShoppingItem copyWith({
    String? id,
    String? title,
    String? notes,
    double? price,
    String? category,
    String? categoryId,
    bool clearCategory = false,
    bool? completed,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ShoppingItem(
      id: id ?? this.id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      price: price ?? this.price,
      category: clearCategory ? null : category ?? this.category,
      categoryId: clearCategory ? null : categoryId ?? this.categoryId,
      completed: completed ?? this.completed,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class ShoppingTemplate {
  final String id;
  final String title;
  final String? notes;
  final double? price;
  final String? category;
  final String? categoryId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ShoppingTemplate({
    required this.id,
    required this.title,
    this.notes,
    this.price,
    this.category,
    this.categoryId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ShoppingTemplate.fromMap(Map<String, dynamic> map) {
    final priceValue = map['price'];
    return ShoppingTemplate(
      id: map['id'] as String,
      title: map['title'] as String,
      notes: map['notes'] as String?,
      price: priceValue is num ? priceValue.toDouble() : null,
      category: map['category'] as String?,
      categoryId: map['categoryId'] as String?,
      createdAt: _parseDateTime(map['createdAt']),
      updatedAt: _parseDateTime(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'notes': notes,
      'price': price,
      'category': category,
      'categoryId': categoryId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  ShoppingTemplate copyWith({
    String? id,
    String? title,
    String? notes,
    double? price,
    String? category,
    String? categoryId,
    bool clearCategory = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ShoppingTemplate(
      id: id ?? this.id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      price: price ?? this.price,
      category: clearCategory ? null : category ?? this.category,
      categoryId: clearCategory ? null : categoryId ?? this.categoryId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  ShoppingItem toItem(String id) {
    final now = DateTime.now();
    return ShoppingItem(
      id: id,
      title: title,
      notes: notes,
      price: price,
      category: category,
      categoryId: categoryId,
      completed: false,
      createdAt: now,
      updatedAt: now,
    );
  }
}

class ShoppingCategory {
  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ShoppingCategory({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ShoppingCategory.fromMap(Map<String, dynamic> map) {
    return ShoppingCategory(
      id: map['id'] as String,
      name: map['name'] as String,
      createdAt: _parseDateTime(map['createdAt']),
      updatedAt: _parseDateTime(map['updatedAt']),
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

  ShoppingCategory copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ShoppingCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

DateTime _parseDateTime(dynamic value) {
  if (value is DateTime) return value;
  if (value is String && value.isNotEmpty) return DateTime.parse(value);
  return DateTime.now();
}
