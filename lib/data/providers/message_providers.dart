import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:uuid/uuid.dart';

import '../models/message.dart';
import '../services/local_storage_service.dart';
import '../services/supabase_service.dart';

// ==================== Message Provider ====================

class MessageNotifier extends StateNotifier<AsyncValue<Message?>> {
  MessageNotifier({
    required this.ref,
    required this.roomId,
    required this.currentUserId,
  }) : super(const AsyncValue.data(null)) {
    _init();
  }

  final Ref ref;
  final String roomId;
  final String currentUserId;
  StreamSubscription<Message?>? _subscription;

  void _init() async {
    try {
      // Get latest message (one-time)
      final latestMsg = await SupabaseService.getLatestMessage(
        roomId,
        excludeUserId: currentUserId,
      );
      state = AsyncValue.data(latestMsg);

      // Subscribe to stream for real-time updates
      _subscription =
          SupabaseService.messageStream(
            roomId,
            excludeUserId: currentUserId,
          ).listen(
            (msg) {
              state = AsyncValue.data(msg);
            },
            onError: (error, stackTrace) {
              debugPrint('Message stream error: $error');
              state = AsyncValue.error(error, stackTrace);
            },
          );
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> sendMessage(String content) async {
    if (content.isEmpty) return;

    try {
      // Try to send to Supabase
      await SupabaseService.sendMessage(roomId, currentUserId, content);
      // Clear any pending message (on success)
      await LocalStorageService.clearPendingMessages();
    } catch (error) {
      debugPrint('Error sending message: $error');
      // Queue locally for retry
      final messageId = const Uuid().v4();
      await LocalStorageService.addPendingMessage({
        'id': messageId,
        'content': content,
        'timestamp': DateTime.now().toIso8601String(),
        'room_id': roomId,
      });
      // Re-throw for UI to handle
      rethrow;
    }
  }

  Future<void> refreshLatest() async {
    final latestMsg = await SupabaseService.getLatestMessage(
      roomId,
      excludeUserId: currentUserId,
    );
    state = AsyncValue.data(latestMsg);
  }

  Future<void> syncPendingMessages() async {
    final queue = await LocalStorageService.getPendingMessages();
    for (final msg in queue) {
      try {
        await SupabaseService.sendMessage(
          msg['room_id'] as String,
          currentUserId,
          msg['content'] as String,
        );
        await LocalStorageService.removePendingMessage(msg['id'] as String);
      } catch (error) {
        debugPrint('Error syncing pending message: $error');
        // Skip and continue with next
      }
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

// Incoming message provider (filters out self-messages)
final incomingMessageProvider = Provider<Message?>((ref) {
  // This would be populated by messageNotifier
  // For now, return null as placeholder
  return null;
});

// Message queue provider (offline queue)
class MessageQueueNotifier extends StateNotifier<List<Map<String, dynamic>>> {
  MessageQueueNotifier() : super([]) {
    _loadQueue();
  }

  Future<void> _loadQueue() async {
    final queue = await LocalStorageService.getPendingMessages();
    state = queue;
  }

  Future<void> addToQueue(String content, String roomId) async {
    final messageId = const Uuid().v4();
    final msg = {
      'id': messageId,
      'content': content,
      'timestamp': DateTime.now().toIso8601String(),
      'room_id': roomId,
    };
    state = [...state, msg];
    await LocalStorageService.addPendingMessage(msg);
  }

  Future<void> removeFromQueue(String messageId) async {
    state = state.where((msg) => msg['id'] != messageId).toList();
    await LocalStorageService.removePendingMessage(messageId);
  }

  Future<void> clearQueue() async {
    state = [];
    await LocalStorageService.clearPendingMessages();
  }
}

final messageQueueProvider =
    StateNotifierProvider<MessageQueueNotifier, List<Map<String, dynamic>>>(
      (ref) => MessageQueueNotifier(),
    );

// Message notifier provider (room-dependent, user-dependent)
final messageProvider =
    StateNotifierProvider.family<
      MessageNotifier,
      AsyncValue<Message?>,
      (String roomId, String userId)
    >((ref, params) {
      return MessageNotifier(
        ref: ref,
        roomId: params.$1,
        currentUserId: params.$2,
      );
    });
