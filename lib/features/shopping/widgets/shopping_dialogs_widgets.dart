part of '../screens/shopping_screen.dart';

class _ShoppingCategoriesDialog extends ConsumerWidget {
  const _ShoppingCategoriesDialog();

  @override
  Widget build(BuildContext context, WidgetRef widgetRef) {
    final state =
        widgetRef.watch(shoppingProvider).value ?? const ShoppingState.empty();

    return AlertDialog(
      title: const Text('Categorías'),
      content: SizedBox(
        width: double.maxFinite,
        child: state.categories.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Aún no tienes categorías. Crea una para ordenar tus compras.',
                  textAlign: TextAlign.center,
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                itemCount: state.categories.length,
                itemBuilder: (context, index) {
                  final category = state.categories[index];
                  final count = state.items
                      .where((item) => item.categoryId == category.id)
                      .length;
                  return ListTile(
                    title: Text(category.name),
                    subtitle: Text('$count compras'),
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Editar categoría',
                          onPressed: () => _showShoppingCategoryNameDialog(
                            context,
                            widgetRef,
                            category,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Eliminar categoría',
                          onPressed: () => _showDeleteShoppingCategoryDialog(
                            context,
                            widgetRef,
                            category,
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
          onPressed: () => _showShoppingCategoryNameDialog(context, widgetRef),
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

void _showShoppingCategoryNameDialog(
  BuildContext context,
  WidgetRef ref, [
  ShoppingCategory? category,
]) {
  showDialog(
    context: context,
    builder: (context) => _ShoppingCategoryNameDialog(
      initialName: category?.name,
      title: category == null ? 'Nueva categoría' : 'Editar categoría',
      onSave: (name) async {
        final notifier = ref.read(shoppingProvider.notifier);
        if (category == null) {
          await notifier.addCategory(name);
        } else {
          await notifier.updateCategory(category.copyWith(name: name));
        }
      },
    ),
  );
}

void _showDeleteShoppingCategoryDialog(
  BuildContext context,
  WidgetRef ref,
  ShoppingCategory category,
) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Eliminar ${category.name}'),
      content: const Text(
        'Las compras de esta categoría se moverán a Sin categoría.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () async {
            await ref
                .read(shoppingProvider.notifier)
                .deleteCategory(category.id);
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

class _ShoppingCategoryNameDialog extends StatefulWidget {
  const _ShoppingCategoryNameDialog({
    required this.title,
    required this.onSave,
    this.initialName,
  });

  final String title;
  final String? initialName;
  final Future<void> Function(String name) onSave;

  @override
  State<_ShoppingCategoryNameDialog> createState() =>
      _ShoppingCategoryNameDialogState();
}

class _ShoppingCategoryNameDialogState
    extends State<_ShoppingCategoryNameDialog> {
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
          hintText: 'Despensa, limpieza, farmacia...',
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

class _ShoppingEntryDialog extends StatefulWidget {
  const _ShoppingEntryDialog({
    required this.title,
    required this.onSave,
    this.initialTitle,
    this.initialNotes,
    this.initialPrice,
    this.initialCategoryId,
    this.categories = const [],
    this.forceCategorySelector = false,
  });

  final String title;
  final String? initialTitle;
  final String? initialNotes;
  final double? initialPrice;
  final String? initialCategoryId;
  final List<ShoppingCategory> categories;
  final bool forceCategorySelector;
  final Future<void> Function(_ShoppingEntryValues values) onSave;

  @override
  State<_ShoppingEntryDialog> createState() => _ShoppingEntryDialogState();
}

class _ShoppingEntryDialogState extends State<_ShoppingEntryDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  late final TextEditingController _priceController;
  late final TextEditingController _categoryController;
  String? _categoryId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _notesController = TextEditingController(text: widget.initialNotes);
    _priceController = TextEditingController(
      text: widget.initialPrice?.toStringAsFixed(2),
    );
    _categoryController = TextEditingController();
    _categoryId = widget.initialCategoryId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _priceController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    setState(() {
      _saving = true;
    });

    try {
      await widget.onSave(
        _ShoppingEntryValues(
          title: title,
          notes: _emptyToNull(_notesController.text),
          price: _emptyToDouble(_priceController.text),
          categoryId: _categoryId,
          legacyCategory: _emptyToNull(_categoryController.text),
        ),
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
                labelText: 'Producto',
                hintText: 'Pan, café, arroz...',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notas (opcional)',
                hintText: 'Marca, cantidad, tienda...',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _priceController,
              decoration: const InputDecoration(
                labelText: 'Precio estimado (opcional)',
                hintText: '0.00',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 16),
            if (widget.categories.isEmpty && !widget.forceCategorySelector)
              TextField(
                controller: _categoryController,
                decoration: const InputDecoration(
                  labelText: 'Categoría (opcional)',
                  hintText: 'Verduras, limpieza, despensa...',
                ),
              )
            else
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

class _ShoppingEntryValues {
  final String title;
  final String? notes;
  final double? price;
  final String? categoryId;
  final String? legacyCategory;

  const _ShoppingEntryValues({
    required this.title,
    this.notes,
    this.price,
    this.categoryId,
    this.legacyCategory,
  });
}
