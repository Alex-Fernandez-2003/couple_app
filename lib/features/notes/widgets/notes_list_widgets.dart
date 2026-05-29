part of '../screens/notes_screen.dart';

class _GroupedNotesList extends StatelessWidget {
  const _GroupedNotesList({
    required this.notes,
    required this.categories,
    required this.searchController,
    required this.query,
    required this.onSearchChanged,
    required this.onToggleFavorite,
    required this.onEdit,
    required this.onDelete,
    required this.onAttachments,
  });

  final List<Note> notes;
  final List<NoteCategory> categories;
  final TextEditingController searchController;
  final String query;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<Note> onToggleFavorite;
  final ValueChanged<Note> onEdit;
  final ValueChanged<Note> onDelete;
  final ValueChanged<Note> onAttachments;

  @override
  Widget build(BuildContext context) {
    final categoryById = {
      for (final category in categories) category.id: category,
    };
    final favoriteNotes = notes.where((note) => note.isFavorite).toList();
    final regularNotes = notes.where((note) => !note.isFavorite).toList();
    final grouped = <String?, List<Note>>{};
    for (final note in regularNotes) {
      grouped.putIfAbsent(note.categoryId, () => []).add(note);
    }

    final categoryIds = [
      ...categories
          .where((category) => grouped.containsKey(category.id))
          .map((category) => category.id),
      if (grouped.containsKey(null)) null,
    ];

    if (notes.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _NotesSearchField(
            controller: searchController,
            onChanged: onSearchChanged,
          ),
          const SizedBox(height: 48),
          _EmptyState(
            icon: Icons.search_off_outlined,
            title: 'No encontré notas',
            message: 'Prueba con otra palabra, categoría o fecha de audio.',
            actionLabel: 'Limpiar búsqueda',
            onAction: () {
              searchController.clear();
              onSearchChanged('');
            },
          ),
        ],
      );
    }

    final sectionsCount = categoryIds.length + (favoriteNotes.isEmpty ? 0 : 1);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sectionsCount + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _NotesSearchField(
              controller: searchController,
              onChanged: onSearchChanged,
            ),
          );
        }

        final sectionIndex = index - 1;
        if (favoriteNotes.isNotEmpty && sectionIndex == 0) {
          return _NotesSection(
            title: query.isEmpty ? 'Favoritas' : 'Favoritas encontradas',
            notes: favoriteNotes,
            categoryById: categoryById,
            onToggleFavorite: onToggleFavorite,
            onEdit: onEdit,
            onDelete: onDelete,
            onAttachments: onAttachments,
          );
        }

        final categoryIndex = sectionIndex - (favoriteNotes.isEmpty ? 0 : 1);
        final categoryId = categoryIds[categoryIndex];
        final categoryName = categoryId == null
            ? 'Sin categoría'
            : categoryById[categoryId]?.name ?? 'Sin categoría';
        final categoryNotes = grouped[categoryId] ?? const <Note>[];

        return _NotesSection(
          title: categoryName,
          notes: categoryNotes,
          categoryById: categoryById,
          onToggleFavorite: onToggleFavorite,
          onEdit: onEdit,
          onDelete: onDelete,
          onAttachments: onAttachments,
        );
      },
    );
  }
}

class _NotesSearchField extends StatelessWidget {
  const _NotesSearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search),
        hintText: 'Buscar notas, categorías o adjuntos',
        filled: true,
        fillColor: const Color(0xFFFFF7F8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Limpiar búsqueda',
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              ),
      ),
    );
  }
}

class _NotesSection extends StatelessWidget {
  const _NotesSection({
    required this.title,
    required this.notes,
    required this.categoryById,
    required this.onToggleFavorite,
    required this.onEdit,
    required this.onDelete,
    required this.onAttachments,
  });

  final String title;
  final List<Note> notes;
  final Map<String, NoteCategory> categoryById;
  final ValueChanged<Note> onToggleFavorite;
  final ValueChanged<Note> onEdit;
  final ValueChanged<Note> onDelete;
  final ValueChanged<Note> onAttachments;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3748),
              ),
            ),
          ),
          for (final note in notes)
            _NoteCard(
              note: note,
              categoryName: note.categoryId == null
                  ? 'Sin categoría'
                  : categoryById[note.categoryId]?.name ?? 'Sin categoría',
              onToggleFavorite: () => onToggleFavorite(note),
              onEdit: () => onEdit(note),
              onDelete: () => onDelete(note),
              onAttachments: () => onAttachments(note),
            ),
        ],
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.note,
    required this.categoryName,
    required this.onToggleFavorite,
    required this.onEdit,
    required this.onDelete,
    required this.onAttachments,
  });

  final Note note;
  final String categoryName;
  final VoidCallback onToggleFavorite;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAttachments;

  @override
  Widget build(BuildContext context) {
    return SoftFadeSlide(
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: IconButton(
            icon: AnimatedCheckIcon(
              checked: note.isFavorite,
              checkedIcon: Icons.star,
              uncheckedIcon: Icons.star_border,
            ),
            tooltip: note.isFavorite ? 'Quitar favorito' : 'Marcar favorito',
            onPressed: onToggleFavorite,
          ),
          title: Text(
            note.title,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(note.content, maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _SmallLabel(icon: Icons.folder_outlined, text: categoryName),
                  _SmallLabel(
                    icon: Icons.schedule,
                    text: 'Creada: ${_formatDate(note.createdAt)}',
                  ),
                  if (note.audioAttachments.isNotEmpty)
                    _SmallLabel(
                      icon: Icons.mic_none,
                      text: '${note.audioAttachments.length} audios',
                    ),
                  if (note.fileAttachments.isNotEmpty)
                    _SmallLabel(
                      icon: Icons.attach_file,
                      text: '${note.fileAttachments.length} archivos',
                    ),
                ],
              ),
            ],
          ),
          trailing: PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'attachments') onAttachments();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('Editar')),
              PopupMenuItem(value: 'attachments', child: Text('Adjuntos')),
              PopupMenuItem(value: 'delete', child: Text('Eliminar')),
            ],
          ),
          onTap: onAttachments,
        ),
      ),
    );
  }
}
