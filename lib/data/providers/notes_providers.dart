import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:uuid/uuid.dart';

import '../models/note.dart';
import '../services/local_storage_service.dart';

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

  Future<void> toggleNoteFavorite(String noteId) async {
    final current = state.value ?? const NotesState.empty();
    final notes = current.notes
        .map(
          (note) => note.id == noteId
              ? note.copyWith(
                  isFavorite: !note.isFavorite,
                  updatedAt: DateTime.now(),
                )
              : note,
        )
        .toList();
    await _saveNotes(notes);
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

  Future<void> toggleAudioAttachmentReviewed(
    String noteId,
    String attachmentId,
  ) async {
    final current = state.value ?? const NotesState.empty();
    final notes = current.notes.map((note) {
      if (note.id != noteId) return note;
      return note.copyWith(
        audioAttachments: note.audioAttachments
            .map(
              (attachment) => attachment.id == attachmentId
                  ? attachment.copyWith(isReviewed: !attachment.isReviewed)
                  : attachment,
            )
            .toList(),
        updatedAt: DateTime.now(),
      );
    }).toList();
    await _saveNotes(notes);
  }

  Future<void> reorderAudioAttachments(
    String noteId,
    int oldIndex,
    int newIndex,
  ) async {
    final current = state.value ?? const NotesState.empty();
    final notes = current.notes.map((note) {
      if (note.id != noteId) return note;
      final attachments = [...note.audioAttachments];
      final moved = attachments.removeAt(oldIndex);
      attachments.insert(newIndex, moved);
      return note.copyWith(
        audioAttachments: attachments,
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

  Future<void> toggleFileAttachmentReviewed(
    String noteId,
    String attachmentId,
  ) async {
    final current = state.value ?? const NotesState.empty();
    final notes = current.notes.map((note) {
      if (note.id != noteId) return note;
      return note.copyWith(
        fileAttachments: note.fileAttachments
            .map(
              (attachment) => attachment.id == attachmentId
                  ? attachment.copyWith(isReviewed: !attachment.isReviewed)
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

final notesCountProvider = Provider<int>((ref) {
  final notesState = ref.watch(notesProvider);
  return notesState.maybeWhen(
    data: (state) => state.notes.length,
    orElse: () => 0,
  );
});
final notesProvider =
    StateNotifierProvider<NotesNotifier, AsyncValue<NotesState>>(
      (ref) => NotesNotifier(),
    );
