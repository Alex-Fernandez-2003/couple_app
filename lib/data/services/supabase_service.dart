import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/supabase_config.dart';
import '../models/room.dart';
import '../models/shared_item.dart';
import '../models/message.dart';

class SupabaseService {
  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static Future<void> initialize() async {
    if (!isConfigured) {
      debugPrint(
        'Supabase URL or anon key no configurado. Usa --dart-define=SUPABASE_URL=... y --dart-define=SUPABASE_ANON_KEY=...',
      );
      return;
    }

    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
    await ensureAnonymousSession();
  }

  static Future<void> ensureAnonymousSession() async {
    if (!isConfigured) return;

    final auth = client.auth;
    if (auth.currentUser != null) return;

    await auth.signInAnonymously();
  }

  static SupabaseClient get client {
    return Supabase.instance.client;
  }

  static Future<Room> createRoom(String inviteCode) async {
    final response = await client
        .from('couple_rooms')
        .insert({
          'invite_code': inviteCode,
          'name': 'Nuestro espacio',
          'created_at': DateTime.now().toIso8601String(),
          'last_activity_at': DateTime.now().toIso8601String(),
        })
        .select()
        .single();

    return Room.fromMap(response);
  }

  static Future<Room> joinRoom(String inviteCode) async {
    final response = await client
        .from('couple_rooms')
        .select()
        .eq('invite_code', inviteCode)
        .single();

    return Room.fromMap(response);
  }

  static Future<Room> getRoom(String roomId) async {
    final response = await client
        .from('couple_rooms')
        .select()
        .eq('id', roomId)
        .single();

    return Room.fromMap(response);
  }

  static Future<Room> assignRoomUser(String roomId, String userId) async {
    final response = await client
        .from('couple_rooms')
        .select()
        .eq('id', roomId)
        .single();

    final room = Room.fromMap(response);
    if (room.user1Id == null || room.user1Id!.isEmpty) {
      final updated = await client
          .from('couple_rooms')
          .update({'user1_id': userId})
          .eq('id', roomId)
          .select()
          .single();
      return Room.fromMap(updated);
    }

    if (room.user1Id != userId &&
        (room.user2Id == null || room.user2Id!.isEmpty)) {
      final updated = await client
          .from('couple_rooms')
          .update({'user2_id': userId})
          .eq('id', roomId)
          .select()
          .single();
      return Room.fromMap(updated);
    }

    return room;
  }

  static Stream<Room> watchRoom(String roomId) {
    return client
        .from('couple_rooms')
        .stream(primaryKey: ['id'])
        .eq('id', roomId)
        .map((rows) => Room.fromMap(rows.first));
  }

  static Future<List<SharedItem>> getRoomItems(
    String roomId, {
    String? type,
  }) async {
    var query = client.from('shared_items').select().eq('room_id', roomId);

    if (type != null) {
      query = query.eq('type', type);
    }

    final response = await query.order('updated_at', ascending: false);

    final rows = List<Map<String, dynamic>>.from(response as List<dynamic>);
    return rows.map((row) => SharedItem.fromMap(row)).toList();
  }

  static Stream<List<SharedItem>> subscribeToRoomItems(
    String roomId, {
    String? type,
  }) {
    final filters = {'room_id': roomId};
    if (type != null) {
      filters['type'] = type;
    }

    final stream = client
        .from('shared_items')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .order('updated_at', ascending: false);

    return stream.map((rows) {
      return rows
          .where((row) => type == null || row['type'] == type)
          .map((row) => SharedItem.fromMap(row))
          .toList();
    });
  }

  static Future<void> addSharedItem(SharedItem item) async {
    await client.from('shared_items').insert(item.toMap());
  }

  static Future<void> updateSharedItem(SharedItem item) async {
    await client.from('shared_items').update(item.toMap()).eq('id', item.id);
  }

  static Future<void> deleteSharedItem(String itemId) async {
    await client.from('shared_items').delete().eq('id', itemId);
  }

  // ==================== Message Methods ====================

  static Stream<Message?> messageStream(
    String roomId, {
    required String excludeUserId,
  }) {
    return client
        .from('couple_rooms')
        .stream(primaryKey: ['id'])
        .eq('id', roomId)
        .map((rows) {
          if (rows.isEmpty) return null;
          return _messageForUser(Room.fromMap(rows.first), excludeUserId);
        });
  }

  static Future<Message?> getLatestMessage(
    String roomId, {
    required String excludeUserId,
  }) async {
    try {
      final response = await client
          .from('couple_rooms')
          .select()
          .eq('id', roomId)
          .single();

      return _messageForUser(Room.fromMap(response), excludeUserId);
    } catch (e) {
      debugPrint('Error fetching latest message: $e');
      return null;
    }
  }

  static Future<Message> sendMessage(
    String roomId,
    String senderId,
    String content,
  ) async {
    final room = await assignRoomUser(roomId, senderId);
    final now = DateTime.now();
    final updates = <String, dynamic>{
      'message_updated_at': now.toIso8601String(),
    };

    if (room.user1Id == senderId) {
      updates['message_for_user2'] = content;
    } else if (room.user2Id == senderId) {
      updates['message_for_user1'] = content;
    } else {
      throw StateError('El usuario actual no pertenece a esta room');
    }

    final response = await client
        .from('couple_rooms')
        .update(updates)
        .eq('id', roomId)
        .select()
        .single();

    final updatedRoom = Room.fromMap(response);
    return Message(
      id: '${updatedRoom.id}-${updatedRoom.messageUpdatedAt?.toIso8601String() ?? now.toIso8601String()}',
      roomId: updatedRoom.id,
      senderId: senderId,
      content: content,
      createdAt: updatedRoom.messageUpdatedAt ?? now,
      updatedAt: updatedRoom.messageUpdatedAt ?? now,
    );
  }

  /// Delete a message (optional, for cleanup)
  static Future<void> deleteMessage(String messageId) async {
    debugPrint('deleteMessage is not used with room-based one-to-one messages');
  }

  static Message? _messageForUser(Room room, String userId) {
    final content = room.user1Id == userId
        ? room.messageForUser1
        : room.user2Id == userId
        ? room.messageForUser2
        : null;

    if (content == null || content.isEmpty) return null;

    final senderId = room.user1Id == userId ? room.user2Id : room.user1Id;
    final updatedAt = room.messageUpdatedAt ?? DateTime.now();

    return Message(
      id: '${room.id}-${updatedAt.toIso8601String()}',
      roomId: room.id,
      senderId: senderId ?? '',
      content: content,
      createdAt: updatedAt,
      updatedAt: updatedAt,
    );
  }

  // ==================== Custom Message Methods ====================

  /// Update the shared custom message in couple_rooms
  static Future<void> updateCustomMessage(
    String roomId,
    String customMessage,
  ) async {
    await client
        .from('couple_rooms')
        .update({
          'custom_message': customMessage,
          'custom_message_updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', roomId);
  }

  static Future<Room> updateRelationshipStartDate(
    String roomId,
    DateTime? date,
  ) async {
    final response = await client
        .from('couple_rooms')
        .update({'relationship_start_date': date?.toIso8601String()})
        .eq('id', roomId)
        .select()
        .single();

    return Room.fromMap(response);
  }

  static Future<Room> updatePeriodStartedAt(
    String roomId,
    DateTime? date,
  ) async {
    final response = await client
        .from('couple_rooms')
        .update({'period_started_at': date?.toIso8601String()})
        .eq('id', roomId)
        .select()
        .single();

    return Room.fromMap(response);
  }

  /// Stream custom message changes from couple_rooms
  static Stream<String> watchRoomCustomMessage(String roomId) {
    return client
        .from('couple_rooms')
        .stream(primaryKey: ['id'])
        .eq('id', roomId)
        .map((rows) {
          if (rows.isEmpty) return 'Tu espacio de pareja';
          return (rows.first['custom_message'] as String?) ??
              'Tu espacio de pareja';
        });
  }

  /// Get current custom message (one-time fetch)
  static Future<String> getCustomMessage(String roomId) async {
    try {
      final response = await client
          .from('couple_rooms')
          .select('custom_message')
          .eq('id', roomId)
          .single();

      return (response['custom_message'] as String?) ?? 'Tu espacio de pareja';
    } catch (e) {
      debugPrint('Error fetching custom message: $e');
      return 'Tu espacio de pareja';
    }
  }
}
