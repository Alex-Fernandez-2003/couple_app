import 'package:flutter_test/flutter_test.dart';
import 'package:couple_app/data/models/message.dart';

void main() {
  group('Message Model Tests', () {
    test('Message.fromMap creates instance from Supabase response', () {
      final map = {
        'id': 'msg-123',
        'room_id': 'room-456',
        'sender_id': 'user-789',
        'content': 'Hello my love!',
        'created_at': '2026-04-26T10:30:00.000Z',
        'updated_at': '2026-04-26T10:30:00.000Z',
      };

      final message = Message.fromMap(map);

      expect(message.id, equals('msg-123'));
      expect(message.roomId, equals('room-456'));
      expect(message.senderId, equals('user-789'));
      expect(message.content, equals('Hello my love!'));
      expect(message.createdAt, isA<DateTime>());
      expect(message.updatedAt, isA<DateTime>());
    });

    test('Message.toMap converts instance to map', () {
      final now = DateTime.now();
      final message = Message(
        id: 'msg-123',
        roomId: 'room-456',
        senderId: 'user-789',
        content: 'Hello my love!',
        createdAt: now,
        updatedAt: now,
      );

      final map = message.toMap();

      expect(map['id'], equals('msg-123'));
      expect(map['room_id'], equals('room-456'));
      expect(map['sender_id'], equals('user-789'));
      expect(map['content'], equals('Hello my love!'));
      expect(map['created_at'], isA<String>());
      expect(map['updated_at'], isA<String>());
    });

    test('Message.copyWith creates updated copy with new content', () {
      final now = DateTime.now();
      final message = Message(
        id: 'msg-123',
        roomId: 'room-456',
        senderId: 'user-789',
        content: 'Original',
        createdAt: now,
        updatedAt: now,
      );

      final updated = message.copyWith(content: 'Updated');

      expect(updated.id, equals('msg-123'));
      expect(updated.roomId, equals('room-456'));
      expect(updated.senderId, equals('user-789'));
      expect(updated.content, equals('Updated'));
      expect(updated.createdAt, equals(now));
      expect(updated.updatedAt, equals(now));
    });

    test('Message equality works correctly', () {
      final now = DateTime.now();
      final msg1 = Message(
        id: 'msg-123',
        roomId: 'room-456',
        senderId: 'user-789',
        content: 'Hello',
        createdAt: now,
        updatedAt: now,
      );
      final msg2 = Message(
        id: 'msg-123',
        roomId: 'room-456',
        senderId: 'user-789',
        content: 'Hello',
        createdAt: now,
        updatedAt: now,
      );

      expect(msg1 == msg2, true);
    });

    test('Message with long content under 500 chars', () {
      final now = DateTime.now();
      final longContent = 'a' * 500;
      final message = Message(
        id: 'msg-123',
        roomId: 'room-456',
        senderId: 'user-789',
        content: longContent,
        createdAt: now,
        updatedAt: now,
      );

      expect(message.content.length, equals(500));
      expect(message.content, equals(longContent));
    });

    test('Message round-trip serialization preserves data', () {
      final original = Message(
        id: 'msg-123',
        roomId: 'room-456',
        senderId: 'user-789',
        content: 'Test message content 💕',
        createdAt: DateTime(2026, 4, 26, 10, 30),
        updatedAt: DateTime(2026, 4, 26, 10, 35),
      );

      final map = original.toMap();
      final restored = Message.fromMap(map);

      expect(restored.id, equals(original.id));
      expect(restored.roomId, equals(original.roomId));
      expect(restored.senderId, equals(original.senderId));
      expect(restored.content, equals(original.content));
      // Compare timestamps as strings since DateTime precision may vary
      expect(
        restored.createdAt.toIso8601String(),
        equals(original.createdAt.toIso8601String()),
      );
    });
  });
}
