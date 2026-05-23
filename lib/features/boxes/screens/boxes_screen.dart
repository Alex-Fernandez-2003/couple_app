import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/box_model.dart';
import '../../../data/providers.dart';

class BoxesScreen extends ConsumerStatefulWidget {
  const BoxesScreen({super.key});

  @override
  ConsumerState<BoxesScreen> createState() => _BoxesScreenState();
}

class _BoxesScreenState extends ConsumerState<BoxesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final boxesAsync = ref.watch(boxesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cajas'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Cajas'),
            Tab(icon: Icon(Icons.bookmark_border), text: 'Plantillas'),
            Tab(icon: Icon(Icons.checklist_outlined), text: 'Materiales'),
          ],
        ),
      ),
      body: boxesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          error: error,
          onRetry: () => ref.invalidate(boxesProvider),
        ),
        data: (state) => TabBarView(
          controller: _tabController,
          children: [
            _BoxesTab(
              boxes: state.boxes,
              materialTemplates: state.materialTemplates,
              onAdd: () => _showBoxDialog(context),
              onEdit: (box) => _showBoxDialog(context, box: box),
              onDelete: (box) => _showDeleteBoxDialog(context, box),
              onAddItem: (box) => _showMaterialDialog(context, box: box),
              onInsertMaterials: (box) =>
                  _showInsertMaterialTemplatesDialog(context, box: box),
              onEditItem: (box, item) =>
                  _showMaterialDialog(context, box: box, item: item),
              onToggleItem: (box, item) => ref
                  .read(boxesProvider.notifier)
                  .toggleItemInBox(box.id, item),
              onDeleteItem: (box, index) => ref
                  .read(boxesProvider.notifier)
                  .removeItemFromBox(box.id, index),
            ),
            _TemplatesTab(
              templates: state.templates,
              materialTemplates: state.materialTemplates,
              onAdd: () => _showTemplateDialog(context),
              onEdit: (template) =>
                  _showTemplateDialog(context, template: template),
              onDelete: (template) =>
                  _showDeleteTemplateDialog(context, template),
              onUse: (template) =>
                  ref.read(boxesProvider.notifier).addBoxFromTemplate(template),
              onAddItem: (template) =>
                  _showMaterialDialog(context, template: template),
              onInsertMaterials: (template) =>
                  _showInsertMaterialTemplatesDialog(
                    context,
                    template: template,
                  ),
              onEditItem: (template, item) =>
                  _showMaterialDialog(context, template: template, item: item),
              onDeleteItem: (template, index) => ref
                  .read(boxesProvider.notifier)
                  .removeItemFromTemplate(template.id, index),
            ),
            _MaterialTemplatesTab(
              templates: state.materialTemplates,
              onAdd: () => _showMaterialTemplateDialog(context),
              onEdit: (template) =>
                  _showMaterialTemplateDialog(context, template: template),
              onDelete: (template) =>
                  _showDeleteMaterialTemplateDialog(context, template),
              onAddItem: (template) =>
                  _showMaterialDialog(context, materialTemplate: template),
              onEditItem: (template, item) => _showMaterialDialog(
                context,
                materialTemplate: template,
                item: item,
              ),
              onDeleteItem: (template, index) => ref
                  .read(boxesProvider.notifier)
                  .removeItemFromMaterialTemplate(template.id, index),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_tabController.index == 0) {
            _showBoxDialog(context);
          } else if (_tabController.index == 1) {
            _showTemplateDialog(context);
          } else {
            _showMaterialTemplateDialog(context);
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Crear'),
        backgroundColor: const Color(0xFFFD8392),
        foregroundColor: Colors.white,
      ),
    );
  }

  void _showBoxDialog(BuildContext context, {Box? box}) {
    showDialog(
      context: context,
      builder: (context) => _BoxDetailsDialog(
        title: box == null ? 'Nueva caja' : 'Editar caja',
        materialTemplates:
            ref.read(boxesProvider).value?.materialTemplates ?? const [],
        initialTitle: box?.title,
        initialDescription: box?.description,
        onSave: (values) async {
          final notifier = ref.read(boxesProvider.notifier);
          final insertedItems = values.materialTemplates
              .expand((template) => template.createItems())
              .toList();
          if (box == null) {
            await notifier.addBox(
              values.title,
              values.description,
              items: insertedItems,
            );
          } else {
            await notifier.updateBox(
              box.copyWith(
                title: values.title,
                description: values.description,
                items: [...box.items, ...insertedItems],
              ),
            );
          }
        },
      ),
    );
  }

  void _showTemplateDialog(BuildContext context, {BoxTemplate? template}) {
    showDialog(
      context: context,
      builder: (context) => _BoxDetailsDialog(
        title: template == null ? 'Nueva plantilla' : 'Editar plantilla',
        materialTemplates:
            ref.read(boxesProvider).value?.materialTemplates ?? const [],
        initialTitle: template?.title,
        initialDescription: template?.description,
        onSave: (values) async {
          final notifier = ref.read(boxesProvider.notifier);
          final insertedItems = values.materialTemplates
              .expand((template) => template.createItems())
              .toList();
          if (template == null) {
            await notifier.addTemplate(
              values.title,
              values.description,
              items: insertedItems,
            );
          } else {
            await notifier.updateTemplate(
              template.copyWith(
                title: values.title,
                description: values.description,
                items: [...template.items, ...insertedItems],
              ),
            );
          }
        },
      ),
    );
  }

  void _showMaterialDialog(
    BuildContext context, {
    Box? box,
    BoxTemplate? template,
    MaterialTemplate? materialTemplate,
    MaterialItem? item,
  }) {
    showDialog(
      context: context,
      builder: (context) => _MaterialDialog(
        title: item == null ? 'Nuevo material' : 'Editar material',
        initialTitle: item?.title,
        onSave: (title) async {
          final notifier = ref.read(boxesProvider.notifier);
          if (box != null) {
            if (item == null) {
              await notifier.addItemToBox(box.id, title);
            } else {
              await notifier.updateItemInBox(
                box.id,
                item.copyWith(title: title),
              );
            }
          }

          if (template != null) {
            if (item == null) {
              await notifier.addItemToTemplate(template.id, title);
            } else {
              await notifier.updateItemInTemplate(
                template.id,
                item.copyWith(title: title),
              );
            }
          }

          if (materialTemplate != null) {
            if (item == null) {
              await notifier.addItemToMaterialTemplate(
                materialTemplate.id,
                title,
              );
            } else {
              await notifier.updateItemInMaterialTemplate(
                materialTemplate.id,
                item.copyWith(title: title),
              );
            }
          }
        },
      ),
    );
  }

  void _showMaterialTemplateDialog(
    BuildContext context, {
    MaterialTemplate? template,
  }) {
    showDialog(
      context: context,
      builder: (context) => _MaterialTemplateDialog(
        title: template == null
            ? 'Nueva plantilla de materiales'
            : 'Editar plantilla de materiales',
        initialTitle: template?.title,
        onSave: (title) async {
          final notifier = ref.read(boxesProvider.notifier);
          if (template == null) {
            await notifier.addMaterialTemplate(title);
          } else {
            await notifier.updateMaterialTemplate(
              template.copyWith(title: title),
            );
          }
        },
      ),
    );
  }

  void _showInsertMaterialTemplatesDialog(
    BuildContext context, {
    Box? box,
    BoxTemplate? template,
  }) {
    final templates =
        ref.read(boxesProvider).value?.materialTemplates ?? const [];
    showDialog(
      context: context,
      builder: (context) => _InsertMaterialTemplatesDialog(
        templates: templates,
        onInsert: (selected) async {
          final notifier = ref.read(boxesProvider.notifier);
          if (box != null) {
            await notifier.insertMaterialTemplatesIntoBox(box.id, selected);
          }
          if (template != null) {
            await notifier.insertMaterialTemplatesIntoBoxTemplate(
              template.id,
              selected,
            );
          }
        },
      ),
    );
  }

  void _showDeleteBoxDialog(BuildContext context, Box box) {
    _showConfirmDelete(
      context,
      title: 'Eliminar caja',
      message: '¿Eliminar "${box.title}" y sus materiales?',
      onConfirm: () => ref.read(boxesProvider.notifier).deleteBox(box.id),
    );
  }

  void _showDeleteTemplateDialog(BuildContext context, BoxTemplate template) {
    _showConfirmDelete(
      context,
      title: 'Eliminar plantilla',
      message: '¿Eliminar la plantilla "${template.title}"?',
      onConfirm: () =>
          ref.read(boxesProvider.notifier).deleteTemplate(template.id),
    );
  }

  void _showDeleteMaterialTemplateDialog(
    BuildContext context,
    MaterialTemplate template,
  ) {
    _showConfirmDelete(
      context,
      title: 'Eliminar plantilla de materiales',
      message: '¿Eliminar "${template.title}"?',
      onConfirm: () =>
          ref.read(boxesProvider.notifier).deleteMaterialTemplate(template.id),
    );
  }
}

class _BoxesTab extends StatelessWidget {
  const _BoxesTab({
    required this.boxes,
    required this.materialTemplates,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onAddItem,
    required this.onInsertMaterials,
    required this.onEditItem,
    required this.onToggleItem,
    required this.onDeleteItem,
  });

  final List<Box> boxes;
  final List<MaterialTemplate> materialTemplates;
  final VoidCallback onAdd;
  final ValueChanged<Box> onEdit;
  final ValueChanged<Box> onDelete;
  final ValueChanged<Box> onAddItem;
  final ValueChanged<Box> onInsertMaterials;
  final void Function(Box box, MaterialItem item) onEditItem;
  final void Function(Box box, MaterialItem item) onToggleItem;
  final void Function(Box box, int index) onDeleteItem;

  @override
  Widget build(BuildContext context) {
    if (boxes.isEmpty) {
      return _EmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'Tus cajas están listas para nacer',
        message: 'Crea una caja y arma su checklist de materiales.',
        actionLabel: 'Crear caja',
        onAction: onAdd,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: boxes.length,
      itemBuilder: (context, index) {
        final box = boxes[index];
        return _BoxCard(
          title: box.title,
          description: box.description,
          items: box.items,
          createdAt: box.createdAt,
          emptyMessage: 'Esta caja está vacía. Agrega tu primer material.',
          onEdit: () => onEdit(box),
          onDelete: () => onDelete(box),
          onAddItem: () => onAddItem(box),
          onInsertMaterials: materialTemplates.isEmpty
              ? null
              : () => onInsertMaterials(box),
          onEditItem: (item) => onEditItem(box, item),
          onToggleItem: (item) => onToggleItem(box, item),
          onDeleteItem: (itemIndex) => onDeleteItem(box, itemIndex),
        );
      },
    );
  }
}

class _TemplatesTab extends StatelessWidget {
  const _TemplatesTab({
    required this.templates,
    required this.materialTemplates,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onUse,
    required this.onAddItem,
    required this.onInsertMaterials,
    required this.onEditItem,
    required this.onDeleteItem,
  });

  final List<BoxTemplate> templates;
  final List<MaterialTemplate> materialTemplates;
  final VoidCallback onAdd;
  final ValueChanged<BoxTemplate> onEdit;
  final ValueChanged<BoxTemplate> onDelete;
  final ValueChanged<BoxTemplate> onUse;
  final ValueChanged<BoxTemplate> onAddItem;
  final ValueChanged<BoxTemplate> onInsertMaterials;
  final void Function(BoxTemplate template, MaterialItem item) onEditItem;
  final void Function(BoxTemplate template, int index) onDeleteItem;

  @override
  Widget build(BuildContext context) {
    if (templates.isEmpty) {
      return _EmptyState(
        icon: Icons.bookmark_border,
        title: 'Aún no hay plantillas',
        message: 'Guarda listas de materiales que quieras reutilizar.',
        actionLabel: 'Crear plantilla',
        onAction: onAdd,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: templates.length,
      itemBuilder: (context, index) {
        final template = templates[index];
        return _BoxCard(
          title: template.title,
          description: template.description,
          items: template.items,
          createdAt: template.createdAt,
          emptyMessage: 'Agrega materiales para completar esta plantilla.',
          onEdit: () => onEdit(template),
          onDelete: () => onDelete(template),
          onUse: () => onUse(template),
          onAddItem: () => onAddItem(template),
          onInsertMaterials: materialTemplates.isEmpty
              ? null
              : () => onInsertMaterials(template),
          onEditItem: (item) => onEditItem(template, item),
          onDeleteItem: (itemIndex) => onDeleteItem(template, itemIndex),
        );
      },
    );
  }
}

class _MaterialTemplatesTab extends StatelessWidget {
  const _MaterialTemplatesTab({
    required this.templates,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onAddItem,
    required this.onEditItem,
    required this.onDeleteItem,
  });

  final List<MaterialTemplate> templates;
  final VoidCallback onAdd;
  final ValueChanged<MaterialTemplate> onEdit;
  final ValueChanged<MaterialTemplate> onDelete;
  final ValueChanged<MaterialTemplate> onAddItem;
  final void Function(MaterialTemplate template, MaterialItem item) onEditItem;
  final void Function(MaterialTemplate template, int index) onDeleteItem;

  @override
  Widget build(BuildContext context) {
    if (templates.isEmpty) {
      return _EmptyState(
        icon: Icons.checklist_outlined,
        title: 'Plantillas de materiales',
        message: 'Crea grupos reutilizables para armar cajas más rápido.',
        actionLabel: 'Crear plantilla',
        onAction: onAdd,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: templates.length,
      itemBuilder: (context, index) {
        final template = templates[index];
        return _BoxCard(
          title: template.title,
          description: 'Grupo reutilizable de materiales',
          items: template.items,
          createdAt: template.createdAt,
          emptyMessage: 'Agrega materiales para reutilizar este grupo.',
          onEdit: () => onEdit(template),
          onDelete: () => onDelete(template),
          onAddItem: () => onAddItem(template),
          onEditItem: (item) => onEditItem(template, item),
          onDeleteItem: (itemIndex) => onDeleteItem(template, itemIndex),
        );
      },
    );
  }
}

class _BoxCard extends StatelessWidget {
  const _BoxCard({
    required this.title,
    required this.description,
    required this.items,
    required this.createdAt,
    required this.emptyMessage,
    required this.onEdit,
    required this.onDelete,
    required this.onAddItem,
    required this.onEditItem,
    required this.onDeleteItem,
    this.onToggleItem,
    this.onUse,
    this.onInsertMaterials,
  });

  final String title;
  final String description;
  final List<MaterialItem> items;
  final DateTime createdAt;
  final String emptyMessage;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAddItem;
  final ValueChanged<MaterialItem> onEditItem;
  final void Function(int index) onDeleteItem;
  final ValueChanged<MaterialItem>? onToggleItem;
  final VoidCallback? onUse;
  final VoidCallback? onInsertMaterials;

  @override
  Widget build(BuildContext context) {
    final completedCount = items.where((item) => item.completed).length;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(description),
            const SizedBox(height: 4),
            Text(
              onToggleItem == null
                  ? '${items.length} materiales • Creada: ${_formatDate(createdAt)}'
                  : '$completedCount/${items.length} listos • Creada: ${_formatDate(createdAt)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'use') onUse?.call();
            if (value == 'insertMaterials') onInsertMaterials?.call();
            if (value == 'edit') onEdit();
            if (value == 'delete') onDelete();
          },
          itemBuilder: (context) => [
            if (onUse != null)
              const PopupMenuItem(value: 'use', child: Text('Crear caja')),
            if (onInsertMaterials != null)
              const PopupMenuItem(
                value: 'insertMaterials',
                child: Text('Insertar materiales'),
              ),
            const PopupMenuItem(value: 'edit', child: Text('Editar')),
            const PopupMenuItem(value: 'delete', child: Text('Eliminar')),
          ],
        ),
        children: [
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                emptyMessage,
                style: const TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            )
          else
            for (final entry in items.asMap().entries)
              _MaterialTile(
                item: entry.value,
                showCheckbox: onToggleItem != null,
                onToggle: onToggleItem == null
                    ? null
                    : () => onToggleItem!(entry.value),
                onEdit: () => onEditItem(entry.value),
                onDelete: () => onDeleteItem(entry.key),
              ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton.icon(
                  onPressed: onAddItem,
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar material'),
                ),
                if (onInsertMaterials != null)
                  TextButton.icon(
                    onPressed: onInsertMaterials,
                    icon: const Icon(Icons.playlist_add_check),
                    label: const Text('Insertar plantilla'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MaterialTile extends StatelessWidget {
  const _MaterialTile({
    required this.item,
    required this.showCheckbox,
    required this.onEdit,
    required this.onDelete,
    this.onToggle,
  });

  final MaterialItem item;
  final bool showCheckbox;
  final VoidCallback? onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: showCheckbox
          ? Checkbox(
              value: item.completed,
              onChanged: (_) => onToggle?.call(),
              activeColor: const Color(0xFFFD8392),
            )
          : const Icon(Icons.checklist, size: 20, color: Color(0xFFFD8392)),
      title: Text(
        item.title,
        style: TextStyle(
          decoration: item.completed ? TextDecoration.lineThrough : null,
          color: item.completed ? Colors.grey : null,
        ),
      ),
      trailing: Wrap(
        spacing: 4,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            tooltip: 'Editar material',
            onPressed: onEdit,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            tooltip: 'Eliminar material',
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _BoxDetailsDialog extends StatefulWidget {
  const _BoxDetailsDialog({
    required this.title,
    required this.materialTemplates,
    required this.onSave,
    this.initialTitle,
    this.initialDescription,
  });

  final String title;
  final List<MaterialTemplate> materialTemplates;
  final String? initialTitle;
  final String? initialDescription;
  final Future<void> Function(_BoxDetailsValues values) onSave;

  @override
  State<_BoxDetailsDialog> createState() => _BoxDetailsDialogState();
}

class _BoxDetailsDialogState extends State<_BoxDetailsDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  final Set<String> _selectedTemplateIds = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _descriptionController = TextEditingController(
      text: widget.initialDescription,
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    if (title.isEmpty) return;

    setState(() => _saving = true);
    try {
      final selectedTemplates = widget.materialTemplates
          .where((template) => _selectedTemplateIds.contains(template.id))
          .toList();
      await widget.onSave(
        _BoxDetailsValues(
          title: title,
          description: description,
          materialTemplates: selectedTemplates,
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
      if (mounted) setState(() => _saving = false);
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
                labelText: 'Nombre',
                hintText: 'Materiales de manualidades',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Descripción opcional',
                hintText: '¿Para qué sirve esta caja?',
              ),
              maxLines: 2,
            ),
            if (widget.materialTemplates.isNotEmpty) ...[
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Insertar materiales',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              const SizedBox(height: 8),
              ...widget.materialTemplates.map(
                (template) => CheckboxListTile(
                  value: _selectedTemplateIds.contains(template.id),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(template.title),
                  subtitle: Text('${template.items.length} materiales'),
                  activeColor: const Color(0xFFFD8392),
                  onChanged: (selected) {
                    setState(() {
                      if (selected == true) {
                        _selectedTemplateIds.add(template.id);
                      } else {
                        _selectedTemplateIds.remove(template.id);
                      }
                    });
                  },
                ),
              ),
            ],
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
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

class _MaterialDialog extends StatefulWidget {
  const _MaterialDialog({
    required this.title,
    required this.onSave,
    this.initialTitle,
  });

  final String title;
  final String? initialTitle;
  final Future<void> Function(String title) onSave;

  @override
  State<_MaterialDialog> createState() => _MaterialDialogState();
}

class _MaterialTemplateDialog extends StatefulWidget {
  const _MaterialTemplateDialog({
    required this.title,
    required this.onSave,
    this.initialTitle,
  });

  final String title;
  final String? initialTitle;
  final Future<void> Function(String title) onSave;

  @override
  State<_MaterialTemplateDialog> createState() =>
      _MaterialTemplateDialogState();
}

class _MaterialTemplateDialogState extends State<_MaterialTemplateDialog> {
  late final TextEditingController _controller;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialTitle);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _controller.text.trim();
    if (title.isEmpty) return;

    setState(() => _saving = true);
    try {
      await widget.onSave(title);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          labelText: 'Nombre',
          hintText: 'Odontología básica, viaje, manualidades...',
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

class _InsertMaterialTemplatesDialog extends StatefulWidget {
  const _InsertMaterialTemplatesDialog({
    required this.templates,
    required this.onInsert,
  });

  final List<MaterialTemplate> templates;
  final Future<void> Function(List<MaterialTemplate> templates) onInsert;

  @override
  State<_InsertMaterialTemplatesDialog> createState() =>
      _InsertMaterialTemplatesDialogState();
}

class _InsertMaterialTemplatesDialogState
    extends State<_InsertMaterialTemplatesDialog> {
  final Set<String> _selectedIds = {};
  bool _saving = false;

  Future<void> _insert() async {
    final selected = widget.templates
        .where((template) => _selectedIds.contains(template.id))
        .toList();
    if (selected.isEmpty) return;

    setState(() => _saving = true);
    try {
      await widget.onInsert(selected);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Insertar materiales'),
      content: SizedBox(
        width: double.maxFinite,
        child: widget.templates.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Aún no hay plantillas de materiales.',
                  textAlign: TextAlign.center,
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                itemCount: widget.templates.length,
                itemBuilder: (context, index) {
                  final template = widget.templates[index];
                  return CheckboxListTile(
                    value: _selectedIds.contains(template.id),
                    contentPadding: EdgeInsets.zero,
                    title: Text(template.title),
                    subtitle: Text('${template.items.length} materiales'),
                    activeColor: const Color(0xFFFD8392),
                    onChanged: (selected) {
                      setState(() {
                        if (selected == true) {
                          _selectedIds.add(template.id);
                        } else {
                          _selectedIds.remove(template.id);
                        }
                      });
                    },
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _saving || _selectedIds.isEmpty ? null : _insert,
          child: const Text('Insertar'),
        ),
      ],
    );
  }
}

class _MaterialDialogState extends State<_MaterialDialog> {
  late final TextEditingController _controller;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialTitle);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _controller.text.trim();
    if (title.isEmpty) return;

    setState(() => _saving = true);
    try {
      await widget.onSave(title);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          labelText: 'Material',
          hintText: 'Cinta, marcador, tijeras...',
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

class _BoxDetailsValues {
  final String title;
  final String description;
  final List<MaterialTemplate> materialTemplates;

  const _BoxDetailsValues({
    required this.title,
    required this.description,
    required this.materialTemplates,
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

void _showConfirmDelete(
  BuildContext context, {
  required String title,
  required String message,
  required Future<void> Function() onConfirm,
}) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () async {
            await onConfirm();
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

String _formatDate(DateTime date) {
  final now = DateTime.now();
  final difference = now.difference(date);

  if (difference.inDays == 0) {
    return 'hoy';
  } else if (difference.inDays == 1) {
    return 'ayer';
  } else if (difference.inDays < 7) {
    return 'hace ${difference.inDays} días';
  } else {
    return '${date.day}/${date.month}/${date.year}';
  }
}
