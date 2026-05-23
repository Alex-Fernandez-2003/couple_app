import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import '../../../data/connectivity/connectivity_provider.dart';
import '../../../data/models/shared_item.dart';
import '../../../data/providers.dart';

class CoupleListScreen extends ConsumerStatefulWidget {
  const CoupleListScreen({super.key});

  @override
  CoupleListScreenState createState() => CoupleListScreenState();
}

class CoupleListScreenState extends ConsumerState<CoupleListScreen> {
  final _newItemController = TextEditingController();

  @override
  void dispose() {
    _newItemController.dispose();
    super.dispose();
  }

  Future<void> _addItem(String roomId) async {
    if (_newItemController.text.trim().isEmpty) return;
    await ref
        .read(sharedItemsProvider.notifier)
        .addItem(roomId, _newItemController.text.trim());
    _newItemController.clear();
  }

  Widget _buildStatus(RoomState roomState) {
    switch (roomState.status) {
      case RoomStatus.waiting:
        return Text(
          roomState.message,
          style: const TextStyle(color: Colors.black54),
        );
      case RoomStatus.connected:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Código de pareja: ${roomState.room!.inviteCode}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tu conexión está lista. Comparte el código para que tu persona se una.',
              style: TextStyle(color: Colors.black54),
            ),
          ],
        );
      case RoomStatus.error:
        return Text(
          roomState.message,
          style: const TextStyle(color: Colors.red),
        );
      case RoomStatus.idle:
        return const Text(
          'Crea o únete a una conexión para ver la lista compartida.',
          style: TextStyle(color: Colors.black54),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final roomState = ref.watch(roomStateProvider);
    final sharedItemsState = ref.watch(sharedItemsProvider);
    final connectionStatus = ref.watch(connectivityProvider);
    final offline = connectionStatus == ConnectionStatus.offline;

    return Scaffold(
      appBar: AppBar(title: const Text('Lista de pareja')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (offline)
                Card(
                  color: Colors.red.shade50,
                  margin: EdgeInsets.zero,
                  child: const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: Text(
                      'Sin conexión. Los cambios se sincronizarán cuando vuelvas a estar online.',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              _buildStatus(roomState),
              const SizedBox(height: 20),
              if (roomState.status == RoomStatus.idle) ...[
                ElevatedButton(
                  onPressed: () => context.go('/create-room'),
                  child: const Text('Crear conexión'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => context.go('/join-room'),
                  child: const Text('Unirme con código'),
                ),
              ],
              if (roomState.status == RoomStatus.connected) ...[
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _newItemController,
                        decoration: const InputDecoration(
                          labelText: 'Agregar item compartido',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () => _addItem(roomState.room!.id),
                      child: const Text('Añadir'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => ref
                        .read(sharedItemsProvider.notifier)
                        .refresh(roomState.room!.id),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refrescar'),
                  ),
                ),
                const SizedBox(height: 6),
                sharedItemsState.when(
                  data: (items) => items.isEmpty
                      ? const Expanded(
                          child: Center(
                            child: Text(
                              'Aún no hay items. Añade algo bonito para tu pareja.',
                            ),
                          ),
                        )
                      : Expanded(
                          child: ListView.separated(
                            itemCount: items.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final item = items[index];
                              return _SharedItemCard(
                                item: item,
                                onToggle: () => ref
                                    .read(sharedItemsProvider.notifier)
                                    .toggleCompletion(item),
                                onDelete: () => ref
                                    .read(sharedItemsProvider.notifier)
                                    .removeItem(item),
                              );
                            },
                          ),
                        ),
                  loading: () => const Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, _) => Expanded(
                    child: Center(
                      child: Text('Error al cargar los items: $error'),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      floatingActionButton: roomState.status == RoomStatus.connected
          ? FloatingActionButton(
              onPressed: () {
                Clipboard.setData(
                  ClipboardData(text: roomState.room!.inviteCode),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Código copiado al portapapeles'),
                  ),
                );
              },
              tooltip: 'Copiar código',
              child: const Icon(Icons.copy),
            )
          : null,
    );
  }
}

class _SharedItemCard extends StatelessWidget {
  const _SharedItemCard({
    required this.item,
    required this.onToggle,
    required this.onDelete,
  });

  final SharedItem item;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Checkbox(value: item.completed, onChanged: (_) => onToggle()),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.title,
                style: TextStyle(
                  fontSize: 16,
                  decoration: item.completed
                      ? TextDecoration.lineThrough
                      : null,
                ),
              ),
            ),
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }
}
