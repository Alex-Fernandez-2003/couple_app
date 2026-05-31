part of '../screens/notes_screen.dart';

class _AudioAttachmentTile extends StatelessWidget {
  const _AudioAttachmentTile({
    super.key,
    required this.index,
    required this.attachment,
    required this.isActive,
    required this.isPlaying,
    required this.position,
    required this.duration,
    required this.speed,
    required this.onPlayPause,
    required this.onSpeedChanged,
    required this.onOpenExternal,
    required this.onShare,
    required this.onRename,
    required this.onDelete,
    required this.onToggleReviewed,
    this.onSeek,
  });

  final int index;
  final NoteAudioAttachment attachment;
  final bool isActive;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final double speed;
  final VoidCallback onPlayPause;
  final ValueChanged<Duration>? onSeek;
  final ValueChanged<double> onSpeedChanged;
  final VoidCallback onOpenExternal;
  final VoidCallback onShare;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onToggleReviewed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final maxSeconds = duration.inSeconds <= 0
        ? 1.0
        : duration.inSeconds.toDouble();
    final currentSeconds = position.inSeconds
        .clamp(0, maxSeconds.toInt())
        .toDouble();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 380;
            final title = Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    attachment.customName ?? _basename(attachment.path),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_formatDuration(duration)} · ${_formatDateTime(attachment.createdAt)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurface.withValues(alpha: 0.64),
                    ),
                  ),
                ],
              ),
            );
            final actions = Wrap(
              spacing: 2,
              children: [
                IconButton(
                  icon: const Icon(Icons.ios_share_outlined),
                  tooltip: 'Compartir',
                  onPressed: onShare,
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'open') onOpenExternal();
                    if (value == 'share') onShare();
                    if (value == 'rename') onRename();
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'open', child: Text('Abrir externo')),
                    PopupMenuItem(value: 'share', child: Text('Compartir')),
                    PopupMenuItem(value: 'rename', child: Text('Renombrar')),
                    PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                  ],
                ),
              ],
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ReorderableDragStartListener(
                      index: index,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Icon(
                          Icons.drag_handle,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Checkbox(
                      value: attachment.isReviewed,
                      onChanged: (_) => onToggleReviewed(),
                      activeColor: const Color(0xFFFD8392),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    IconButton.filledTonal(
                      onPressed: onPlayPause,
                      icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                      tooltip: isPlaying ? 'Pausar' : 'Reproducir',
                    ),
                    const SizedBox(width: 8),
                    title,
                    if (!compact) actions,
                  ],
                ),
                if (compact) ...[
                  const SizedBox(height: 8),
                  Align(alignment: Alignment.centerRight, child: actions),
                ],
                const SizedBox(height: 8),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: const Color(0xFFFD8392),
                    thumbColor: const Color(0xFFFD8392),
                    inactiveTrackColor: const Color(
                      0xFFFD8392,
                    ).withValues(alpha: 0.18),
                  ),
                  child: Slider(
                    value: currentSeconds,
                    min: 0,
                    max: maxSeconds,
                    onChanged: onSeek == null
                        ? null
                        : (value) => onSeek!(Duration(seconds: value.round())),
                  ),
                ),
                Row(
                  children: [
                    Text(
                      _formatDuration(position),
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurface.withValues(alpha: 0.64),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _formatDuration(duration),
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurface.withValues(alpha: 0.64),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final value in const [0.5, 1.0, 1.5, 2.0])
                      ChoiceChip(
                        label: Text('${_formatSpeed(value)}x'),
                        selected: isActive && speed == value,
                        onSelected: (_) => onSpeedChanged(value),
                        selectedColor: const Color(
                          0xFFFD8392,
                        ).withValues(alpha: 0.18),
                        checkmarkColor: const Color(0xFFFD8392),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SmallLabel extends StatelessWidget {
  const _SmallLabel({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: colors.onSurface.withValues(alpha: 0.62)),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: colors.onSurface.withValues(alpha: 0.62),
          ),
        ),
      ],
    );
  }
}
