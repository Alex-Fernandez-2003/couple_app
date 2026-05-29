import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/providers.dart';
import '../../../data/models/message.dart';
import '../../../shared/widgets/floral_background.dart';
import '../../../shared/widgets/soft_animations.dart';
import '../widgets/edit_custom_message_dialog.dart';

part '../widgets/home_status_widgets.dart';
part '../widgets/home_card_widgets.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _titleController;
  late AnimationController _messageController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _titleAnimation;
  late Animation<double> _messageAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _titleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _messageController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));
    _titleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _titleController, curve: Curves.easeOut));
    _messageAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _messageController, curve: Curves.easeOut),
    );

    _fadeController.forward();
    _titleController.forward();
    _messageController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _showEditDialog(String currentMessage) {
    showDialog(
      context: context,
      builder: (context) => EditCustomMessageDialog(
        initialValue: currentMessage,
        onSave: (newMessage) async {
          final roomState = ref.read(roomStateProvider);
          if (roomState.status == RoomStatus.connected &&
              roomState.room != null) {
            try {
              await ref
                  .read(roomStateProvider.notifier)
                  .updateCustomMessage(roomState.room!.id, newMessage);
              _titleController.forward(from: 0);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Mensaje actualizado ❤️'),
                    duration: Duration(seconds: 2),
                    backgroundColor: Color(0xFFFD8392),
                  ),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: ${e.toString()}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          }
        },
      ),
    );
  }

  Future<void> _pickRelationshipStartDate(DateTime? currentDate) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: currentDate ?? now,
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked == null) return;

    await ref
        .read(roomStateProvider.notifier)
        .updateRelationshipStartDate(
          DateTime(picked.year, picked.month, picked.day),
        );
  }

  Future<void> _refreshHome() async {
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

  @override
  Widget build(BuildContext context) {
    final roomState = ref.watch(roomStateProvider);
    final pendingTodos = ref.watch(pendingTodosCountProvider);
    final pendingShopping = ref.watch(pendingShoppingCountProvider);
    final notesCount = ref.watch(notesCountProvider);
    final boxesCount = ref.watch(boxesCountProvider);
    final calendarCount = ref.watch(calendarReminderCountProvider);
    final currentUserId = ref.watch(currentUserIdProvider);

    final customMessage = roomState.customMessage ?? 'Tu espacio de pareja';
    final isRoomConnected = roomState.status == RoomStatus.connected;
    final relationshipStartDate = roomState.relationshipStartDate;
    final periodStartedAt = roomState.periodStartedAt;

    // Message notifier - only if room is connected and we have user ID
    late final AsyncValue<Message?> messageNotifier;
    if (isRoomConnected && roomState.room != null && currentUserId != null) {
      final messageParams = (roomState.room!.id, currentUserId);
      messageNotifier = ref.watch(messageProvider(messageParams));
    } else {
      messageNotifier = const AsyncValue.data(null);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            onPressed: () => context.go('/theme-settings'),
            icon: const Icon(Icons.palette_outlined),
            tooltip: 'Personalización',
          ),
          IconButton(
            onPressed: _refreshHome,
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar',
          ),
        ],
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: FloralBackground(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Theme.of(context).scaffoldBackgroundColor,
                    Theme.of(context).colorScheme.surface,
                  ],
                ),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final horizontalPadding = constraints.maxWidth >= 600
                      ? 24.0
                      : 16.0;
                  final availableWidth =
                      constraints.maxWidth - (horizontalPadding * 2);
                  final contentWidth = availableWidth > 720
                      ? 720.0
                      : availableWidth;
                  final gridColumns = contentWidth >= 420 ? 2 : 1;
                  final gridRatio = gridColumns == 1 ? 1.75 : 1.12;

                  return RefreshIndicator(
                    onRefresh: _refreshHome,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        16,
                        horizontalPadding,
                        24,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 720),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Editable custom message title
                              FadeTransition(
                                opacity: _titleAnimation,
                                child: GestureDetector(
                                  onTap: isRoomConnected
                                      ? () => _showEditDialog(customMessage)
                                      : null,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0xFFFD8392)
                                            .withValues(
                                              alpha: isRoomConnected ? 0.3 : 0,
                                            ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            customMessage,
                                            style: const TextStyle(
                                              fontSize: 28,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF2D3748),
                                            ),
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (isRoomConnected)
                                          const SizedBox(width: 8),
                                        if (isRoomConnected)
                                          Icon(
                                            Icons.edit,
                                            size: 20,
                                            color: const Color(
                                              0xFFFD8392,
                                            ).withValues(alpha: 0.7),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),

                              _RelationshipTrackerCard(
                                relationshipStartDate: relationshipStartDate,
                                periodStartedAt: periodStartedAt,
                                onEditStartDate: () =>
                                    _pickRelationshipStartDate(
                                      relationshipStartDate,
                                    ),
                                onClearStartDate: relationshipStartDate == null
                                    ? null
                                    : () => ref
                                          .read(roomStateProvider.notifier)
                                          .updateRelationshipStartDate(null),
                                onStartPeriod: () => ref
                                    .read(roomStateProvider.notifier)
                                    .startPeriod(),
                                onClearPeriod: periodStartedAt == null
                                    ? null
                                    : () => ref
                                          .read(roomStateProvider.notifier)
                                          .updatePeriodStartedAt(null),
                              ),
                              const SizedBox(height: 12),

                              // Incoming message card
                              if (isRoomConnected) ...[
                                FadeTransition(
                                  opacity: _messageAnimation,
                                  child: Builder(
                                    builder: (context) {
                                      return messageNotifier.when(
                                        data: (message) {
                                          if (message == null) {
                                            return _EmptyMessageCard();
                                          }
                                          return Card(
                                            elevation: 4,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            child: Container(
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                gradient: LinearGradient(
                                                  colors: [
                                                    const Color(
                                                      0xFFFD8392,
                                                    ).withValues(alpha: 0.05),
                                                    const Color(
                                                      0xFFF7C0C9,
                                                    ).withValues(alpha: 0.1),
                                                  ],
                                                ),
                                              ),
                                              padding: const EdgeInsets.all(16),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Un mensaje para ti',
                                                    style: Theme.of(
                                                      context,
                                                    ).textTheme.labelSmall,
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    message.content,
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: Color(0xFF2D3748),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                        loading: () => const Card(
                                          child: Padding(
                                            padding: EdgeInsets.all(16),
                                            child: CircularProgressIndicator(),
                                          ),
                                        ),
                                        error: (error, stack) =>
                                            _EmptyMessageCard(),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 24),
                              ],

                              // Counts grid
                              GridView.count(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                crossAxisCount: gridColumns,
                                mainAxisSpacing: 16,
                                crossAxisSpacing: 16,
                                childAspectRatio: gridRatio,
                                children: [
                                  _AnimatedHomeCard(
                                    delay: 0,
                                    title: 'Tareas pendientes',
                                    count: pendingTodos,
                                    icon: Icons.check_circle_outline,
                                    color: const Color(0xFFFD8392),
                                    onTap: () => context.go('/couple'),
                                  ),
                                  _AnimatedHomeCard(
                                    delay: 100,
                                    title: 'Compras pendientes',
                                    count: pendingShopping,
                                    icon: Icons.shopping_cart_outlined,
                                    color: const Color(0xFFFD8392),
                                    onTap: () => context.go('/shopping'),
                                  ),
                                  _AnimatedHomeCard(
                                    delay: 200,
                                    title: 'Notas guardadas',
                                    count: notesCount,
                                    icon: Icons.note_outlined,
                                    color: const Color(0xFFFD8392),
                                    onTap: () => context.go('/notes'),
                                  ),
                                  _AnimatedHomeCard(
                                    delay: 300,
                                    title: 'Recordatorios',
                                    count: calendarCount,
                                    icon: Icons.calendar_month_outlined,
                                    color: const Color(0xFFFD8392),
                                    onTap: () => context.go('/calendar'),
                                  ),
                                  _AnimatedHomeCard(
                                    delay: 400,
                                    title: 'Cajas creadas',
                                    count: boxesCount,
                                    icon: Icons.inventory_2_outlined,
                                    color: const Color(0xFFFD8392),
                                    onTap: () => context.go('/boxes'),
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
          ),
        ),
      ),
    );
  }
}
