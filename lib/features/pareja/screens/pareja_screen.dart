import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:couple_app/data/providers.dart';
import 'package:couple_app/data/models/shared_item.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:go_router/go_router.dart';
import '../widgets/send_message_dialog.dart';

class ParejaScreen extends ConsumerStatefulWidget {
  const ParejaScreen({super.key});

  @override
  ConsumerState<ParejaScreen> createState() => _ParejaScreenState();
}

class _ParejaScreenState extends ConsumerState<ParejaScreen> {
  final _taskController = TextEditingController();
  final _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _subscribeToTasksIfConnected();
    });
  }

  @override
  void dispose() {
    _taskController.dispose();
    super.dispose();
  }

  void _subscribeToTasksIfConnected() {
    final roomState = ref.read(roomStateProvider);
    if (roomState.status == RoomStatus.connected && roomState.room != null) {
      ref.read(sharedItemsProvider.notifier).subscribe(roomState.room!.id);
    }
  }

  Future<void> _refreshPareja() async {
    final roomState = ref.read(roomStateProvider);
    final currentUserId = ref.read(currentUserIdProvider);

    if (roomState.status != RoomStatus.connected || roomState.room == null) {
      return;
    }

    final roomId = roomState.room!.id;
    await Future.wait([
      ref.read(roomStateProvider.notifier).refreshCurrentRoom(),
      ref.read(sharedItemsProvider.notifier).refresh(roomId),
      if (currentUserId != null)
        ref
            .read(messageProvider((roomId, currentUserId)).notifier)
            .refreshLatest(),
    ]);
  }

  void _showSendMessageDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => SendMessageDialog(
        onSend: (content) async {
          final roomState = ref.read(roomStateProvider);
          final currentUserId = ref.read(currentUserIdProvider);

          if (roomState.status != RoomStatus.connected ||
              roomState.room == null ||
              currentUserId == null) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'No hay conexión con tu pareja. Intenta después.',
                  ),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return;
          }

          try {
            final messageParams = (roomState.room!.id, currentUserId);
            final messageNotifier = ref.read(
              messageProvider(messageParams).notifier,
            );
            await messageNotifier.sendMessage(content);
          } catch (e) {
            debugPrint('Error sending message: $e');
            rethrow;
          }
        },
      ),
    );
  }

  void _showAddTaskDialog(BuildContext context, WidgetRef ref) {
    _taskController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Agregar tarea'),
        content: TextField(
          controller: _taskController,
          decoration: const InputDecoration(
            labelText: 'Tarea',
            hintText: '¿Qué necesitan hacer juntos?',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final roomState = ref.read(roomStateProvider);
              if (roomState.status == RoomStatus.connected &&
                  roomState.room != null &&
                  _taskController.text.isNotEmpty) {
                try {
                  await ref
                      .read(sharedItemsProvider.notifier)
                      .addItem(roomState.room!.id, _taskController.text.trim());
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Tarea agregada ✓'),
                        duration: Duration(seconds: 2),
                        backgroundColor: Color(0xFFFD8392),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            },
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickPartnerPhoto(BuildContext context, WidgetRef ref) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        imageQuality: 85,
      );
      if (picked == null) return;

      final appDirectory = await getApplicationDocumentsDirectory();
      final extension = picked.path.split('.').last.toLowerCase();
      final safeExtension = extension.isEmpty ? 'jpg' : extension;
      final fileName =
          'partner_photo_${DateTime.now().millisecondsSinceEpoch}.$safeExtension';
      final savedFile = File('${appDirectory.path}/$fileName');
      await File(picked.path).copy(savedFile.path);

      final oldPath = ref.read(partnerPhotoProvider).value;
      await ref
          .read(partnerPhotoProvider.notifier)
          .setPhotoPath(savedFile.path);
      await _deleteLocalPhotoFile(oldPath);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo guardar la foto: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _removePartnerPhoto(WidgetRef ref) async {
    final currentPath = ref.read(partnerPhotoProvider).value;
    await ref.read(partnerPhotoProvider.notifier).clearPhotoPath();
    await _deleteLocalPhotoFile(currentPath);
  }

  Future<void> _deleteLocalPhotoFile(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // The saved preference is already cleared; stale files should not block UI.
    }
  }

  Future<void> _confirmLeaveRoom(BuildContext context) async {
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Salir de la sala'),
        content: const Text(
          'Esto solo quitará la sala de este dispositivo. No se borrará nada de Supabase.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Salir'),
          ),
        ],
      ),
    );

    if (shouldLeave != true) return;
    await ref.read(roomStateProvider.notifier).leaveRoom();
    if (!context.mounted) return;
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final roomState = ref.watch(roomStateProvider);
        final tasksState = ref.watch(sharedItemsProvider);
        final partnerPhoto = ref.watch(partnerPhotoProvider);
        final isRoomConnected = roomState.status == RoomStatus.connected;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Mi pareja'),
            centerTitle: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              IconButton(
                onPressed: _refreshPareja,
                icon: const Icon(Icons.refresh),
                tooltip: 'Recargar',
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'leave') _confirmLeaveRoom(context);
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'leave',
                    child: Text('Salir de la sala'),
                  ),
                ],
              ),
            ],
          ),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final horizontalPadding = constraints.maxWidth >= 600
                    ? 24.0
                    : 16.0;

                return RefreshIndicator(
                  onRefresh: _refreshPareja,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      16,
                      horizontalPadding,
                      isRoomConnected ? 128 : 24,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 720),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (roomState.message.isNotEmpty) ...[
                              Card(
                                color: const Color(
                                  0xFFFD8392,
                                ).withValues(alpha: 0.08),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(
                                    roomState.message,
                                    style: const TextStyle(
                                      color: Color(0xFF80515A),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            // Placeholder partner info card
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    _PartnerPhotoAvatar(
                                      photoPath: partnerPhoto.value,
                                      onChangePhoto: () =>
                                          _pickPartnerPhoto(context, ref),
                                    ),
                                    const SizedBox(height: 12),
                                    if (isRoomConnected &&
                                        roomState.room != null)
                                      Column(
                                        children: [
                                          const Text(
                                            'Mi amor',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Conectados desde el ${roomState.room!.createdAt.day}/${roomState.room!.createdAt.month}/${roomState.room!.createdAt.year}',
                                            textAlign: TextAlign.center,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                          ),
                                        ],
                                      )
                                    else
                                      const Text(
                                        'Sin conexión',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontStyle: FontStyle.italic,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      alignment: WrapAlignment.center,
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        OutlinedButton.icon(
                                          onPressed: () =>
                                              _pickPartnerPhoto(context, ref),
                                          icon: const Icon(Icons.photo_camera),
                                          label: Text(
                                            partnerPhoto.value == null
                                                ? 'Agregar foto'
                                                : 'Cambiar foto',
                                          ),
                                        ),
                                        if (partnerPhoto.value != null)
                                          TextButton.icon(
                                            onPressed: () =>
                                                _removePartnerPhoto(ref),
                                            icon: const Icon(
                                              Icons.delete_outline,
                                            ),
                                            label: const Text('Eliminar foto'),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            // Info section
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Información de pareja',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    if (isRoomConnected &&
                                        roomState.room != null) ...[
                                      _InfoRow(
                                        label: 'Código de conexión',
                                        value: roomState.room!.inviteCode,
                                      ),
                                      const SizedBox(height: 8),
                                      _InfoRow(
                                        label: 'Nombre del espacio',
                                        value: roomState.room!.name,
                                      ),
                                    ] else
                                      const Text(
                                        'Conéctate con tu pareja para ver información.',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            if (isRoomConnected && roomState.room != null) ...[
                              _TasksCard(
                                tasksState: tasksState,
                                onRetry: () => ref
                                    .read(sharedItemsProvider.notifier)
                                    .refresh(roomState.room!.id),
                                onToggle: (item) => ref
                                    .read(sharedItemsProvider.notifier)
                                    .toggleCompletion(item),
                                onDelete: (item) => ref
                                    .read(sharedItemsProvider.notifier)
                                    .removeItem(item),
                              ),
                              const SizedBox(height: 24),
                            ],
                            // Empty state message
                            if (!isRoomConnected)
                              Center(
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.heart_broken,
                                      size: 48,
                                      color: const Color(
                                        0xFFFD8392,
                                      ).withValues(alpha: 0.5),
                                    ),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'Necesitas estar conectado con tu pareja\npara enviar mensajes y agregar tareas',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          floatingActionButton: isRoomConnected
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    FloatingActionButton(
                      heroTag: 'task_fab',
                      onPressed: () => _showAddTaskDialog(context, ref),
                      tooltip: 'Agregar tarea',
                      child: const Icon(Icons.check_circle_outline),
                    ),
                    const SizedBox(height: 16),
                    FloatingActionButton.extended(
                      heroTag: 'message_fab',
                      onPressed: () => _showSendMessageDialog(context, ref),
                      label: const Text('Mensaje'),
                      icon: const Icon(Icons.send),
                      backgroundColor: const Color(0xFFFD8392),
                    ),
                  ],
                )
              : null,
        );
      },
    );
  }
}

class _PartnerPhotoAvatar extends StatelessWidget {
  const _PartnerPhotoAvatar({
    required this.photoPath,
    required this.onChangePhoto,
  });

  static const _heroTag = 'partner_photo_hero';

  final String? photoPath;
  final VoidCallback onChangePhoto;

  @override
  Widget build(BuildContext context) {
    final path = photoPath;
    final hasPhoto = path != null && path.isNotEmpty && File(path).existsSync();

    return Semantics(
      button: true,
      label: hasPhoto ? 'Ver foto de pareja' : 'Agregar foto de pareja',
      child: SizedBox(
        width: 112,
        height: 112,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(
              child: InkWell(
                onTap: hasPhoto
                    ? () => _openPartnerPhotoViewer(context, path)
                    : onChangePhoto,
                customBorder: const CircleBorder(),
                child: Hero(
                  tag: _heroTag,
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: hasPhoto
                          ? null
                          : LinearGradient(
                              colors: [
                                const Color(0xFFFD8392).withValues(alpha: 0.7),
                                const Color(0xFFF7C0C9).withValues(alpha: 0.7),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: hasPhoto
                        ? Image.file(File(path), fit: BoxFit.cover)
                        : const Center(
                            child: Icon(
                              Icons.favorite,
                              color: Colors.white,
                              size: 42,
                            ),
                          ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 4,
              bottom: 4,
              child: Material(
                color: const Color(0xFFFD8392),
                shape: const CircleBorder(),
                elevation: 3,
                child: IconButton(
                  onPressed: onChangePhoto,
                  icon: Icon(
                    hasPhoto ? Icons.edit : Icons.photo_camera,
                    color: Colors.white,
                  ),
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  tooltip: hasPhoto ? 'Cambiar foto' : 'Agregar foto',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openPartnerPhotoViewer(BuildContext context, String path) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: _PartnerPhotoViewer(photoPath: path, heroTag: _heroTag),
          );
        },
      ),
    );
  }
}

class _PartnerPhotoViewer extends StatelessWidget {
  const _PartnerPhotoViewer({required this.photoPath, required this.heroTag});

  final String photoPath;
  final String heroTag;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).pop(),
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: Hero(
                  tag: heroTag,
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4,
                    child: Image.file(File(photoPath), fit: BoxFit.contain),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white),
                  tooltip: 'Cerrar',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _TaskFilter { all, pending, completed }

class _TasksCard extends StatefulWidget {
  const _TasksCard({
    required this.tasksState,
    required this.onRetry,
    required this.onToggle,
    required this.onDelete,
  });

  final AsyncValue<List<SharedItem>> tasksState;
  final VoidCallback onRetry;
  final ValueChanged<SharedItem> onToggle;
  final ValueChanged<SharedItem> onDelete;

  @override
  State<_TasksCard> createState() => _TasksCardState();
}

class _TasksCardState extends State<_TasksCard> {
  _TaskFilter _filter = _TaskFilter.all;

  List<SharedItem> _applyFilter(List<SharedItem> tasks) {
    return switch (_filter) {
      _TaskFilter.all => tasks,
      _TaskFilter.pending => tasks.where((task) => !task.completed).toList(),
      _TaskFilter.completed => tasks.where((task) => task.completed).toList(),
    };
  }

  String _emptyMessage() {
    return switch (_filter) {
      _TaskFilter.all => 'Aún no hay tareas. Agrega la primera con el botón +.',
      _TaskFilter.pending => 'No hay tareas pendientes por ahora.',
      _TaskFilter.completed => 'Aún no hay tareas completadas.',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tareas de pareja',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            widget.tasksState.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Error al cargar las tareas: $error',
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: widget.onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                ],
              ),
              data: (tasks) {
                final filteredTasks = _applyFilter(tasks);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _TaskFilterChip(
                          label: 'Todas',
                          selected: _filter == _TaskFilter.all,
                          onSelected: () =>
                              setState(() => _filter = _TaskFilter.all),
                        ),
                        _TaskFilterChip(
                          label: 'Pendientes',
                          selected: _filter == _TaskFilter.pending,
                          onSelected: () =>
                              setState(() => _filter = _TaskFilter.pending),
                        ),
                        _TaskFilterChip(
                          label: 'Completadas',
                          selected: _filter == _TaskFilter.completed,
                          onSelected: () =>
                              setState(() => _filter = _TaskFilter.completed),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: filteredTasks.isEmpty
                          ? Padding(
                              key: ValueKey(_filter),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                _emptyMessage(),
                                style: const TextStyle(color: Colors.grey),
                              ),
                            )
                          : Column(
                              key: ValueKey(_filter),
                              children: [
                                for (final task in filteredTasks)
                                  CheckboxListTile(
                                    value: task.completed,
                                    onChanged: (_) => widget.onToggle(task),
                                    title: Text(
                                      task.title,
                                      style: TextStyle(
                                        decoration: task.completed
                                            ? TextDecoration.lineThrough
                                            : null,
                                      ),
                                    ),
                                    secondary: IconButton(
                                      onPressed: () => widget.onDelete(task),
                                      icon: const Icon(Icons.delete_outline),
                                      tooltip: 'Eliminar tarea',
                                    ),
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                              ],
                            ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskFilterChip extends StatelessWidget {
  const _TaskFilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: const Color(0xFFFD8392).withValues(alpha: 0.18),
      checkmarkColor: const Color(0xFFFD8392),
      labelStyle: TextStyle(
        color: selected ? const Color(0xFFFD8392) : const Color(0xFF4A5568),
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      ),
      side: BorderSide(
        color: selected ? const Color(0xFFFD8392) : Colors.grey.shade300,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w500),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
