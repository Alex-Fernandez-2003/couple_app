import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:uuid/uuid.dart';

import '../models/shared_item.dart';
import '../services/supabase_service.dart';

class SharedItemsNotifier extends StateNotifier<AsyncValue<List<SharedItem>>> {
  SharedItemsNotifier() : super(const AsyncValue.data([]));

  StreamSubscription<List<SharedItem>>? _subscription;

  Future<void> subscribe(String roomId) async {
    await _subscription?.cancel();
    state = const AsyncValue.loading();

    try {
      final initialItems = await SupabaseService.getRoomItems(
        roomId,
        type: 'todo',
      );
      state = AsyncValue.data(initialItems);
      _subscription = SupabaseService.subscribeToRoomItems(roomId, type: 'todo')
          .listen(
            (items) {
              state = AsyncValue.data(items);
            },
            onError: (error, stackTrace) {
              state = AsyncValue.error(error, stackTrace);
            },
          );
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> refresh(String roomId) async {
    await subscribe(roomId);
  }

  Future<void> clear() async {
    await _subscription?.cancel();
    _subscription = null;
    state = const AsyncValue.data([]);
  }

  Future<void> addItem(String roomId, String title) async {
    final item = SharedItem(
      id: const Uuid().v4(),
      roomId: roomId,
      type: 'todo',
      title: title,
      details: null,
      price: null,
      category: null,
      completed: false,
      updatedAt: DateTime.now(),
    );
    final currentItems = state.value ?? [];
    state = AsyncValue.data([item, ...currentItems]);

    try {
      await SupabaseService.addSharedItem(item);
    } catch (error, stackTrace) {
      state = AsyncValue.data(currentItems);
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> toggleCompletion(SharedItem item) async {
    final updated = item.copyWith(
      completed: !item.completed,
      updatedAt: DateTime.now(),
    );
    final currentItems = state.value ?? [];
    state = AsyncValue.data(
      currentItems.map((existing) {
        return existing.id == updated.id ? updated : existing;
      }).toList(),
    );

    try {
      await SupabaseService.updateSharedItem(updated);
    } catch (error, stackTrace) {
      await refresh(updated.roomId);
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> removeItem(SharedItem item) async {
    final currentItems = state.value ?? [];
    state = AsyncValue.data(
      currentItems.where((existing) => existing.id != item.id).toList(),
    );

    try {
      await SupabaseService.deleteSharedItem(item.id);
    } catch (error, stackTrace) {
      await refresh(item.roomId);
      state = AsyncValue.error(error, stackTrace);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final sharedItemsProvider =
    StateNotifierProvider<SharedItemsNotifier, AsyncValue<List<SharedItem>>>(
      (ref) => SharedItemsNotifier(),
    );

// Computed count providers
final pendingTodosCountProvider = Provider<int>((ref) {
  final sharedItems = ref.watch(sharedItemsProvider);
  return sharedItems.maybeWhen(
    data: (items) => items.where((item) => !item.completed).length,
    orElse: () => 0,
  );
});
