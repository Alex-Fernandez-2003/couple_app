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
            onPressed: _refreshHome,
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar',
          ),
        ],
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFF9F4F4), Colors.white],
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
                                      color: const Color(
                                        0xFFFD8392,
                                      ).withOpacity(isRoomConnected ? 0.3 : 0),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
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
                                          ).withOpacity(0.7),
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
                              onEditStartDate: () => _pickRelationshipStartDate(
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
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              gradient: LinearGradient(
                                                colors: [
                                                  const Color(
                                                    0xFFFD8392,
                                                  ).withOpacity(0.05),
                                                  const Color(
                                                    0xFFF7C0C9,
                                                  ).withOpacity(0.1),
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
                                                    fontWeight: FontWeight.w500,
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
            colors: [const Color(0xFFFD8392).withOpacity(0.03), Colors.white],
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.mail_outline,
              size: 32,
              color: const Color(0xFFFD8392).withOpacity(0.4),
            ),
            const SizedBox(height: 8),
            Text(
              'Tu pareja aún no te ha dejado un mensaje ❤️',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RelationshipTrackerCard extends StatelessWidget {
  const _RelationshipTrackerCard({
    required this.relationshipStartDate,
    required this.periodStartedAt,
    required this.onEditStartDate,
    required this.onStartPeriod,
    this.onClearStartDate,
    this.onClearPeriod,
  });

  final DateTime? relationshipStartDate;
  final DateTime? periodStartedAt;
  final VoidCallback onEditStartDate;
  final VoidCallback? onClearStartDate;
  final VoidCallback onStartPeriod;
  final VoidCallback? onClearPeriod;

  @override
  Widget build(BuildContext context) {
    final together = relationshipStartDate == null
        ? null
        : _timeTogether(relationshipStartDate!, DateTime.now());
    final periodText = periodStartedAt == null
        ? 'Sin periodo registrado'
        : 'Periodo iniciado hace ${_daysSince(periodStartedAt!)} días';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nuestro ritmo',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF2D3748),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.favorite, color: Color(0xFFFD8392)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    together == null
                        ? 'Agrega la fecha en que empezó su historia.'
                        : '${together.years} años, ${together.months} meses y ${together.days} días juntos',
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.water_drop_outlined, color: Color(0xFFFD8392)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(periodText, style: const TextStyle(fontSize: 15)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onEditStartDate,
                  icon: const Icon(Icons.edit_calendar),
                  label: Text(
                    relationshipStartDate == null
                        ? 'Fecha juntos'
                        : 'Editar fecha',
                  ),
                ),
                if (onClearStartDate != null)
                  IconButton(
                    onPressed: onClearStartDate,
                    icon: const Icon(Icons.close),
                    tooltip: 'Quitar fecha',
                  ),
                ElevatedButton.icon(
                  onPressed: onStartPeriod,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Iniciar periodo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFD8392),
                    foregroundColor: Colors.white,
                  ),
                ),
                if (onClearPeriod != null)
                  IconButton(
                    onPressed: onClearPeriod,
                    icon: const Icon(Icons.restart_alt),
                    tooltip: 'Quitar periodo',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TogetherDuration {
  final int years;
  final int months;
  final int days;

  const _TogetherDuration({
    required this.years,
    required this.months,
    required this.days,
  });
}

_TogetherDuration _timeTogether(DateTime start, DateTime now) {
  var years = now.year - start.year;
  var months = now.month - start.month;
  var days = now.day - start.day;

  if (days < 0) {
    final previousMonth = DateTime(now.year, now.month, 0);
    days += previousMonth.day;
    months -= 1;
  }

  if (months < 0) {
    months += 12;
    years -= 1;
  }

  return _TogetherDuration(
    years: years < 0 ? 0 : years,
    months: months < 0 ? 0 : months,
    days: days < 0 ? 0 : days,
  );
}

int _daysSince(DateTime date) {
  final start = DateTime(date.year, date.month, date.day);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return today.difference(start).inDays;
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
            shadowColor: widget.color.withOpacity(0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.white, widget.color.withOpacity(0.05)],
                ),
              ),
              child: InkWell(
                onTap: _handleTap,
                borderRadius: BorderRadius.circular(20),
                splashColor: widget.color.withOpacity(0.1),
                highlightColor: widget.color.withOpacity(0.05),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: widget.color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(widget.icon, size: 30, color: widget.color),
                      ),
                      const SizedBox(height: 12),
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
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: widget.color,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2D3748),
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
