part of '../screens/notes_screen.dart';

class _NoteDialog extends StatefulWidget {
  const _NoteDialog({
    required this.title,
    required this.categories,
    required this.onSave,
    this.initialTitle,
    this.initialContent,
    this.initialCategoryId,
  });

  final String title;
  final List<NoteCategory> categories;
  final String? initialTitle;
  final String? initialContent;
  final String? initialCategoryId;
  final Future<void> Function(_NoteValues values) onSave;

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  String? _categoryId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _contentController = TextEditingController(text: widget.initialContent);
    _categoryId = widget.initialCategoryId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (title.isEmpty) return;

    setState(() {
      _saving = true;
    });

    try {
      await widget.onSave(
        _NoteValues(title: title, content: content, categoryId: _categoryId),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $error')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Título',
                hintText: 'Título de la nota',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _contentController,
              decoration: const InputDecoration(
                labelText: 'Contenido opcional',
                hintText: 'Escribe tu nota aquí...',
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              initialValue: _categoryId,
              decoration: const InputDecoration(labelText: 'Categoría'),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Sin categoría'),
                ),
                for (final category in widget.categories)
                  DropdownMenuItem<String?>(
                    value: category.id,
                    child: Text(category.name),
                  ),
              ],
              onChanged: (value) {
                setState(() {
                  _categoryId = value;
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}

class _CategoriesDialog extends ConsumerWidget {
  const _CategoriesDialog({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef widgetRef) {
    final state = ref.watch(notesProvider).value ?? const NotesState.empty();

    return AlertDialog(
      title: const Text('Categorías'),
      content: SizedBox(
        width: double.maxFinite,
        child: state.categories.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Aún no tienes categorías. Crea una para ordenar tus notas.',
                  textAlign: TextAlign.center,
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                itemCount: state.categories.length,
                itemBuilder: (context, index) {
                  final category = state.categories[index];
                  final count = state.notes
                      .where((note) => note.categoryId == category.id)
                      .length;
                  return ListTile(
                    title: Text(category.name),
                    subtitle: Text('$count notas'),
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Editar categoría',
                          onPressed: () =>
                              _showCategoryNameDialog(context, ref, category),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Eliminar categoría',
                          onPressed: () => _showDeleteCategoryDialog(
                            context,
                            ref,
                            category,
                            count,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () => _showCategoryNameDialog(context, ref),
          icon: const Icon(Icons.add),
          label: const Text('Crear'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}

void _showCategoryNameDialog(
  BuildContext context,
  WidgetRef ref, [
  NoteCategory? category,
]) {
  showDialog(
    context: context,
    builder: (context) => _CategoryNameDialog(
      initialName: category?.name,
      title: category == null ? 'Nueva categoría' : 'Editar categoría',
      onSave: (name) async {
        final notifier = ref.read(notesProvider.notifier);
        if (category == null) {
          await notifier.addCategory(name);
        } else {
          await notifier.updateCategory(category.copyWith(name: name));
        }
      },
    ),
  );
}

void _showDeleteCategoryDialog(
  BuildContext context,
  WidgetRef ref,
  NoteCategory category,
  int noteCount,
) {
  DeleteCategoryMode mode = DeleteCategoryMode.moveToUncategorized;
  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text('Eliminar ${category.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Esta categoría tiene $noteCount notas.'),
            const SizedBox(height: 12),
            _DeleteModeTile(
              selected: mode == DeleteCategoryMode.moveToUncategorized,
              title: const Text('Mover notas a Sin categoría'),
              onTap: () =>
                  setState(() => mode = DeleteCategoryMode.moveToUncategorized),
            ),
            _DeleteModeTile(
              selected: mode == DeleteCategoryMode.deleteNotes,
              title: const Text('Eliminar notas asociadas'),
              onTap: () =>
                  setState(() => mode = DeleteCategoryMode.deleteNotes),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              await ref
                  .read(notesProvider.notifier)
                  .deleteCategory(category.id, mode: mode);
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
    ),
  );
}

class _DeleteModeTile extends StatelessWidget {
  const _DeleteModeTile({
    required this.selected,
    required this.title,
    required this.onTap,
  });

  final bool selected;
  final Widget title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        selected ? Icons.check_circle : Icons.radio_button_unchecked,
        color: selected
            ? colors.primary
            : colors.onSurface.withValues(alpha: 0.62),
      ),
      title: title,
      onTap: onTap,
    );
  }
}

class _CategoryNameDialog extends StatefulWidget {
  const _CategoryNameDialog({
    required this.title,
    required this.onSave,
    this.initialName,
  });

  final String title;
  final String? initialName;
  final Future<void> Function(String name) onSave;

  @override
  State<_CategoryNameDialog> createState() => _CategoryNameDialogState();
}

class _CategoryNameDialogState extends State<_CategoryNameDialog> {
  late final TextEditingController _nameController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() {
      _saving = true;
    });

    try {
      await widget.onSave(name);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $error')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _nameController,
        decoration: const InputDecoration(
          labelText: 'Nombre',
          hintText: 'Materia, viaje, ideas...',
        ),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

class _NoteValues {
  final String title;
  final String content;
  final String? categoryId;

  const _NoteValues({
    required this.title,
    required this.content,
    this.categoryId,
  });
}
