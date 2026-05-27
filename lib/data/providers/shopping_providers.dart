import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:uuid/uuid.dart';

import '../models/shopping_item.dart';
import '../services/local_storage_service.dart';

class ShoppingState {
  final List<ShoppingItem> items;
  final List<ShoppingTemplate> templates;
  final List<ShoppingCategory> categories;

  const ShoppingState({
    required this.items,
    required this.templates,
    required this.categories,
  });

  const ShoppingState.empty()
    : items = const [],
      templates = const [],
      categories = const [];

  ShoppingState copyWith({
    List<ShoppingItem>? items,
    List<ShoppingTemplate>? templates,
    List<ShoppingCategory>? categories,
  }) {
    return ShoppingState(
      items: items ?? this.items,
      templates: templates ?? this.templates,
      categories: categories ?? this.categories,
    );
  }
}

// Shopping provider (personal/local)
class ShoppingNotifier extends StateNotifier<AsyncValue<ShoppingState>> {
  ShoppingNotifier() : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    state = const AsyncValue.loading();
    try {
      final items = await LocalStorageService.getShoppingItems();
      final templates = await LocalStorageService.getShoppingTemplates();
      final categories = await LocalStorageService.getShoppingCategories();
      state = AsyncValue.data(
        ShoppingState(
          items: items,
          templates: templates,
          categories: categories,
        ),
      );
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> refresh() => _load();

  Future<void> addItem(
    String title, {
    String? notes,
    double? price,
    String? categoryId,
  }) async {
    final now = DateTime.now();
    final item = ShoppingItem(
      id: const Uuid().v4(),
      title: title,
      notes: notes,
      price: price,
      categoryId: categoryId,
      completed: false,
      createdAt: now,
      updatedAt: now,
    );
    await _saveItems([item, ...(state.value?.items ?? [])]);
  }

  Future<void> updateItem(ShoppingItem item) async {
    final current = state.value ?? const ShoppingState.empty();
    final updated = item.copyWith(updatedAt: DateTime.now());
    final items = current.items
        .map((existing) => existing.id == updated.id ? updated : existing)
        .toList();
    await _saveItems(items);
  }

  Future<void> toggleCompletion(ShoppingItem item) async {
    await updateItem(item.copyWith(completed: !item.completed));
  }

  Future<void> removeItem(ShoppingItem item) async {
    final current = state.value ?? const ShoppingState.empty();
    await _saveItems(
      current.items.where((existing) => existing.id != item.id).toList(),
    );
  }

  Future<void> addTemplate(
    String title, {
    String? notes,
    double? price,
    String? categoryId,
  }) async {
    final now = DateTime.now();
    final template = ShoppingTemplate(
      id: const Uuid().v4(),
      title: title,
      notes: notes,
      price: price,
      categoryId: categoryId,
      createdAt: now,
      updatedAt: now,
    );
    await _saveTemplates([template, ...(state.value?.templates ?? [])]);
  }

  Future<void> addCategory(String name) async {
    final now = DateTime.now();
    final category = ShoppingCategory(
      id: const Uuid().v4(),
      name: name,
      createdAt: now,
      updatedAt: now,
    );
    final current = state.value ?? const ShoppingState.empty();
    await _saveCategories([category, ...current.categories]);
  }

  Future<void> updateCategory(ShoppingCategory category) async {
    final current = state.value ?? const ShoppingState.empty();
    final updated = category.copyWith(updatedAt: DateTime.now());
    await _saveCategories(
      current.categories
          .map((existing) => existing.id == updated.id ? updated : existing)
          .toList(),
    );
  }

  Future<void> deleteCategory(String categoryId) async {
    final current = state.value ?? const ShoppingState.empty();
    final categories = current.categories
        .where((category) => category.id != categoryId)
        .toList();
    final items = current.items
        .map(
          (item) => item.categoryId == categoryId
              ? item.copyWith(clearCategory: true, updatedAt: DateTime.now())
              : item,
        )
        .toList();
    final templates = current.templates
        .map(
          (template) => template.categoryId == categoryId
              ? template.copyWith(
                  clearCategory: true,
                  updatedAt: DateTime.now(),
                )
              : template,
        )
        .toList();

    final previous = current;
    state = AsyncValue.data(
      ShoppingState(items: items, templates: templates, categories: categories),
    );
    try {
      await LocalStorageService.saveShoppingItems(items);
      await LocalStorageService.saveShoppingTemplates(templates);
      await LocalStorageService.saveShoppingCategories(categories);
    } catch (error, stackTrace) {
      state = AsyncValue.data(previous);
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> updateTemplate(ShoppingTemplate template) async {
    final current = state.value ?? const ShoppingState.empty();
    final updated = template.copyWith(updatedAt: DateTime.now());
    final templates = current.templates
        .map((existing) => existing.id == updated.id ? updated : existing)
        .toList();
    await _saveTemplates(templates);
  }

  Future<void> removeTemplate(ShoppingTemplate template) async {
    final current = state.value ?? const ShoppingState.empty();
    await _saveTemplates(
      current.templates
          .where((existing) => existing.id != template.id)
          .toList(),
    );
  }

  Future<void> addItemFromTemplate(ShoppingTemplate template) async {
    await _saveItems([
      template.toItem(const Uuid().v4()),
      ...?state.value?.items,
    ]);
  }

  Future<void> _saveItems(List<ShoppingItem> items) async {
    final current = state.value ?? const ShoppingState.empty();
    state = AsyncValue.data(current.copyWith(items: items));
    try {
      await LocalStorageService.saveShoppingItems(items);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> _saveTemplates(List<ShoppingTemplate> templates) async {
    final current = state.value ?? const ShoppingState.empty();
    state = AsyncValue.data(current.copyWith(templates: templates));
    try {
      await LocalStorageService.saveShoppingTemplates(templates);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> _saveCategories(List<ShoppingCategory> categories) async {
    final current = state.value ?? const ShoppingState.empty();
    state = AsyncValue.data(current.copyWith(categories: categories));
    try {
      await LocalStorageService.saveShoppingCategories(categories);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}

final pendingShoppingCountProvider = Provider<int>((ref) {
  final shoppingState = ref.watch(shoppingProvider);
  return shoppingState.maybeWhen(
    data: (state) => state.items.where((item) => !item.completed).length,
    orElse: () => 0,
  );
});
final shoppingProvider =
    StateNotifierProvider<ShoppingNotifier, AsyncValue<ShoppingState>>(
      (ref) => ShoppingNotifier(),
    );
