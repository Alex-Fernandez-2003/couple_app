import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/shopping_item.dart';
import '../../../data/providers.dart';

class ShoppingScreen extends ConsumerStatefulWidget {
  const ShoppingScreen({super.key});

  @override
  ConsumerState<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends ConsumerState<ShoppingScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shoppingState = ref.watch(shoppingProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Compras'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_outlined),
            tooltip: 'Gestionar categorías',
            onPressed: () => _showCategoriesDialog(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.shopping_cart_outlined), text: 'Lista'),
            Tab(icon: Icon(Icons.bookmark_border), text: 'Plantillas'),
          ],
        ),
      ),
      body: shoppingState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          error: error,
          onRetry: () => ref.read(shoppingProvider.notifier).refresh(),
        ),
        data: (state) => TabBarView(
          controller: _tabController,
          children: [
            _ItemsTab(
              items: state.items,
              categories: state.categories,
              onAdd: () => _showItemDialog(context),
              onEdit: (item) => _showItemDialog(context, item: item),
              onToggle: (item) =>
                  ref.read(shoppingProvider.notifier).toggleCompletion(item),
              onDelete: (item) =>
                  ref.read(shoppingProvider.notifier).removeItem(item),
            ),
            _TemplatesTab(
              templates: state.templates,
              onAdd: () => _showTemplateDialog(context),
              onEdit: (template) =>
                  _showTemplateDialog(context, template: template),
              onUse: (template) => ref
                  .read(shoppingProvider.notifier)
                  .addItemFromTemplate(template),
              onDelete: (template) =>
                  ref.read(shoppingProvider.notifier).removeTemplate(template),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_tabController.index == 0) {
            _showItemDialog(context);
          } else {
            _showTemplateDialog(context);
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Agregar'),
        backgroundColor: const Color(0xFFFD8392),
        foregroundColor: Colors.white,
      ),
    );
  }

  void _showItemDialog(BuildContext context, {ShoppingItem? item}) {
    showDialog(
      context: context,
      builder: (context) => _ShoppingEntryDialog(
        title: item == null ? 'Nueva compra' : 'Editar compra',
        initialTitle: item?.title,
        initialNotes: item?.notes,
        initialPrice: item?.price,
        initialCategoryId: item?.categoryId,
        categories: ref.read(shoppingProvider).value?.categories ?? const [],
        onSave: (values) async {
          final notifier = ref.read(shoppingProvider.notifier);
          if (item == null) {
            await notifier.addItem(
              values.title,
              notes: values.notes,
              price: values.price,
              categoryId: values.categoryId,
            );
          } else {
            await notifier.updateItem(
              item.copyWith(
                title: values.title,
                notes: values.notes,
                price: values.price,
                categoryId: values.categoryId,
                clearCategory: values.categoryId == null,
              ),
            );
          }
        },
      ),
    );
  }

  void _showTemplateDialog(BuildContext context, {ShoppingTemplate? template}) {
    showDialog(
      context: context,
      builder: (context) => _ShoppingEntryDialog(
        title: template == null ? 'Nueva plantilla' : 'Editar plantilla',
        initialTitle: template?.title,
        initialNotes: template?.notes,
        initialPrice: template?.price,
        initialCategory: template?.category,
        categories: const [],
        onSave: (values) async {
          final notifier = ref.read(shoppingProvider.notifier);
          if (template == null) {
            await notifier.addTemplate(
              values.title,
              notes: values.notes,
              price: values.price,
              category: values.legacyCategory,
            );
          } else {
            await notifier.updateTemplate(
              template.copyWith(
                title: values.title,
                notes: values.notes,
                price: values.price,
                category: values.legacyCategory,
              ),
            );
          }
        },
      ),
    );
  }

  void _showCategoriesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _ShoppingCategoriesDialog(ref: ref),
    );
  }
}

class _ItemsTab extends StatelessWidget {
  const _ItemsTab({
    required this.items,
    required this.categories,
    required this.onAdd,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  final List<ShoppingItem> items;
  final List<ShoppingCategory> categories;
  final VoidCallback onAdd;
  final ValueChanged<ShoppingItem> onEdit;
  final ValueChanged<ShoppingItem> onToggle;
  final ValueChanged<ShoppingItem> onDelete;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _EmptyState(
        icon: Icons.shopping_cart_outlined,
        title: 'Tu lista está tranquila',
        message: 'Agrega lo que necesitas comprar y lo tendrás a mano.',
        actionLabel: 'Agregar compra',
        onAction: onAdd,
      );
    }

    final categoryById = {
      for (final category in categories) category.id: category,
    };
    final grouped = <String?, List<ShoppingItem>>{};
    for (final item in items) {
      grouped.putIfAbsent(item.categoryId, () => []).add(item);
    }
    final categoryIds = [
      ...categories
          .where((category) => grouped.containsKey(category.id))
          .map((category) => category.id),
      if (grouped.containsKey(null)) null,
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: categoryIds.length,
      itemBuilder: (context, index) {
        final categoryId = categoryIds[index];
        final categoryName = categoryId == null
            ? 'Sin categoría'
            : categoryById[categoryId]?.name ?? 'Sin categoría';
        final categoryItems = grouped[categoryId] ?? const <ShoppingItem>[];

        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  categoryName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748),
                  ),
                ),
              ),
              for (final item in categoryItems)
                _ShoppingItemCard(
                  item: item,
                  categoryName: item.categoryId == null ? item.category : null,
                  onToggle: () => onToggle(item),
                  onEdit: () => onEdit(item),
                  onDelete: () => onDelete(item),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _TemplatesTab extends StatelessWidget {
  const _TemplatesTab({
    required this.templates,
    required this.onAdd,
    required this.onEdit,
    required this.onUse,
    required this.onDelete,
  });

  final List<ShoppingTemplate> templates;
  final VoidCallback onAdd;
  final ValueChanged<ShoppingTemplate> onEdit;
  final ValueChanged<ShoppingTemplate> onUse;
  final ValueChanged<ShoppingTemplate> onDelete;

  @override
  Widget build(BuildContext context) {
    if (templates.isEmpty) {
      return _EmptyState(
        icon: Icons.bookmark_border,
        title: 'Aún no hay plantillas',
        message: 'Guarda compras frecuentes para agregarlas rápido después.',
        actionLabel: 'Crear plantilla',
        onAction: onAdd,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: templates.length,
      itemBuilder: (context, index) {
        final template = templates[index];
        return _ShoppingTemplateCard(
          template: template,
          onUse: () => onUse(template),
          onEdit: () => onEdit(template),
          onDelete: () => onDelete(template),
        );
      },
    );
  }
}

class _ShoppingItemCard extends StatelessWidget {
  const _ShoppingItemCard({
    required this.item,
    this.categoryName,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final ShoppingItem item;
  final String? categoryName;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Checkbox(
          value: item.completed,
          onChanged: (_) => onToggle(),
          activeColor: const Color(0xFFFD8392),
        ),
        title: Text(
          item.title,
          style: TextStyle(
            decoration: item.completed ? TextDecoration.lineThrough : null,
            color: item.completed ? Colors.grey : null,
          ),
        ),
        subtitle: _ShoppingMetadata(
          notes: item.notes,
          price: item.price,
          category: categoryName,
        ),
        trailing: Wrap(
          spacing: 4,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Editar compra',
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Eliminar compra',
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _ShoppingTemplateCard extends StatelessWidget {
  const _ShoppingTemplateCard({
    required this.template,
    required this.onUse,
    required this.onEdit,
    required this.onDelete,
  });

  final ShoppingTemplate template;
  final VoidCallback onUse;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.bookmark_border, color: Color(0xFFFD8392)),
        title: Text(template.title),
        subtitle: _ShoppingMetadata(
          notes: template.notes,
          price: template.price,
          category: template.category,
        ),
        trailing: Wrap(
          spacing: 4,
          children: [
            IconButton(
              icon: const Icon(Icons.add_shopping_cart),
              tooltip: 'Crear compra',
              onPressed: onUse,
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Editar plantilla',
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Eliminar plantilla',
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _ShoppingMetadata extends StatelessWidget {
  const _ShoppingMetadata({this.notes, this.price, this.category});

  final String? notes;
  final double? price;
  final String? category;

  @override
  Widget build(BuildContext context) {
    final lines = [
      if (notes != null && notes!.isNotEmpty) notes!,
      if (price != null) 'Precio: \$${price!.toStringAsFixed(2)}',
      if (category != null && category!.isNotEmpty) 'Categoría: $category',
    ];

    if (lines.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: lines.map((line) => Text(line)).toList(),
      ),
    );
  }
}

class _ShoppingCategoriesDialog extends ConsumerWidget {
  const _ShoppingCategoriesDialog({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef widgetRef) {
    final state =
        ref.watch(shoppingProvider).value ?? const ShoppingState.empty();

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
                            ref,
                            category,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Eliminar categoría',
                          onPressed: () => _showDeleteShoppingCategoryDialog(
                            context,
                            ref,
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
          onPressed: () => _showShoppingCategoryNameDialog(context, ref),
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
    this.initialCategory,
    this.initialCategoryId,
    this.categories = const [],
  });

  final String title;
  final String? initialTitle;
  final String? initialNotes;
  final double? initialPrice;
  final String? initialCategory;
  final String? initialCategoryId;
  final List<ShoppingCategory> categories;
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
    _categoryController = TextEditingController(text: widget.initialCategory);
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
            if (widget.categories.isEmpty)
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFFD8392).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(icon, size: 64, color: const Color(0xFFFD8392)),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF718096),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add),
              label: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: $error', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}

String? _emptyToNull(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

double? _emptyToDouble(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : double.tryParse(trimmed);
}
