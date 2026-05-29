import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:couple_app/data/providers.dart';
import 'package:couple_app/data/models/shared_item.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/floral_background.dart';
import '../widgets/send_message_dialog.dart';

part '../widgets/partner_photo_widgets.dart';
part '../widgets/partner_tasks_widgets.dart';

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
                            if (!isRoomConnected)
                              Column(
                                children: [
                                  FloralEmptyState(
                                    icon: Icons.favorite_border,
                                    title: 'Sin conexión',
                                    message:
                                        'Conecta una sala cuando quieras enviar mensajes y compartir tareas.',
                                    actionLabel: 'Crear conexión',
                                    onAction: () => context.go('/create-room'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () => context.go('/join-room'),
                                    icon: const Icon(Icons.link),
                                    label: const Text('Unirme con código'),
                                  ),
                                ],
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
