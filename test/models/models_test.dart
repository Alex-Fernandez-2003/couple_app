import 'package:flutter_test/flutter_test.dart';
import 'package:couple_app/data/models/note.dart';
import 'package:couple_app/data/models/box_model.dart';

void main() {
  group('Note Model Tests', () {
    test('Note.fromMap creates instance from map', () {
      final map = {
        'id': '123',
        'title': 'Test Note',
        'content': 'Test content',
        'createdAt': '2025-04-21T10:00:00.000Z',
        'updatedAt': '2025-04-21T11:00:00.000Z',
      };

      final note = Note.fromMap(map);

      expect(note.id, equals('123'));
      expect(note.title, equals('Test Note'));
      expect(note.content, equals('Test content'));
      expect(note.createdAt, isA<DateTime>());
      expect(note.updatedAt, isA<DateTime>());
    });

    test('Note.toMap converts instance to map', () {
      final now = DateTime.now();
      final note = Note(
        id: '123',
        title: 'Test Note',
        content: 'Test content',
        createdAt: now,
        updatedAt: now,
      );

      final map = note.toMap();

      expect(map['id'], equals('123'));
      expect(map['title'], equals('Test Note'));
      expect(map['content'], equals('Test content'));
      expect(map['createdAt'], isA<String>());
      expect(map['updatedAt'], isA<String>());
    });

    test('Note.copyWith creates updated copy', () {
      final now = DateTime.now();
      final note = Note(
        id: '123',
        title: 'Original',
        content: 'Original content',
        createdAt: now,
        updatedAt: now,
      );

      final updated = note.copyWith(title: 'Updated');

      expect(updated.id, equals(note.id));
      expect(updated.title, equals('Updated'));
      expect(updated.content, equals(note.content));
      expect(updated.createdAt, equals(note.createdAt));
    });

    test('Note preserves JSON round-trip integrity', () {
      final original = Note(
        id: '123',
        title: 'Test Note',
        content: 'Test content',
        createdAt: DateTime(2025, 4, 21, 10, 0),
        updatedAt: DateTime(2025, 4, 21, 11, 0),
      );

      final map = original.toMap();
      final restored = Note.fromMap(map);

      expect(restored.id, equals(original.id));
      expect(restored.title, equals(original.title));
      expect(restored.content, equals(original.content));
    });
  });

  group('Box Model Tests', () {
    test('Box.fromMap creates instance from map', () {
      final map = {
        'id': '456',
        'title': 'Test Box',
        'description': 'Test description',
        'items': ['item1', 'item2'],
        'createdAt': '2025-04-21T10:00:00.000Z',
        'updatedAt': '2025-04-21T11:00:00.000Z',
      };

      final box = Box.fromMap(map);

      expect(box.id, equals('456'));
      expect(box.title, equals('Test Box'));
      expect(box.description, equals('Test description'));
      expect(box.items.map((item) => item.title), equals(['item1', 'item2']));
      expect(box.items.every((item) => !item.completed), isTrue);
      expect(box.createdAt, isA<DateTime>());
      expect(box.updatedAt, isA<DateTime>());
    });

    test('Box.toMap converts instance to map', () {
      final now = DateTime.now();
      final item1 = MaterialItem.create('item1');
      final item2 = MaterialItem.create('item2');
      final box = Box(
        id: '456',
        title: 'Test Box',
        description: 'Test description',
        items: [item1, item2],
        createdAt: now,
        updatedAt: now,
      );

      final map = box.toMap();

      expect(map['id'], equals('456'));
      expect(map['title'], equals('Test Box'));
      expect(map['description'], equals('Test description'));
      expect(
        (map['items'] as List).map((item) => item['title']),
        equals(['item1', 'item2']),
      );
    });

    test('Box.copyWith creates updated copy', () {
      final now = DateTime.now();
      final item1 = MaterialItem.create('item1');
      final item2 = MaterialItem.create('item2');
      final box = Box(
        id: '456',
        title: 'Original',
        description: 'Original description',
        items: [item1],
        createdAt: now,
        updatedAt: now,
      );

      final updated = box.copyWith(items: [item1, item2]);

      expect(updated.id, equals(box.id));
      expect(updated.title, equals(box.title));
      expect(
        updated.items.map((item) => item.title),
        equals(['item1', 'item2']),
      );
    });

    test('Box handles empty items list', () {
      final box = Box(
        id: '456',
        title: 'Empty Box',
        description: 'Empty',
        items: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(box.items, isEmpty);
      expect(box.items.length, equals(0));
    });

    test('Box preserves JSON round-trip integrity', () {
      final original = Box(
        id: '456',
        title: 'Test Box',
        description: 'Test description',
        items: [MaterialItem.create('item1'), MaterialItem.create('item2')],
        createdAt: DateTime(2025, 4, 21, 10, 0),
        updatedAt: DateTime(2025, 4, 21, 11, 0),
      );

      final map = original.toMap();
      final restored = Box.fromMap(map);

      expect(restored.id, equals(original.id));
      expect(restored.title, equals(original.title));
      expect(
        restored.items.map((item) => item.title),
        equals(original.items.map((item) => item.title)),
      );
    });
  });
}
