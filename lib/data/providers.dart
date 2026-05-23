import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'models/room.dart';
import 'models/shared_item.dart';
import 'models/note.dart';
import 'models/box_model.dart';
import 'models/message.dart';
import 'models/shopping_item.dart';
import 'models/study.dart';
import 'services/supabase_service.dart';
import 'services/local_storage_service.dart';
import 'services/study_notification_service.dart';

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

final roomStateProvider = StateNotifierProvider<RoomNotifier, RoomState>(
  (ref) => RoomNotifier(ref),
);
final sharedItemsProvider =
    StateNotifierProvider<SharedItemsNotifier, AsyncValue<List<SharedItem>>>(
      (ref) => SharedItemsNotifier(),
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

enum DeleteCategoryMode { deleteNotes, moveToUncategorized }

class NotesState {
  final List<Note> notes;
  final List<NoteCategory> categories;

  const NotesState({required this.notes, required this.categories});

  const NotesState.empty() : notes = const [], categories = const [];

  NotesState copyWith({List<Note>? notes, List<NoteCategory>? categories}) {
    return NotesState(
      notes: notes ?? this.notes,
      categories: categories ?? this.categories,
    );
  }
}

// Notes provider
class NotesNotifier extends StateNotifier<AsyncValue<NotesState>> {
  NotesNotifier() : super(const AsyncValue.loading()) {
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    state = const AsyncValue.loading();
    try {
      final notes = await LocalStorageService.getNotes();
      final categories = await LocalStorageService.getNoteCategories();
      state = AsyncValue.data(NotesState(notes: notes, categories: categories));
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> addNote(
    String title,
    String content, {
    String? categoryId,
  }) async {
    final note = Note(
      id: const Uuid().v4(),
      title: title,
      content: content,
      categoryId: categoryId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final current = state.value ?? const NotesState.empty();
    await _saveNotes([note, ...current.notes]);
  }

  Future<void> updateNote(Note updatedNote) async {
    final updated = updatedNote.copyWith(updatedAt: DateTime.now());
    final current = state.value ?? const NotesState.empty();
    await _saveNotes(
      current.notes
          .map((note) => note.id == updated.id ? updated : note)
          .toList(),
    );
  }

  Future<void> deleteNote(String noteId) async {
    final current = state.value ?? const NotesState.empty();
    Note? deletedNote;
    for (final note in current.notes) {
      if (note.id == noteId) {
        deletedNote = note;
        break;
      }
    }
    await _saveNotes(current.notes.where((note) => note.id != noteId).toList());
    if (deletedNote != null) {
      await _deleteAttachmentFiles(deletedNote.attachments);
      await _deleteAudioFiles(deletedNote.audioAttachments);
      await _deleteFileAttachmentFiles(deletedNote.fileAttachments);
    }
  }

  Future<void> addAudioAttachment(
    String noteId,
    NoteAudioAttachment attachment,
  ) async {
    final current = state.value ?? const NotesState.empty();
    final notes = current.notes.map((note) {
      if (note.id != noteId) return note;
      return note.copyWith(
        audioAttachments: [attachment, ...note.audioAttachments],
        updatedAt: DateTime.now(),
      );
    }).toList();
    await _saveNotes(notes);
  }

  Future<void> renameAudioAttachment(
    String noteId,
    String attachmentId,
    String? customName,
  ) async {
    final current = state.value ?? const NotesState.empty();
    final notes = current.notes.map((note) {
      if (note.id != noteId) return note;
      return note.copyWith(
        audioAttachments: note.audioAttachments
            .map(
              (attachment) => attachment.id == attachmentId
                  ? attachment.copyWith(
                      customName: customName,
                      clearCustomName: customName == null,
                    )
                  : attachment,
            )
            .toList(),
        updatedAt: DateTime.now(),
      );
    }).toList();
    await _saveNotes(notes);
  }

  Future<void> deleteAudioAttachment(String noteId, String attachmentId) async {
    final current = state.value ?? const NotesState.empty();
    NoteAudioAttachment? deletedAttachment;
    final notes = current.notes.map((note) {
      if (note.id != noteId) return note;
      final attachments = <NoteAudioAttachment>[];
      for (final attachment in note.audioAttachments) {
        if (attachment.id == attachmentId) {
          deletedAttachment = attachment;
        } else {
          attachments.add(attachment);
        }
      }
      return note.copyWith(
        audioAttachments: attachments,
        updatedAt: DateTime.now(),
      );
    }).toList();
    await _saveNotes(notes);
    if (deletedAttachment != null) {
      await _deleteAudioFiles([deletedAttachment!]);
    }
  }

  Future<void> addFileAttachment(
    String noteId,
    NoteFileAttachment attachment,
  ) async {
    final current = state.value ?? const NotesState.empty();
    final notes = current.notes.map((note) {
      if (note.id != noteId) return note;
      return note.copyWith(
        fileAttachments: [attachment, ...note.fileAttachments],
        updatedAt: DateTime.now(),
      );
    }).toList();
    await _saveNotes(notes);
  }

  Future<void> renameFileAttachment(
    String noteId,
    String attachmentId,
    String name,
  ) async {
    final current = state.value ?? const NotesState.empty();
    final notes = current.notes.map((note) {
      if (note.id != noteId) return note;
      return note.copyWith(
        fileAttachments: note.fileAttachments
            .map(
              (attachment) => attachment.id == attachmentId
                  ? attachment.copyWith(name: name)
                  : attachment,
            )
            .toList(),
        updatedAt: DateTime.now(),
      );
    }).toList();
    await _saveNotes(notes);
  }

  Future<void> deleteFileAttachment(String noteId, String attachmentId) async {
    final current = state.value ?? const NotesState.empty();
    NoteFileAttachment? deletedAttachment;
    final notes = current.notes.map((note) {
      if (note.id != noteId) return note;
      final attachments = <NoteFileAttachment>[];
      for (final attachment in note.fileAttachments) {
        if (attachment.id == attachmentId) {
          deletedAttachment = attachment;
        } else {
          attachments.add(attachment);
        }
      }
      return note.copyWith(
        fileAttachments: attachments,
        updatedAt: DateTime.now(),
      );
    }).toList();
    await _saveNotes(notes);
    if (deletedAttachment != null) {
      await _deleteFileAttachmentFiles([deletedAttachment!]);
    }
  }

  Future<void> addAttachment(String noteId, NoteAttachment attachment) async {
    final current = state.value ?? const NotesState.empty();
    final notes = current.notes.map((note) {
      if (note.id != noteId) return note;
      return note.copyWith(
        attachments: [attachment, ...note.attachments],
        updatedAt: DateTime.now(),
      );
    }).toList();
    await _saveNotes(notes);
  }

  Future<void> deleteAttachment(String noteId, String attachmentId) async {
    final current = state.value ?? const NotesState.empty();
    NoteAttachment? deletedAttachment;
    final notes = current.notes.map((note) {
      if (note.id != noteId) return note;
      final attachments = <NoteAttachment>[];
      for (final attachment in note.attachments) {
        if (attachment.id == attachmentId) {
          deletedAttachment = attachment;
        } else {
          attachments.add(attachment);
        }
      }
      return note.copyWith(attachments: attachments, updatedAt: DateTime.now());
    }).toList();
    await _saveNotes(notes);
    if (deletedAttachment != null) {
      await _deleteAttachmentFiles([deletedAttachment!]);
    }
  }

  Future<void> addCategory(String name) async {
    final now = DateTime.now();
    final category = NoteCategory(
      id: const Uuid().v4(),
      name: name,
      createdAt: now,
      updatedAt: now,
    );
    final current = state.value ?? const NotesState.empty();
    await _saveCategories([category, ...current.categories]);
  }

  Future<void> updateCategory(NoteCategory category) async {
    final current = state.value ?? const NotesState.empty();
    final updated = category.copyWith(updatedAt: DateTime.now());
    await _saveCategories(
      current.categories
          .map((existing) => existing.id == updated.id ? updated : existing)
          .toList(),
    );
  }

  Future<void> deleteCategory(
    String categoryId, {
    required DeleteCategoryMode mode,
  }) async {
    final current = state.value ?? const NotesState.empty();
    final deletedNotes = mode == DeleteCategoryMode.deleteNotes
        ? current.notes.where((note) => note.categoryId == categoryId).toList()
        : const <Note>[];
    final categories = current.categories
        .where((category) => category.id != categoryId)
        .toList();
    final notes = switch (mode) {
      DeleteCategoryMode.deleteNotes =>
        current.notes.where((note) => note.categoryId != categoryId).toList(),
      DeleteCategoryMode.moveToUncategorized =>
        current.notes
            .map(
              (note) => note.categoryId == categoryId
                  ? note.copyWith(
                      clearCategory: true,
                      updatedAt: DateTime.now(),
                    )
                  : note,
            )
            .toList(),
    };

    final previous = current;
    state = AsyncValue.data(NotesState(notes: notes, categories: categories));
    try {
      await LocalStorageService.saveNotes(notes);
      await LocalStorageService.saveNoteCategories(categories);
      for (final note in deletedNotes) {
        await _deleteAttachmentFiles(note.attachments);
        await _deleteAudioFiles(note.audioAttachments);
        await _deleteFileAttachmentFiles(note.fileAttachments);
      }
    } catch (error, stackTrace) {
      state = AsyncValue.data(previous);
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> _saveNotes(List<Note> notes) async {
    final current = state.value ?? const NotesState.empty();
    state = AsyncValue.data(current.copyWith(notes: notes));
    try {
      await LocalStorageService.saveNotes(notes);
    } catch (error, stackTrace) {
      state = AsyncValue.data(current);
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> _saveCategories(List<NoteCategory> categories) async {
    final current = state.value ?? const NotesState.empty();
    state = AsyncValue.data(current.copyWith(categories: categories));
    try {
      await LocalStorageService.saveNoteCategories(categories);
    } catch (error, stackTrace) {
      state = AsyncValue.data(current);
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> _deleteAttachmentFiles(List<NoteAttachment> attachments) async {
    for (final attachment in attachments) {
      try {
        final file = File(attachment.path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {
        // Metadata is already updated; stale local files should not block notes.
      }
    }
  }

  Future<void> _deleteAudioFiles(List<NoteAudioAttachment> attachments) async {
    for (final attachment in attachments) {
      try {
        final file = File(attachment.path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {
        // Metadata is already updated; stale local files should not block notes.
      }
    }
  }

  Future<void> _deleteFileAttachmentFiles(
    List<NoteFileAttachment> attachments,
  ) async {
    for (final attachment in attachments) {
      try {
        final file = File(attachment.path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {
        // Metadata is already updated; stale local files should not block notes.
      }
    }
  }
}

class BoxesState {
  final List<Box> boxes;
  final List<BoxTemplate> templates;
  final List<MaterialTemplate> materialTemplates;

  const BoxesState({
    required this.boxes,
    required this.templates,
    required this.materialTemplates,
  });

  const BoxesState.empty()
    : boxes = const [],
      templates = const [],
      materialTemplates = const [];

  BoxesState copyWith({
    List<Box>? boxes,
    List<BoxTemplate>? templates,
    List<MaterialTemplate>? materialTemplates,
  }) {
    return BoxesState(
      boxes: boxes ?? this.boxes,
      templates: templates ?? this.templates,
      materialTemplates: materialTemplates ?? this.materialTemplates,
    );
  }
}

// Boxes provider
class BoxesNotifier extends StateNotifier<AsyncValue<BoxesState>> {
  BoxesNotifier() : super(const AsyncValue.loading()) {
    _loadBoxes();
  }

  Future<void> _loadBoxes() async {
    state = const AsyncValue.loading();
    try {
      final boxes = await LocalStorageService.getBoxes();
      final templates = await LocalStorageService.getBoxTemplates();
      final materialTemplates =
          await LocalStorageService.getMaterialTemplates();
      state = AsyncValue.data(
        BoxesState(
          boxes: boxes,
          templates: templates,
          materialTemplates: materialTemplates,
        ),
      );
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> addBox(
    String title,
    String description, {
    List<MaterialItem> items = const [],
  }) async {
    final box = Box(
      id: const Uuid().v4(),
      title: title,
      description: description,
      items: items,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final current = state.value ?? const BoxesState.empty();
    await _saveBoxes([box, ...current.boxes]);
  }

  Future<void> addBoxFromTemplate(BoxTemplate template) async {
    final current = state.value ?? const BoxesState.empty();
    await _saveBoxes([template.toBox(const Uuid().v4()), ...current.boxes]);
  }

  Future<void> updateBox(Box updatedBox) async {
    final updated = updatedBox.copyWith(updatedAt: DateTime.now());
    final current = state.value ?? const BoxesState.empty();
    await _saveBoxes(
      current.boxes.map((box) => box.id == updated.id ? updated : box).toList(),
    );
  }

  Future<void> deleteBox(String boxId) async {
    final current = state.value ?? const BoxesState.empty();
    await _saveBoxes(current.boxes.where((box) => box.id != boxId).toList());
  }

  Future<void> addItemToBox(String boxId, String item) async {
    final current = state.value ?? const BoxesState.empty();
    final boxIndex = current.boxes.indexWhere((box) => box.id == boxId);
    if (boxIndex == -1) return;

    final box = current.boxes[boxIndex];
    final updatedBox = box.copyWith(
      items: [...box.items, MaterialItem.create(item)],
    );
    await updateBox(updatedBox);
  }

  Future<void> insertMaterialTemplatesIntoBox(
    String boxId,
    List<MaterialTemplate> materialTemplates,
  ) async {
    if (materialTemplates.isEmpty) return;
    final current = state.value ?? const BoxesState.empty();
    final boxIndex = current.boxes.indexWhere((box) => box.id == boxId);
    if (boxIndex == -1) return;

    final box = current.boxes[boxIndex];
    final newItems = materialTemplates
        .expand((template) => template.createItems())
        .toList();
    await updateBox(box.copyWith(items: [...box.items, ...newItems]));
  }

  Future<void> updateItemInBox(String boxId, MaterialItem updatedItem) async {
    final current = state.value ?? const BoxesState.empty();
    final box = current.boxes.firstWhere((box) => box.id == boxId);
    final updatedBox = box.copyWith(
      items: box.items
          .map(
            (item) => item.id == updatedItem.id
                ? updatedItem.copyWith(updatedAt: DateTime.now())
                : item,
          )
          .toList(),
    );
    await updateBox(updatedBox);
  }

  Future<void> toggleItemInBox(String boxId, MaterialItem item) async {
    await updateItemInBox(boxId, item.copyWith(completed: !item.completed));
  }

  Future<void> removeItemFromBox(String boxId, int itemIndex) async {
    final current = state.value ?? const BoxesState.empty();
    final boxIndex = current.boxes.indexWhere((box) => box.id == boxId);
    if (boxIndex == -1) return;

    final box = current.boxes[boxIndex];
    final updatedItems = [...box.items]..removeAt(itemIndex);
    await updateBox(box.copyWith(items: updatedItems));
  }

  Future<void> addTemplate(
    String title,
    String description, {
    List<MaterialItem> items = const [],
  }) async {
    final now = DateTime.now();
    final template = BoxTemplate(
      id: const Uuid().v4(),
      title: title,
      description: description,
      items: items,
      createdAt: now,
      updatedAt: now,
    );
    final current = state.value ?? const BoxesState.empty();
    await _saveTemplates([template, ...current.templates]);
  }

  Future<void> updateTemplate(BoxTemplate updatedTemplate) async {
    final updated = updatedTemplate.copyWith(updatedAt: DateTime.now());
    final current = state.value ?? const BoxesState.empty();
    await _saveTemplates(
      current.templates
          .map((template) => template.id == updated.id ? updated : template)
          .toList(),
    );
  }

  Future<void> deleteTemplate(String templateId) async {
    final current = state.value ?? const BoxesState.empty();
    await _saveTemplates(
      current.templates.where((template) => template.id != templateId).toList(),
    );
  }

  Future<void> addItemToTemplate(String templateId, String item) async {
    final current = state.value ?? const BoxesState.empty();
    final template = current.templates.firstWhere(
      (template) => template.id == templateId,
    );
    await updateTemplate(
      template.copyWith(items: [...template.items, MaterialItem.create(item)]),
    );
  }

  Future<void> insertMaterialTemplatesIntoBoxTemplate(
    String templateId,
    List<MaterialTemplate> materialTemplates,
  ) async {
    if (materialTemplates.isEmpty) return;
    final current = state.value ?? const BoxesState.empty();
    final template = current.templates.firstWhere(
      (template) => template.id == templateId,
    );
    final newItems = materialTemplates
        .expand((template) => template.createItems())
        .toList();
    await updateTemplate(
      template.copyWith(items: [...template.items, ...newItems]),
    );
  }

  Future<void> updateItemInTemplate(
    String templateId,
    MaterialItem updatedItem,
  ) async {
    final current = state.value ?? const BoxesState.empty();
    final template = current.templates.firstWhere(
      (template) => template.id == templateId,
    );
    await updateTemplate(
      template.copyWith(
        items: template.items
            .map(
              (item) => item.id == updatedItem.id
                  ? updatedItem.copyWith(updatedAt: DateTime.now())
                  : item,
            )
            .toList(),
      ),
    );
  }

  Future<void> removeItemFromTemplate(String templateId, int itemIndex) async {
    final current = state.value ?? const BoxesState.empty();
    final template = current.templates.firstWhere(
      (template) => template.id == templateId,
    );
    final items = [...template.items]..removeAt(itemIndex);
    await updateTemplate(template.copyWith(items: items));
  }

  Future<void> addMaterialTemplate(
    String title, {
    MaterialTemplateKind kind = MaterialTemplateKind.group,
    List<MaterialItem> items = const [],
  }) async {
    final now = DateTime.now();
    final template = MaterialTemplate(
      id: const Uuid().v4(),
      title: title,
      kind: kind,
      items: kind == MaterialTemplateKind.individual && items.length > 1
          ? [items.first]
          : items,
      createdAt: now,
      updatedAt: now,
    );
    final current = state.value ?? const BoxesState.empty();
    await _saveMaterialTemplates([template, ...current.materialTemplates]);
  }

  Future<void> updateMaterialTemplate(MaterialTemplate updatedTemplate) async {
    final updated = updatedTemplate.copyWith(updatedAt: DateTime.now());
    final current = state.value ?? const BoxesState.empty();
    await _saveMaterialTemplates(
      current.materialTemplates
          .map((template) => template.id == updated.id ? updated : template)
          .toList(),
    );
  }

  Future<void> deleteMaterialTemplate(String templateId) async {
    final current = state.value ?? const BoxesState.empty();
    await _saveMaterialTemplates(
      current.materialTemplates
          .where((template) => template.id != templateId)
          .toList(),
    );
  }

  Future<void> addItemToMaterialTemplate(String templateId, String item) async {
    final current = state.value ?? const BoxesState.empty();
    final template = current.materialTemplates.firstWhere(
      (template) => template.id == templateId,
    );
    await updateMaterialTemplate(
      template.kind == MaterialTemplateKind.individual
          ? template.copyWith(items: [MaterialItem.create(item)])
          : template.copyWith(
              items: [...template.items, MaterialItem.create(item)],
            ),
    );
  }

  Future<void> updateItemInMaterialTemplate(
    String templateId,
    MaterialItem updatedItem,
  ) async {
    final current = state.value ?? const BoxesState.empty();
    final template = current.materialTemplates.firstWhere(
      (template) => template.id == templateId,
    );
    await updateMaterialTemplate(
      template.copyWith(
        items: template.items
            .map(
              (item) => item.id == updatedItem.id
                  ? updatedItem.copyWith(updatedAt: DateTime.now())
                  : item,
            )
            .toList(),
      ),
    );
  }

  Future<void> removeItemFromMaterialTemplate(
    String templateId,
    int itemIndex,
  ) async {
    final current = state.value ?? const BoxesState.empty();
    final template = current.materialTemplates.firstWhere(
      (template) => template.id == templateId,
    );
    final items = [...template.items]..removeAt(itemIndex);
    await updateMaterialTemplate(template.copyWith(items: items));
  }

  Future<void> _saveBoxes(List<Box> boxes) async {
    final current = state.value ?? const BoxesState.empty();
    state = AsyncValue.data(current.copyWith(boxes: boxes));
    try {
      await LocalStorageService.saveBoxes(boxes);
    } catch (error, stackTrace) {
      state = AsyncValue.data(current);
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> _saveTemplates(List<BoxTemplate> templates) async {
    final current = state.value ?? const BoxesState.empty();
    state = AsyncValue.data(current.copyWith(templates: templates));
    try {
      await LocalStorageService.saveBoxTemplates(templates);
    } catch (error, stackTrace) {
      state = AsyncValue.data(current);
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> _saveMaterialTemplates(
    List<MaterialTemplate> materialTemplates,
  ) async {
    final current = state.value ?? const BoxesState.empty();
    state = AsyncValue.data(
      current.copyWith(materialTemplates: materialTemplates),
    );
    try {
      await LocalStorageService.saveMaterialTemplates(materialTemplates);
    } catch (error, stackTrace) {
      state = AsyncValue.data(current);
      state = AsyncValue.error(error, stackTrace);
    }
  }
}

class ShoppingState {
  final List<ShoppingItem> items;
  final List<ShoppingTemplate> templates;
  final List<ShoppingCategory> categories;

  const ShoppingState({
    required this.items,
    required this.templates,
    required this.categories,
  });

  const ShoppingState.empty()
    : items = const [],
      templates = const [],
      categories = const [];

  ShoppingState copyWith({
    List<ShoppingItem>? items,
    List<ShoppingTemplate>? templates,
    List<ShoppingCategory>? categories,
  }) {
    return ShoppingState(
      items: items ?? this.items,
      templates: templates ?? this.templates,
      categories: categories ?? this.categories,
    );
  }
}

// Shopping provider (personal/local)
class ShoppingNotifier extends StateNotifier<AsyncValue<ShoppingState>> {
  ShoppingNotifier() : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    state = const AsyncValue.loading();
    try {
      final items = await LocalStorageService.getShoppingItems();
      final templates = await LocalStorageService.getShoppingTemplates();
      final categories = await LocalStorageService.getShoppingCategories();
      state = AsyncValue.data(
        ShoppingState(
          items: items,
          templates: templates,
          categories: categories,
        ),
      );
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> refresh() => _load();

  Future<void> addItem(
    String title, {
    String? notes,
    double? price,
    String? categoryId,
  }) async {
    final now = DateTime.now();
    final item = ShoppingItem(
      id: const Uuid().v4(),
      title: title,
      notes: notes,
      price: price,
      categoryId: categoryId,
      completed: false,
      createdAt: now,
      updatedAt: now,
    );
    await _saveItems([item, ...(state.value?.items ?? [])]);
  }

  Future<void> updateItem(ShoppingItem item) async {
    final current = state.value ?? const ShoppingState.empty();
    final updated = item.copyWith(updatedAt: DateTime.now());
    final items = current.items
        .map((existing) => existing.id == updated.id ? updated : existing)
        .toList();
    await _saveItems(items);
  }

  Future<void> toggleCompletion(ShoppingItem item) async {
    await updateItem(item.copyWith(completed: !item.completed));
  }

  Future<void> removeItem(ShoppingItem item) async {
    final current = state.value ?? const ShoppingState.empty();
    await _saveItems(
      current.items.where((existing) => existing.id != item.id).toList(),
    );
  }

  Future<void> addTemplate(
    String title, {
    String? notes,
    double? price,
    String? categoryId,
  }) async {
    final now = DateTime.now();
    final template = ShoppingTemplate(
      id: const Uuid().v4(),
      title: title,
      notes: notes,
      price: price,
      categoryId: categoryId,
      createdAt: now,
      updatedAt: now,
    );
    await _saveTemplates([template, ...(state.value?.templates ?? [])]);
  }

  Future<void> addCategory(String name) async {
    final now = DateTime.now();
    final category = ShoppingCategory(
      id: const Uuid().v4(),
      name: name,
      createdAt: now,
      updatedAt: now,
    );
    final current = state.value ?? const ShoppingState.empty();
    await _saveCategories([category, ...current.categories]);
  }

  Future<void> updateCategory(ShoppingCategory category) async {
    final current = state.value ?? const ShoppingState.empty();
    final updated = category.copyWith(updatedAt: DateTime.now());
    await _saveCategories(
      current.categories
          .map((existing) => existing.id == updated.id ? updated : existing)
          .toList(),
    );
  }

  Future<void> deleteCategory(String categoryId) async {
    final current = state.value ?? const ShoppingState.empty();
    final categories = current.categories
        .where((category) => category.id != categoryId)
        .toList();
    final items = current.items
        .map(
          (item) => item.categoryId == categoryId
              ? item.copyWith(clearCategory: true, updatedAt: DateTime.now())
              : item,
        )
        .toList();
    final templates = current.templates
        .map(
          (template) => template.categoryId == categoryId
              ? template.copyWith(
                  clearCategory: true,
                  updatedAt: DateTime.now(),
                )
              : template,
        )
        .toList();

    final previous = current;
    state = AsyncValue.data(
      ShoppingState(items: items, templates: templates, categories: categories),
    );
    try {
      await LocalStorageService.saveShoppingItems(items);
      await LocalStorageService.saveShoppingTemplates(templates);
      await LocalStorageService.saveShoppingCategories(categories);
    } catch (error, stackTrace) {
      state = AsyncValue.data(previous);
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> updateTemplate(ShoppingTemplate template) async {
    final current = state.value ?? const ShoppingState.empty();
    final updated = template.copyWith(updatedAt: DateTime.now());
    final templates = current.templates
        .map((existing) => existing.id == updated.id ? updated : existing)
        .toList();
    await _saveTemplates(templates);
  }

  Future<void> removeTemplate(ShoppingTemplate template) async {
    final current = state.value ?? const ShoppingState.empty();
    await _saveTemplates(
      current.templates
          .where((existing) => existing.id != template.id)
          .toList(),
    );
  }

  Future<void> addItemFromTemplate(ShoppingTemplate template) async {
    await _saveItems([
      template.toItem(const Uuid().v4()),
      ...?state.value?.items,
    ]);
  }

  Future<void> _saveItems(List<ShoppingItem> items) async {
    final current = state.value ?? const ShoppingState.empty();
    state = AsyncValue.data(current.copyWith(items: items));
    try {
      await LocalStorageService.saveShoppingItems(items);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> _saveTemplates(List<ShoppingTemplate> templates) async {
    final current = state.value ?? const ShoppingState.empty();
    state = AsyncValue.data(current.copyWith(templates: templates));
    try {
      await LocalStorageService.saveShoppingTemplates(templates);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> _saveCategories(List<ShoppingCategory> categories) async {
    final current = state.value ?? const ShoppingState.empty();
    state = AsyncValue.data(current.copyWith(categories: categories));
    try {
      await LocalStorageService.saveShoppingCategories(categories);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}

class StudyState {
  final List<StudyGoal> goals;
  final List<StudySession> sessions;
  final List<StudyTemplate> templates;

  const StudyState({
    required this.goals,
    required this.sessions,
    required this.templates,
  });

  const StudyState.empty()
    : goals = const [],
      sessions = const [],
      templates = const [];

  StudyState copyWith({
    List<StudyGoal>? goals,
    List<StudySession>? sessions,
    List<StudyTemplate>? templates,
  }) {
    return StudyState(
      goals: goals ?? this.goals,
      sessions: sessions ?? this.sessions,
      templates: templates ?? this.templates,
    );
  }
}

class StudyNotifier extends StateNotifier<AsyncValue<StudyState>> {
  StudyNotifier() : super(const AsyncValue.loading()) {
    _loadStudy();
  }

  Future<void> _loadStudy() async {
    try {
      final goals = await LocalStorageService.getStudyGoals();
      final sessions = await LocalStorageService.getStudySessions();
      final storedTemplates = await LocalStorageService.getStudyTemplates();
      state = AsyncValue.data(
        StudyState(
          goals: goals,
          sessions: sessions,
          templates: [..._presetTemplates(), ...storedTemplates],
        ),
      );
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> addGoal({
    required int weekday,
    required int durationMinutes,
    required List<String> topics,
    String? incentive,
    String? templateId,
    DateTime? reminderAt,
  }) async {
    final now = DateTime.now();
    final goal = StudyGoal(
      id: const Uuid().v4(),
      weekday: weekday,
      durationMinutes: durationMinutes,
      topics: topics,
      incentive: incentive,
      templateId: templateId,
      reminderAt: reminderAt,
      createdAt: now,
      updatedAt: now,
    );
    final current = state.value ?? const StudyState.empty();
    await _saveGoals([goal, ...current.goals]);
    await _scheduleReminder(goal);
  }

  Future<void> updateGoal(StudyGoal goal) async {
    final current = state.value ?? const StudyState.empty();
    final updated = goal.copyWith(updatedAt: DateTime.now());
    await _saveGoals(
      current.goals
          .map((item) => item.id == updated.id ? updated : item)
          .toList(),
    );
    await StudyNotificationService.cancelReminder(_notificationId(updated.id));
    await _scheduleReminder(updated);
  }

  Future<void> deleteGoal(StudyGoal goal) async {
    final current = state.value ?? const StudyState.empty();
    await _saveGoals(
      current.goals.where((item) => item.id != goal.id).toList(),
    );
    await StudyNotificationService.cancelReminder(_notificationId(goal.id));
  }

  Future<void> completeSession({
    String? goalId,
    String? templateId,
    required List<String> topics,
    required int plannedMinutes,
    required int completedMinutes,
    String? incentive,
    DateTime? startedAt,
  }) async {
    final session = StudySession(
      id: const Uuid().v4(),
      goalId: goalId,
      templateId: templateId,
      topics: topics,
      plannedMinutes: plannedMinutes,
      completedMinutes: completedMinutes,
      incentive: incentive,
      startedAt: startedAt ?? DateTime.now(),
      completedAt: DateTime.now(),
    );
    final current = state.value ?? const StudyState.empty();
    await _saveSessions([session, ...current.sessions]);
  }

  Future<void> addTemplate(String title, String description) async {
    final template = StudyTemplate(
      id: const Uuid().v4(),
      title: title,
      description: description,
      kind: StudyTemplateKind.custom,
      createdAt: DateTime.now(),
    );
    final current = state.value ?? const StudyState.empty();
    final custom = current.templates
        .where((template) => template.kind == StudyTemplateKind.custom)
        .toList();
    await _saveCustomTemplates([template, ...custom]);
  }

  Future<void> deleteTemplate(StudyTemplate template) async {
    if (template.kind == StudyTemplateKind.preset) return;
    final current = state.value ?? const StudyState.empty();
    final custom = current.templates
        .where(
          (item) =>
              item.kind == StudyTemplateKind.custom && item.id != template.id,
        )
        .toList();
    await _saveCustomTemplates(custom);
  }

  Future<void> _saveGoals(List<StudyGoal> goals) async {
    final current = state.value ?? const StudyState.empty();
    state = AsyncValue.data(current.copyWith(goals: goals));
    try {
      await LocalStorageService.saveStudyGoals(goals);
    } catch (error, stackTrace) {
      state = AsyncValue.data(current);
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> _saveSessions(List<StudySession> sessions) async {
    final current = state.value ?? const StudyState.empty();
    state = AsyncValue.data(current.copyWith(sessions: sessions));
    try {
      await LocalStorageService.saveStudySessions(sessions);
    } catch (error, stackTrace) {
      state = AsyncValue.data(current);
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> _saveCustomTemplates(List<StudyTemplate> custom) async {
    final current = state.value ?? const StudyState.empty();
    final templates = [..._presetTemplates(), ...custom];
    state = AsyncValue.data(current.copyWith(templates: templates));
    try {
      await LocalStorageService.saveStudyTemplates(custom);
    } catch (error, stackTrace) {
      state = AsyncValue.data(current);
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> _scheduleReminder(StudyGoal goal) async {
    final reminder = goal.reminderAt;
    if (reminder == null) return;
    await StudyNotificationService.scheduleStudyReminder(
      id: _notificationId(goal.id),
      reminderAt: reminder,
      title: 'Momento de estudiar',
      body: goal.topics.isEmpty
          ? 'Una sesión pequeña también cuenta.'
          : 'Hoy toca: ${goal.topics.join(', ')}',
    );
  }

  int _notificationId(String id) => id.hashCode & 0x7fffffff;

  List<StudyTemplate> _presetTemplates() {
    final now = DateTime(2026);
    return [
      StudyTemplate(
        id: 'preset_flashcards',
        title: 'Hacer flashcards',
        description: 'Repasar conceptos clave en tarjetas rápidas.',
        kind: StudyTemplateKind.preset,
        createdAt: now,
      ),
      StudyTemplate(
        id: 'preset_video',
        title: 'Ver un video',
        description: 'Mirar una explicación breve y tomar apuntes.',
        kind: StudyTemplateKind.preset,
        createdAt: now,
      ),
      StudyTemplate(
        id: 'preset_summary',
        title: 'Hacer resumen corto',
        description: 'Ordenar lo importante en una página.',
        kind: StudyTemplateKind.preset,
        createdAt: now,
      ),
      StudyTemplate(
        id: 'preset_questions',
        title: 'Responder preguntas',
        description: 'Practicar recuperación activa sin mirar apuntes.',
        kind: StudyTemplateKind.preset,
        createdAt: now,
      ),
      StudyTemplate(
        id: 'preset_map',
        title: 'Hacer mapa conceptual',
        description: 'Conectar ideas y procesos visualmente.',
        kind: StudyTemplateKind.preset,
        createdAt: now,
      ),
    ];
  }
}

// Computed count providers
final pendingTodosCountProvider = Provider<int>((ref) {
  final sharedItems = ref.watch(sharedItemsProvider);
  return sharedItems.maybeWhen(
    data: (items) => items.where((item) => !item.completed).length,
    orElse: () => 0,
  );
});

final pendingShoppingCountProvider = Provider<int>((ref) {
  final shoppingState = ref.watch(shoppingProvider);
  return shoppingState.maybeWhen(
    data: (state) => state.items.where((item) => !item.completed).length,
    orElse: () => 0,
  );
});

final notesCountProvider = Provider<int>((ref) {
  final notesState = ref.watch(notesProvider);
  return notesState.maybeWhen(
    data: (state) => state.notes.length,
    orElse: () => 0,
  );
});

final boxesCountProvider = Provider<int>((ref) {
  final boxesState = ref.watch(boxesProvider);
  return boxesState.maybeWhen(
    data: (state) => state.boxes.length,
    orElse: () => 0,
  );
});

final notesProvider =
    StateNotifierProvider<NotesNotifier, AsyncValue<NotesState>>(
      (ref) => NotesNotifier(),
    );

final boxesProvider =
    StateNotifierProvider<BoxesNotifier, AsyncValue<BoxesState>>(
      (ref) => BoxesNotifier(),
    );

final shoppingProvider =
    StateNotifierProvider<ShoppingNotifier, AsyncValue<ShoppingState>>(
      (ref) => ShoppingNotifier(),
    );

final studyProvider =
    StateNotifierProvider<StudyNotifier, AsyncValue<StudyState>>(
      (ref) => StudyNotifier(),
    );

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
