part of '../screens/shopping_screen.dart';

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
    required this.categories,
    required this.onAdd,
    required this.onEdit,
    required this.onUse,
    required this.onDelete,
  });

  final List<ShoppingTemplate> templates;
  final List<ShoppingCategory> categories;
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
        final categoryById = {
          for (final category in categories) category.id: category,
        };
        final categoryName = template.categoryId == null
            ? template.category
            : categoryById[template.categoryId]?.name;
        return _ShoppingTemplateCard(
          template: template,
          categoryName: categoryName,
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
    return SoftFadeSlide(
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: SoftAnimatedCheckbox(
            value: item.completed,
            onChanged: (_) => onToggle(),
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
      ),
    );
  }
}

class _ShoppingTemplateCard extends StatelessWidget {
  const _ShoppingTemplateCard({
    required this.template,
    this.categoryName,
    required this.onUse,
    required this.onEdit,
    required this.onDelete,
  });

  final ShoppingTemplate template;
  final String? categoryName;
  final VoidCallback onUse;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return SoftFadeSlide(
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: const Icon(Icons.bookmark_border, color: Color(0xFFFD8392)),
          title: Text(template.title),
          subtitle: _ShoppingMetadata(
            notes: template.notes,
            price: template.price,
            category: categoryName,
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
