import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/providers.dart';
import '../../../data/models/message.dart';
import '../widgets/edit_custom_message_dialog.dart';

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

  @override
  Widget build(BuildContext context) {
    final roomState = ref.watch(roomStateProvider);
    final pendingTodos = ref.watch(pendingTodosCountProvider);
    final pendingShopping = ref.watch(pendingShoppingCountProvider);
    final notesCount = ref.watch(notesCountProvider);
    final boxesCount = ref.watch(boxesCountProvider);
    final currentUserId = ref.watch(currentUserIdProvider);

    final customMessage = roomState.customMessage ?? 'Tu espacio de pareja';
    final isRoomConnected = roomState.status == RoomStatus.connected;

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
        foregroundColor: Theme.of(context).colorScheme.onSurface,
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
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
            child: Padding(
              padding: const EdgeInsets.all(24.0),
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
                            color: const Color(
                              0xFFFD8392,
                            ).withValues(alpha: isRoomConnected ? 0.3 : 0),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                customMessage,
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isRoomConnected) const SizedBox(width: 8),
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
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
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
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
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
                            error: (error, stack) => _EmptyMessageCard(),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Counts grid
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 20,
                      crossAxisSpacing: 20,
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
                          title: 'Cajas creadas',
                          count: boxesCount,
                          icon: Icons.inventory_2_outlined,
                          color: const Color(0xFFFD8392),
                          onTap: () => context.go('/boxes'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyMessageCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              const Color(0xFFFD8392).withValues(alpha: 0.03),
              Theme.of(context).colorScheme.surface,
            ],
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.mail_outline,
              size: 32,
              color: const Color(0xFFFD8392).withValues(alpha: 0.4),
            ),
            const SizedBox(height: 8),
            Text(
              'Tu pareja aún no te ha dejado un mensaje ❤️',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.68),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedHomeCard extends StatefulWidget {
  final int delay;
  final String title;
  final int count;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _AnimatedHomeCard({
    required this.delay,
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<_AnimatedHomeCard> createState() => _AnimatedHomeCardState();
}

class _AnimatedHomeCardState extends State<_AnimatedHomeCard>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _slideController;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        _slideController.forward();
        _scaleController.forward();
      }
    });
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: _HomeCard(
          title: widget.title,
          count: widget.count,
          icon: widget.icon,
          color: widget.color,
          onTap: widget.onTap,
        ),
      ),
    );
  }
}

class _HomeCard extends StatefulWidget {
  final String title;
  final int count;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _HomeCard({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<_HomeCard> createState() => _HomeCardState();
}

class _HomeCardState extends State<_HomeCard> with TickerProviderStateMixin {
  late AnimationController _tapController;
  late Animation<double> _tapAnimation;

  @override
  void initState() {
    super.initState();
    _tapController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _tapAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _tapController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _tapController.dispose();
    super.dispose();
  }

  void _handleTap() {
    _tapController.forward().then((_) {
      _tapController.reverse();
    });
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _tapAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _tapAnimation.value,
          child: Card(
            elevation: 8,
            shadowColor: widget.color.withValues(alpha: 0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).colorScheme.surface,
                    widget.color.withValues(alpha: 0.08),
                  ],
                ),
              ),
              child: InkWell(
                onTap: _handleTap,
                borderRadius: BorderRadius.circular(20),
                splashColor: widget.color.withValues(alpha: 0.1),
                highlightColor: widget.color.withValues(alpha: 0.05),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: widget.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(widget.icon, size: 32, color: widget.color),
                      ),
                      const SizedBox(height: 16),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (child, animation) {
                          return ScaleTransition(
                            scale: animation,
                            child: child,
                          );
                        },
                        child: Text(
                          widget.count.toString(),
                          key: ValueKey<int>(widget.count),
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: widget.color,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
