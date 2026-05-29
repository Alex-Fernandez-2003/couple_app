part of '../screens/boxes_screen.dart';

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
          description: _materialTemplateKindLabel(template),
          items: template.items,
          createdAt: template.createdAt,
          emptyMessage: 'Agrega materiales para reutilizar este grupo.',
          onEdit: () => onEdit(template),
          onDelete: () => onDelete(template),
          showAddItem:
              template.kind == MaterialTemplateKind.group ||
              template.items.isEmpty,
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
    this.showAddItem = true,
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
  final bool showAddItem;
  final ValueChanged<MaterialItem>? onToggleItem;
  final VoidCallback? onUse;
  final VoidCallback? onInsertMaterials;

  @override
  Widget build(BuildContext context) {
    final completedCount = items.where((item) => item.completed).length;
    return SoftFadeSlide(
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ExpansionTile(
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
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
                  if (showAddItem)
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
          ? SoftAnimatedCheckbox(
              value: item.completed,
              onChanged: (_) => onToggle?.call(),
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
