import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/connectivity_controller.dart';
import '../../state/session_controller.dart';

/// Shown under the app bar whenever the device is offline or the server has
/// rejected the stored session.
class StatusBanners extends StatelessWidget {
  const StatusBanners({super.key});

  @override
  Widget build(BuildContext context) {
    final isOnline = context.watch<ConnectivityController>().isOnline;
    final needsReauth = context.watch<SessionController>().needsReauth;
    return Column(
      children: [
        if (needsReauth)
          _Banner(
            icon: Icons.lock_clock_rounded,
            color: AppColors.failed,
            text: S.sessionExpired,
            action: TextButton(
              onPressed: () => context.read<SessionController>().signOut(),
              child: const Text(S.login),
            ),
          ),
        if (!isOnline)
          const _Banner(
            icon: Icons.wifi_off_rounded,
            color: AppColors.pending,
            text: S.offlineBanner,
          ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.color,
    required this.text,
    this.action,
  });

  final IconData icon;
  final Color color;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ?action,
          ],
        ),
      ),
    );
  }
}

class SyncStatusChip extends StatelessWidget {
  const SyncStatusChip(this.status, {super.key});

  final SyncStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: status.color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class MeterTypeBadge extends StatelessWidget {
  const MeterTypeBadge(this.type, {super.key, this.compact = false});

  final MeterType type;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: compact ? 36 : 44,
      height: compact ? 36 : 44,
      decoration: BoxDecoration(
        color: type.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(type.icon, color: type.color, size: compact ? 20 : 24),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.body,
  });

  final IconData icon;
  final String title;
  final String? body;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: scheme.outline),
            const SizedBox(height: 14),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (body != null) ...[
              const SizedBox(height: 6),
              Text(
                body!,
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Uses Flutter's own selection toolbar instead of the iOS system context
/// menu, which in debug builds can trip a framework assertion ("Attempted
/// to show while another instance was still visible") when the menu is
/// re-shown during a rebuild. Pass as `contextMenuBuilder` on text fields.
Widget appContextMenuBuilder(BuildContext context, EditableTextState state) =>
    AdaptiveTextSelectionToolbar.editableText(editableTextState: state);

/// One label/value line in an expanded reading or meter card.
class DetailRow extends StatelessWidget {
  const DetailRow(this.label, this.value, {super.key, this.mono = false});

  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textDirection: mono ? TextDirection.ltr : null,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                fontFamily: mono ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Square thumbnail: the photo with the meter-type icon pinned to the
/// lower corner. Falls back to the plain type badge when there is no image
/// or it fails to load.
class PhotoThumb extends StatelessWidget {
  const PhotoThumb({super.key, required this.type, this.image, this.size = 44});

  final MeterType type;
  final ImageProvider? image;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = SizedBox(
      width: size,
      height: size,
      child: MeterTypeBadge(type, compact: size < 44),
    );
    if (image == null) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image(
              image: image!,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => fallback,
            ),
            PositionedDirectional(
              bottom: 0,
              end: 0,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: type.color,
                  borderRadius: const BorderRadiusDirectional.only(
                    topStart: Radius.circular(8),
                  ),
                ),
                child: Icon(type.icon, size: size * 0.3, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-size reading photo for an expanded card: the whole image, letterboxed
/// on a dark ground, tap to open a pinch-zoom viewer. `image == null` means
/// the photo was purged after the retention period.
class ReadingPhoto extends StatelessWidget {
  const ReadingPhoto({super.key, required this.image});

  final ImageProvider? image;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (image == null) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hide_image_outlined, color: scheme.outline, size: 30),
            const SizedBox(height: 6),
            Text(
              S.photoExpired,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
            ),
          ],
        ),
      );
    }
    return Tooltip(
      message: S.openPhoto,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PhotoViewerScreen(image: image!),
            fullscreenDialog: true,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            color: const Color(0xFF1D2422),
            constraints: const BoxConstraints(maxHeight: 360, minHeight: 160),
            width: double.infinity,
            child: Image(
              image: image!,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : const SizedBox(
                      height: 160,
                      child: Center(child: CircularProgressIndicator()),
                    ),
              errorBuilder: (context, _, _) => SizedBox(
                height: 160,
                child: Center(
                  child: Text(
                    S.photoLoadFailed,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PhotoViewerScreen extends StatelessWidget {
  const PhotoViewerScreen({super.key, required this.image});

  final ImageProvider image;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          child: Image(image: image, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
