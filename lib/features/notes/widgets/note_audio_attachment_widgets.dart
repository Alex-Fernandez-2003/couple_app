part of '../screens/notes_screen.dart';

class _AudioAttachmentTile extends StatelessWidget {
  const _AudioAttachmentTile({
    super.key,
    required this.index,
    required this.attachment,
    required this.isPlaying,
    required this.position,
    required this.duration,
    required this.onPlayPause,
    required this.onOpenExternal,
    required this.onShare,
    required this.onRename,
    required this.onDelete,
    required this.onToggleReviewed,
    this.onSeek,
  });

  final int index;
  final NoteAudioAttachment attachment;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final VoidCallback onPlayPause;
  final ValueChanged<Duration>? onSeek;
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
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 360;
            final title = Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
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
                  _AudioCreatedAtLabel(
                    createdAt: attachment.createdAt,
                    duration: duration,
                    compact: compact,
                  ),
                ],
              ),
            );
            final actions = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!compact)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.ios_share_outlined),
                    tooltip: 'Compartir',
                    onPressed: onShare,
                  ),
                PopupMenuButton<String>(
                  tooltip: 'Opciones de audio',
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
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    ReorderableDragStartListener(
                      index: index,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 2),
                        child: Icon(
                          Icons.drag_handle,
                          size: 20,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Checkbox(
                      value: attachment.isReviewed,
                      onChanged: (_) => onToggleReviewed(),
                      activeColor: colors.primary,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    IconButton.filledTonal(
                      visualDensity: VisualDensity.compact,
                      onPressed: onPlayPause,
                      icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                      tooltip: isPlaying ? 'Pausar' : 'Reproducir',
                    ),
                    const SizedBox(width: 6),
                    title,
                    actions,
                  ],
                ),
                const SizedBox(height: 4),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: colors.primary,
                    thumbColor: colors.primary,
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 7,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 14,
                    ),
                    inactiveTrackColor: colors.primary.withValues(alpha: 0.18),
                  ),
                  child: Slider(
                    value: currentSeconds,
                    min: 0,
                    max: maxSeconds,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
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
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AudioCreatedAtLabel extends StatelessWidget {
  const _AudioCreatedAtLabel({
    required this.createdAt,
    required this.duration,
    required this.compact,
  });

  final DateTime createdAt;
  final Duration duration;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final style = TextStyle(
      fontSize: 12,
      height: 1.18,
      color: colors.onSurface.withValues(alpha: 0.64),
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_formatAudioDate(createdAt), maxLines: 1, style: style),
          Text(
            '${_formatAudioTime(createdAt)} - ${_formatDuration(duration)}',
            maxLines: 1,
            style: style,
          ),
        ],
      );
    }

    return Text(
      '${_formatDuration(duration)} - ${_formatDateTime(createdAt)}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }
}

class _AudioSpeedButton extends StatelessWidget {
  const _AudioSpeedButton({required this.speed, required this.onChanged});

  final double speed;
  final ValueChanged<double> onChanged;

  static const _values = [0.5, 1.0, 1.5, 2.0];

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<double>(
      tooltip: 'Velocidad de reproducción',
      initialValue: speed,
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final value in _values)
          PopupMenuItem<double>(
            value: value,
            child: Row(
              children: [
                Expanded(child: Text('Velocidad ${_formatSpeed(value)}x')),
                if (speed == value) const Icon(Icons.check, size: 18),
              ],
            ),
          ),
      ],
      child: Builder(
        builder: (context) {
          final colors = Theme.of(context).colorScheme;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.outline.withValues(alpha: 0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.speed, size: 18, color: colors.primary),
                const SizedBox(width: 8),
                Text(
                  '${_formatSpeed(speed)}x',
                  style: TextStyle(
                    color: colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        },
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
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 180),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: colors.onSurface.withValues(alpha: 0.62)),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: colors.onSurface.withValues(alpha: 0.62),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
