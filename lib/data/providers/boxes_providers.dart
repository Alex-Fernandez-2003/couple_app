import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:uuid/uuid.dart';

import '../models/box_model.dart';
import '../services/local_storage_service.dart';

class BoxesState {
  final List<Box> boxes;
  final List<BoxTemplate> templates;
  final List<MaterialTemplate> materialTemplates;

  const BoxesState({
    required this.boxes,
    required this.templates,
    required this.materialTemplates,
  });

  const BoxesState.empty()
    : boxes = const [],
      templates = const [],
      materialTemplates = const [];

  BoxesState copyWith({
    List<Box>? boxes,
    List<BoxTemplate>? templates,
    List<MaterialTemplate>? materialTemplates,
  }) {
    return BoxesState(
      boxes: boxes ?? this.boxes,
      templates: templates ?? this.templates,
      materialTemplates: materialTemplates ?? this.materialTemplates,
    );
  }
}

// Boxes provider
class BoxesNotifier extends StateNotifier<AsyncValue<BoxesState>> {
  BoxesNotifier() : super(const AsyncValue.loading()) {
    _loadBoxes();
  }

  Future<void> _loadBoxes() async {
    state = const AsyncValue.loading();
    try {
      final boxes = await LocalStorageService.getBoxes();
      final templates = await LocalStorageService.getBoxTemplates();
      final materialTemplates =
          await LocalStorageService.getMaterialTemplates();
      state = AsyncValue.data(
        BoxesState(
          boxes: boxes,
          templates: templates,
          materialTemplates: materialTemplates,
        ),
      );
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> addBox(
    String title,
    String description, {
    List<MaterialItem> items = const [],
  }) async {
    final box = Box(
      id: const Uuid().v4(),
      title: title,
      description: description,
      items: items,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final current = state.value ?? const BoxesState.empty();
    await _saveBoxes([box, ...current.boxes]);
  }

  Future<void> addBoxFromTemplate(BoxTemplate template) async {
    final current = state.value ?? const BoxesState.empty();
    await _saveBoxes([template.toBox(const Uuid().v4()), ...current.boxes]);
  }

  Future<void> updateBox(Box updatedBox) async {
    final updated = updatedBox.copyWith(updatedAt: DateTime.now());
    final current = state.value ?? const BoxesState.empty();
    await _saveBoxes(
      current.boxes.map((box) => box.id == updated.id ? updated : box).toList(),
    );
  }

  Future<void> deleteBox(String boxId) async {
    final current = state.value ?? const BoxesState.empty();
    await _saveBoxes(current.boxes.where((box) => box.id != boxId).toList());
  }

  Future<void> addItemToBox(String boxId, String item) async {
    final current = state.value ?? const BoxesState.empty();
    final boxIndex = current.boxes.indexWhere((box) => box.id == boxId);
    if (boxIndex == -1) return;

    final box = current.boxes[boxIndex];
    final updatedBox = box.copyWith(
      items: [...box.items, MaterialItem.create(item)],
    );
    await updateBox(updatedBox);
  }

  Future<void> insertMaterialTemplatesIntoBox(
    String boxId,
    List<MaterialTemplate> materialTemplates,
  ) async {
    if (materialTemplates.isEmpty) return;
    final current = state.value ?? const BoxesState.empty();
    final boxIndex = current.boxes.indexWhere((box) => box.id == boxId);
    if (boxIndex == -1) return;

    final box = current.boxes[boxIndex];
    final newItems = materialTemplates
        .expand((template) => template.createItems())
        .toList();
    await updateBox(box.copyWith(items: [...box.items, ...newItems]));
  }

  Future<void> updateItemInBox(String boxId, MaterialItem updatedItem) async {
    final current = state.value ?? const BoxesState.empty();
    final box = current.boxes.firstWhere((box) => box.id == boxId);
    final updatedBox = box.copyWith(
      items: box.items
          .map(
            (item) => item.id == updatedItem.id
                ? updatedItem.copyWith(updatedAt: DateTime.now())
                : item,
          )
          .toList(),
    );
    await updateBox(updatedBox);
  }

  Future<void> toggleItemInBox(String boxId, MaterialItem item) async {
    await updateItemInBox(boxId, item.copyWith(completed: !item.completed));
  }

  Future<void> removeItemFromBox(String boxId, int itemIndex) async {
    final current = state.value ?? const BoxesState.empty();
    final boxIndex = current.boxes.indexWhere((box) => box.id == boxId);
    if (boxIndex == -1) return;

    final box = current.boxes[boxIndex];
    final updatedItems = [...box.items]..removeAt(itemIndex);
    await updateBox(box.copyWith(items: updatedItems));
  }

  Future<void> addTemplate(
    String title,
    String description, {
    List<MaterialItem> items = const [],
  }) async {
    final now = DateTime.now();
    final template = BoxTemplate(
      id: const Uuid().v4(),
      title: title,
      description: description,
      items: items,
      createdAt: now,
      updatedAt: now,
    );
    final current = state.value ?? const BoxesState.empty();
    await _saveTemplates([template, ...current.templates]);
  }

  Future<void> updateTemplate(BoxTemplate updatedTemplate) async {
    final updated = updatedTemplate.copyWith(updatedAt: DateTime.now());
    final current = state.value ?? const BoxesState.empty();
    await _saveTemplates(
      current.templates
          .map((template) => template.id == updated.id ? updated : template)
          .toList(),
    );
  }

  Future<void> deleteTemplate(String templateId) async {
    final current = state.value ?? const BoxesState.empty();
    await _saveTemplates(
      current.templates.where((template) => template.id != templateId).toList(),
    );
  }

  Future<void> addItemToTemplate(String templateId, String item) async {
    final current = state.value ?? const BoxesState.empty();
    final template = current.templates.firstWhere(
      (template) => template.id == templateId,
    );
    await updateTemplate(
      template.copyWith(items: [...template.items, MaterialItem.create(item)]),
    );
  }

  Future<void> insertMaterialTemplatesIntoBoxTemplate(
    String templateId,
    List<MaterialTemplate> materialTemplates,
  ) async {
    if (materialTemplates.isEmpty) return;
    final current = state.value ?? const BoxesState.empty();
    final template = current.templates.firstWhere(
      (template) => template.id == templateId,
    );
    final newItems = materialTemplates
        .expand((template) => template.createItems())
        .toList();
    await updateTemplate(
      template.copyWith(items: [...template.items, ...newItems]),
    );
  }

  Future<void> updateItemInTemplate(
    String templateId,
    MaterialItem updatedItem,
  ) async {
    final current = state.value ?? const BoxesState.empty();
    final template = current.templates.firstWhere(
      (template) => template.id == templateId,
    );
    await updateTemplate(
      template.copyWith(
        items: template.items
            .map(
              (item) => item.id == updatedItem.id
                  ? updatedItem.copyWith(updatedAt: DateTime.now())
                  : item,
            )
            .toList(),
      ),
    );
  }

  Future<void> removeItemFromTemplate(String templateId, int itemIndex) async {
    final current = state.value ?? const BoxesState.empty();
    final template = current.templates.firstWhere(
      (template) => template.id == templateId,
    );
    final items = [...template.items]..removeAt(itemIndex);
    await updateTemplate(template.copyWith(items: items));
  }

  Future<void> addMaterialTemplate(
    String title, {
    MaterialTemplateKind kind = MaterialTemplateKind.group,
    List<MaterialItem> items = const [],
  }) async {
    final now = DateTime.now();
    final template = MaterialTemplate(
      id: const Uuid().v4(),
      title: title,
      kind: kind,
      items: kind == MaterialTemplateKind.individual && items.length > 1
          ? [items.first]
          : items,
      createdAt: now,
      updatedAt: now,
    );
    final current = state.value ?? const BoxesState.empty();
    await _saveMaterialTemplates([template, ...current.materialTemplates]);
  }

  Future<void> updateMaterialTemplate(MaterialTemplate updatedTemplate) async {
    final updated = updatedTemplate.copyWith(updatedAt: DateTime.now());
    final current = state.value ?? const BoxesState.empty();
    await _saveMaterialTemplates(
      current.materialTemplates
          .map((template) => template.id == updated.id ? updated : template)
          .toList(),
    );
  }

  Future<void> deleteMaterialTemplate(String templateId) async {
    final current = state.value ?? const BoxesState.empty();
    await _saveMaterialTemplates(
      current.materialTemplates
          .where((template) => template.id != templateId)
          .toList(),
    );
  }

  Future<void> addItemToMaterialTemplate(String templateId, String item) async {
    final current = state.value ?? const BoxesState.empty();
    final template = current.materialTemplates.firstWhere(
      (template) => template.id == templateId,
    );
    await updateMaterialTemplate(
      template.kind == MaterialTemplateKind.individual
          ? template.copyWith(items: [MaterialItem.create(item)])
          : template.copyWith(
              items: [...template.items, MaterialItem.create(item)],
            ),
    );
  }

  Future<void> updateItemInMaterialTemplate(
    String templateId,
    MaterialItem updatedItem,
  ) async {
    final current = state.value ?? const BoxesState.empty();
    final template = current.materialTemplates.firstWhere(
      (template) => template.id == templateId,
    );
    await updateMaterialTemplate(
      template.copyWith(
        items: template.items
            .map(
              (item) => item.id == updatedItem.id
                  ? updatedItem.copyWith(updatedAt: DateTime.now())
                  : item,
            )
            .toList(),
      ),
    );
  }

  Future<void> removeItemFromMaterialTemplate(
    String templateId,
    int itemIndex,
  ) async {
    final current = state.value ?? const BoxesState.empty();
    final template = current.materialTemplates.firstWhere(
      (template) => template.id == templateId,
    );
    final items = [...template.items]..removeAt(itemIndex);
    await updateMaterialTemplate(template.copyWith(items: items));
  }

  Future<void> _saveBoxes(List<Box> boxes) async {
    final current = state.value ?? const BoxesState.empty();
    state = AsyncValue.data(current.copyWith(boxes: boxes));
    try {
      await LocalStorageService.saveBoxes(boxes);
    } catch (error, stackTrace) {
      state = AsyncValue.data(current);
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> _saveTemplates(List<BoxTemplate> templates) async {
    final current = state.value ?? const BoxesState.empty();
    state = AsyncValue.data(current.copyWith(templates: templates));
    try {
      await LocalStorageService.saveBoxTemplates(templates);
    } catch (error, stackTrace) {
      state = AsyncValue.data(current);
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> _saveMaterialTemplates(
    List<MaterialTemplate> materialTemplates,
  ) async {
    final current = state.value ?? const BoxesState.empty();
    state = AsyncValue.data(
      current.copyWith(materialTemplates: materialTemplates),
    );
    try {
      await LocalStorageService.saveMaterialTemplates(materialTemplates);
    } catch (error, stackTrace) {
      state = AsyncValue.data(current);
      state = AsyncValue.error(error, stackTrace);
    }
  }
}

final boxesCountProvider = Provider<int>((ref) {
  final boxesState = ref.watch(boxesProvider);
  return boxesState.maybeWhen(
    data: (state) => state.boxes.length,
    orElse: () => 0,
  );
});
final boxesProvider =
    StateNotifierProvider<BoxesNotifier, AsyncValue<BoxesState>>(
      (ref) => BoxesNotifier(),
    );
