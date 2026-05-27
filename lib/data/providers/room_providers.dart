import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/room.dart';
import '../services/local_storage_service.dart';
import '../services/supabase_service.dart';
import 'shared_items_providers.dart';

enum RoomStatus { idle, waiting, connected, error }

// ==================== Auth Provider ====================
final currentUserIdProvider = Provider<String?>((ref) {
  return Supabase.instance.client.auth.currentUser?.id;
});

class RoomState {
  final RoomStatus status;
  final Room? room;
  final String? customMessage;
  final DateTime? relationshipStartDate;
  final DateTime? periodStartedAt;
  final String message;

  const RoomState({
    required this.status,
    this.room,
    this.customMessage,
    this.relationshipStartDate,
    this.periodStartedAt,
    this.message = '',
  });

  factory RoomState.initial() => const RoomState(status: RoomStatus.idle);

  factory RoomState.loading(String message) =>
      RoomState(status: RoomStatus.waiting, message: message);

  factory RoomState.connected(
    Room room, {
    String? customMessage,
    DateTime? relationshipStartDate,
    DateTime? periodStartedAt,
    String message = '',
  }) => RoomState(
    status: RoomStatus.connected,
    room: room,
    customMessage: customMessage ?? room.customMessage,
    relationshipStartDate: relationshipStartDate ?? room.relationshipStartDate,
    periodStartedAt: periodStartedAt ?? room.periodStartedAt,
    message: message,
  );

  factory RoomState.error(String message) =>
      RoomState(status: RoomStatus.error, message: message);
}

class RoomNotifier extends StateNotifier<RoomState> {
  RoomNotifier(this.ref) : super(RoomState.initial()) {
    _restoreCurrentRoom();
  }

  final Ref ref;
  StreamSubscription<Room>? _roomSubscription;

  Future<void> _restoreCurrentRoom() async {
    final cachedSession = await LocalStorageService.getCurrentRoomSession();
    if (cachedSession == null) {
      await _loadCachedRelationshipTracker();
      return;
    }

    state = RoomState.loading('Recuperando tu espacio de pareja...');
    try {
      var room = await SupabaseService.getRoom(cachedSession.roomId);
      final currentUserId = ref.read(currentUserIdProvider);
      if (currentUserId != null) {
        room = await SupabaseService.assignRoomUser(room.id, currentUserId);
      }
      await _activateRoom(room, persistSession: true);
    } catch (error) {
      debugPrint('Error restoring room session: $error');
      await _activateCachedRoom(
        cachedSession.roomId,
        cachedSession.inviteCode,
        'No pude actualizar la sala guardada. Te dejo el espacio local mientras vuelve la conexión.',
      );
    }
  }

  Future<void> _loadCachedRelationshipTracker() async {
    final relationshipStartDate =
        await LocalStorageService.getCachedRelationshipStartDate();
    final periodStartedAt =
        await LocalStorageService.getCachedPeriodStartedAt();
    if (state.status == RoomStatus.connected) return;
    state = RoomState(
      status: state.status,
      room: state.room,
      customMessage: state.customMessage,
      relationshipStartDate: relationshipStartDate,
      periodStartedAt: periodStartedAt,
      message: state.message,
    );
  }

  Future<bool> createRoom(String inviteCode) async {
    state = RoomState.loading('Creando tu espacio de pareja...');
    try {
      var room = await SupabaseService.createRoom(inviteCode);
      final currentUserId = ref.read(currentUserIdProvider);
      if (currentUserId != null) {
        room = await SupabaseService.assignRoomUser(room.id, currentUserId);
      }
      await _activateRoom(room, persistSession: true);
      return true;
    } catch (error) {
      state = RoomState.error(error.toString());
      return false;
    }
  }

  Future<bool> joinRoom(String inviteCode) async {
    state = RoomState.loading('Buscando tu conexión...');
    try {
      var room = await SupabaseService.joinRoom(inviteCode);
      final currentUserId = ref.read(currentUserIdProvider);
      if (currentUserId != null) {
        room = await SupabaseService.assignRoomUser(room.id, currentUserId);
      }
      await _activateRoom(room, persistSession: true);
      return true;
    } catch (error) {
      state = RoomState.error(
        _isNoRowsError(error)
            ? 'No encontré una sala con ese código.'
            : error.toString(),
      );
      return false;
    }
  }

  Future<void> _activateRoom(Room room, {required bool persistSession}) async {
    final customMsg = await SupabaseService.getCustomMessage(room.id);
    await LocalStorageService.setCachedCustomMessage(customMsg);
    await LocalStorageService.setCachedRelationshipStartDate(
      room.relationshipStartDate,
    );
    await LocalStorageService.setCachedPeriodStartedAt(room.periodStartedAt);
    if (persistSession) {
      await LocalStorageService.saveCurrentRoomSession(
        roomId: room.id,
        inviteCode: room.inviteCode,
      );
    }

    state = RoomState.connected(
      room,
      customMessage: customMsg,
      relationshipStartDate:
          room.relationshipStartDate ??
          await LocalStorageService.getCachedRelationshipStartDate(),
      periodStartedAt:
          room.periodStartedAt ??
          await LocalStorageService.getCachedPeriodStartedAt(),
    );
    _subscribeToRoom(room.id);
    await ref.read(sharedItemsProvider.notifier).subscribe(room.id);
  }

  Future<void> _activateCachedRoom(
    String roomId,
    String inviteCode,
    String message,
  ) async {
    final cachedCustomMessage =
        await LocalStorageService.getCachedCustomMessage() ??
        'Tu espacio de pareja';
    final relationshipStartDate =
        await LocalStorageService.getCachedRelationshipStartDate();
    final periodStartedAt =
        await LocalStorageService.getCachedPeriodStartedAt();
    final now = DateTime.now();
    final room = Room(
      id: roomId,
      inviteCode: inviteCode,
      name: 'Nuestro espacio',
      createdAt: now,
      updatedAt: now,
      customMessage: cachedCustomMessage,
      relationshipStartDate: relationshipStartDate,
      periodStartedAt: periodStartedAt,
    );

    state = RoomState.connected(
      room,
      customMessage: cachedCustomMessage,
      relationshipStartDate: relationshipStartDate,
      periodStartedAt: periodStartedAt,
      message: message,
    );
  }

  bool _isNoRowsError(Object error) {
    if (error is PostgrestException) {
      final message = error.message.toLowerCase();
      return error.code == 'PGRST116' || message.contains('no rows');
    }
    return false;
  }

  void _subscribeToRoom(String roomId) {
    _roomSubscription?.cancel();
    _roomSubscription = SupabaseService.watchRoom(roomId).listen(
      (room) {
        if (state.status == RoomStatus.connected) {
          state = RoomState.connected(room);
          LocalStorageService.setCachedCustomMessage(room.customMessage);
          LocalStorageService.setCachedRelationshipStartDate(
            room.relationshipStartDate,
          );
          LocalStorageService.setCachedPeriodStartedAt(room.periodStartedAt);
        }
      },
      onError: (error) {
        debugPrint('Error watching room: $error');
      },
    );
  }

  Future<void> refreshCurrentRoom() async {
    if (state.status != RoomStatus.connected || state.room == null) return;
    final room = await SupabaseService.getRoom(state.room!.id);
    state = RoomState.connected(room);
    await LocalStorageService.setCachedCustomMessage(room.customMessage);
    await LocalStorageService.setCachedRelationshipStartDate(
      room.relationshipStartDate,
    );
    await LocalStorageService.setCachedPeriodStartedAt(room.periodStartedAt);
  }

  Future<void> leaveRoom() async {
    await _roomSubscription?.cancel();
    _roomSubscription = null;
    await LocalStorageService.clearCurrentRoomSession();
    await ref.read(sharedItemsProvider.notifier).clear();
    state = RoomState.initial();
    await _loadCachedRelationshipTracker();
  }

  Future<void> updateCustomMessage(String roomId, String customMessage) async {
    try {
      await SupabaseService.updateCustomMessage(roomId, customMessage);
      // Update local state
      if (state.status == RoomStatus.connected && state.room != null) {
        state = RoomState.connected(
          state.room!.copyWith(customMessage: customMessage),
          customMessage: customMessage,
          relationshipStartDate: state.relationshipStartDate,
          periodStartedAt: state.periodStartedAt,
        );
      }
      // Cache locally
      await LocalStorageService.setCachedCustomMessage(customMessage);
    } catch (e) {
      debugPrint('Error updating custom message: $e');
      rethrow;
    }
  }

  Future<void> updateRelationshipStartDate(DateTime? date) async {
    await LocalStorageService.setCachedRelationshipStartDate(date);
    final previous = state;
    state = RoomState(
      status: state.status,
      room: state.room?.copyWith(
        relationshipStartDate: date,
        clearRelationshipStartDate: date == null,
      ),
      customMessage: state.customMessage,
      relationshipStartDate: date,
      periodStartedAt: state.periodStartedAt,
      message: state.message,
    );

    if (previous.status != RoomStatus.connected || previous.room == null) {
      return;
    }

    try {
      final updated = await SupabaseService.updateRelationshipStartDate(
        previous.room!.id,
        date,
      );
      state = RoomState.connected(
        updated,
        relationshipStartDate: date,
        periodStartedAt: state.periodStartedAt,
      );
    } catch (error) {
      debugPrint('Error updating relationship start date: $error');
    }
  }

  Future<void> startPeriod([DateTime? date]) async {
    await updatePeriodStartedAt(date ?? DateTime.now());
  }

  Future<void> updatePeriodStartedAt(DateTime? date) async {
    await LocalStorageService.setCachedPeriodStartedAt(date);
    final previous = state;
    state = RoomState(
      status: state.status,
      room: state.room?.copyWith(
        periodStartedAt: date,
        clearPeriodStartedAt: date == null,
      ),
      customMessage: state.customMessage,
      relationshipStartDate: state.relationshipStartDate,
      periodStartedAt: date,
      message: state.message,
    );

    if (previous.status != RoomStatus.connected || previous.room == null) {
      return;
    }

    try {
      final updated = await SupabaseService.updatePeriodStartedAt(
        previous.room!.id,
        date,
      );
      state = RoomState.connected(
        updated,
        relationshipStartDate: state.relationshipStartDate,
        periodStartedAt: date,
      );
    } catch (error) {
      debugPrint('Error updating period start date: $error');
    }
  }

  @override
  void dispose() {
    _roomSubscription?.cancel();
    super.dispose();
  }
}

final roomStateProvider = StateNotifierProvider<RoomNotifier, RoomState>(
  (ref) => RoomNotifier(ref),
);

class PartnerPhotoNotifier extends StateNotifier<AsyncValue<String?>> {
  PartnerPhotoNotifier() : super(const AsyncValue.loading()) {
    _loadPhotoPath();
  }

  Future<void> _loadPhotoPath() async {
    try {
      final path = await LocalStorageService.getPartnerPhotoPath();
      state = AsyncValue.data(path);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> setPhotoPath(String path) async {
    await LocalStorageService.setPartnerPhotoPath(path);
    state = AsyncValue.data(path);
  }

  Future<void> clearPhotoPath() async {
    await LocalStorageService.clearPartnerPhotoPath();
    state = const AsyncValue.data(null);
  }
}

final partnerPhotoProvider =
    StateNotifierProvider<PartnerPhotoNotifier, AsyncValue<String?>>(
      (ref) => PartnerPhotoNotifier(),
    );
