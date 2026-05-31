import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/shopping_item.dart';
import '../../../data/providers.dart';
import '../../../shared/widgets/floral_background.dart';
import '../../../shared/widgets/soft_animations.dart';

part '../widgets/shopping_tabs_widgets.dart';
part '../widgets/shopping_dialogs_widgets.dart';
part '../widgets/shopping_state_widgets.dart';

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
              categories: state.categories,
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
        initialCategoryId: template?.categoryId,
        categories: ref.read(shoppingProvider).value?.categories ?? const [],
        forceCategorySelector: true,
        onSave: (values) async {
          final notifier = ref.read(shoppingProvider.notifier);
          if (template == null) {
            await notifier.addTemplate(
              values.title,
              notes: values.notes,
              price: values.price,
              categoryId: values.categoryId,
            );
          } else {
            await notifier.updateTemplate(
              template.copyWith(
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

  void _showCategoriesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _ShoppingCategoriesDialog(),
    );
  }
}
