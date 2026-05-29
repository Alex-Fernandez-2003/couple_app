import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import '../../../data/models/note.dart';
import '../../../data/providers.dart';
import '../../../shared/widgets/floral_background.dart';
import '../../../shared/widgets/soft_animations.dart';

part '../widgets/notes_list_widgets.dart';
part '../widgets/note_attachments_dialog.dart';
part '../widgets/note_file_attachment_widgets.dart';
part '../widgets/note_audio_attachment_widgets.dart';
part '../widgets/note_dialogs_widgets.dart';
part '../widgets/notes_state_widgets.dart';
part '../widgets/notes_utils.dart';

final _recordingNotifications = FlutterLocalNotificationsPlugin();
bool _recordingNotificationsInitialized = false;

class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _updateQuery(String value) {
    setState(() => _query = value.trim().toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(notesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notas'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_outlined),
            tooltip: 'Gestionar categorías',
            onPressed: () => _showCategoriesDialog(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Nueva nota',
            onPressed: () => _showNoteDialog(context, ref),
          ),
        ],
      ),
      body: notesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          error: error,
          onRetry: () => ref.invalidate(notesProvider),
        ),
        data: (state) {
          if (state.notes.isEmpty) {
            return _EmptyState(
              icon: Icons.note_outlined,
              title: 'Tu diario personal',
              message:
                  'Un espacio para tus pensamientos, recuerdos y materias importantes.',
              actionLabel: 'Escribir primera nota',
              onAction: () => _showNoteDialog(context, ref),
            );
          }

          return _GroupedNotesList(
            notes: _filterNotes(state.notes, state.categories, _query),
            categories: state.categories,
            searchController: _searchController,
            query: _query,
            onSearchChanged: _updateQuery,
            onToggleFavorite: (note) =>
                ref.read(notesProvider.notifier).toggleNoteFavorite(note.id),
            onEdit: (note) => _showNoteDialog(context, ref, note: note),
            onDelete: (note) => _showDeleteNoteConfirmation(context, ref, note),
            onAttachments: (note) => _showAttachmentsDialog(context, ref, note),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNoteDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nota'),
        backgroundColor: const Color(0xFFFD8392),
        foregroundColor: Colors.white,
      ),
    );
  }
}

void _showNoteDialog(BuildContext context, WidgetRef ref, {Note? note}) {
  final state = ref.read(notesProvider).value ?? const NotesState.empty();
  showDialog(
    context: context,
    builder: (context) => _NoteDialog(
      title: note == null ? 'Nueva nota' : 'Editar nota',
      categories: state.categories,
      initialTitle: note?.title,
      initialContent: note?.content,
      initialCategoryId: note?.categoryId,
      onSave: (values) async {
        final notifier = ref.read(notesProvider.notifier);
        if (note == null) {
          await notifier.addNote(
            values.title,
            values.content,
            categoryId: values.categoryId,
          );
        } else {
          await notifier.updateNote(
            note.copyWith(
              title: values.title,
              content: values.content,
              categoryId: values.categoryId,
              clearCategory: values.categoryId == null,
            ),
          );
        }
      },
    ),
  );
}

void _showCategoriesDialog(BuildContext context, WidgetRef ref) {
  showDialog(
    context: context,
    builder: (context) => _CategoriesDialog(ref: ref),
  );
}

void _showAttachmentsDialog(BuildContext context, WidgetRef ref, Note note) {
  showDialog(
    context: context,
    builder: (context) => _NoteAttachmentsDialog(noteId: note.id),
  );
}

void _showDeleteNoteConfirmation(
  BuildContext context,
  WidgetRef ref,
  Note note,
) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Eliminar nota'),
      content: Text('¿Eliminar "${note.title}"?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () async {
            await ref.read(notesProvider.notifier).deleteNote(note.id);
            if (context.mounted) Navigator.of(context).pop();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text('Eliminar'),
        ),
      ],
    ),
  );
}
