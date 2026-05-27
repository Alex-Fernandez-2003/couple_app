import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/box_model.dart';
import '../../../data/providers.dart';

part '../widgets/boxes_tabs_widgets.dart';
part '../widgets/boxes_dialogs_widgets.dart';
part '../widgets/boxes_state_widgets.dart';
part '../widgets/boxes_utils.dart';

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
        initialKind: template?.kind,
        initialItems: template?.items ?? const [],
        onSave: (values) async {
          final notifier = ref.read(boxesProvider.notifier);
          if (template == null) {
            await notifier.addMaterialTemplate(
              values.title,
              kind: values.kind,
              items: values.items,
            );
          } else {
            await notifier.updateMaterialTemplate(
              template.copyWith(
                title: values.title,
                kind: values.kind,
                items: values.items,
              ),
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
