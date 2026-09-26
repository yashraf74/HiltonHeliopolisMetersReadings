import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
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
              child: Text(S.login),
            ),
          ),
        if (!isOnline)
          _Banner(
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
  const DetailRow(
    this.label,
    this.value, {
    super.key,
    this.mono = false,
    this.onTap,
  });

  final String label;
  final String value;
  final bool mono;

  /// Makes the value a [TapLink] (e.g. a meter or user name).
  final VoidCallback? onTap;

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
            child: onTap != null
                ? Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TapLink(
                      value,
                      onTap: onTap!,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                : Text(
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
  const PhotoThumb({
    super.key,
    required this.type,
    this.image,
    this.size = 44,
    this.zoomOnTap = false,
  });

  final MeterType type;
  final ImageProvider? image;
  final double size;

  /// When true and an image is present, tapping opens the pinch-zoom viewer.
  final bool zoomOnTap;

  @override
  Widget build(BuildContext context) {
    final fallback = SizedBox(
      width: size,
      height: size,
      child: MeterTypeBadge(type, compact: size < 44),
    );
    if (image == null) return fallback;
    final thumb = ClipRRect(
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
    if (!zoomOnTap) return thumb;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PhotoViewerScreen(image: image!),
          fullscreenDialog: true,
        ),
      ),
      child: thumb,
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

/// "▲ 12.5" in green (or "▼ 3" in red for a negative gain); nothing when
/// the gain is unknown (first reading) or zero.
class GainText extends StatelessWidget {
  const GainText(this.gain, {super.key, this.unit, this.fontSize = 12});

  final num? gain;
  final String? unit;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final g = gain;
    if (g == null || g == 0) return const SizedBox.shrink();
    final up = g > 0;
    final color = up ? AppColors.synced : AppColors.failed;
    final number = NumberFormat.decimalPattern('en').format(g.abs());
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          up ? Icons.arrow_drop_up_rounded : Icons.arrow_drop_down_rounded,
          color: color,
          size: fontSize + 8,
        ),
        Text(
          unit == null ? number : '$number $unit',
          textDirection: TextDirection.ltr,
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// Value with its unit, LTR so digits and unit never reorder.
class ValueText extends StatelessWidget {
  const ValueText(
    this.value, {
    super.key,
    required this.unit,
    this.fontSize = 17,
  });

  final num value;
  final String unit;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: NumberFormat.decimalPattern('en').format(value)),
          TextSpan(
            text: ' $unit',
            style: TextStyle(
              fontSize: fontSize * 0.7,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      textDirection: TextDirection.ltr,
      style: TextStyle(fontWeight: FontWeight.w800, fontSize: fontSize),
    );
  }
}

/// Meter-type choice chip with the checkmark suppressed (the avatar icon
/// already marks it); an "all" chip keeps the default checkmark.
class TypeChip extends StatelessWidget {
  const TypeChip({
    super.key,
    required this.type,
    required this.selected,
    required this.onSelected,
  });

  final MeterType type;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(type.label),
      avatar: Icon(
        type.icon,
        size: 18,
        color: selected ? Colors.white : type.color,
      ),
      selected: selected,
      showCheckmark: false,
      selectedColor: type.color,
      labelStyle: TextStyle(
        color: selected ? Colors.white : null,
        fontWeight: FontWeight.w600,
      ),
      onSelected: onSelected,
    );
  }
}

/// Tappable text for a meter, user or reading. It looks like the text around
/// it (no link colour, no underline); a small chevron is the only cue.
class TapLink extends StatelessWidget {
  const TapLink(
    this.text, {
    super.key,
    required this.onTap,
    this.style,
    this.maxLines = 1,
  });

  final String text;
  final VoidCallback onTap;
  final TextStyle? style;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final effective = DefaultTextStyle.of(context).style.merge(style);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              text,
              style: style,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // chevron_right mirrors itself in right-to-left layouts.
          Icon(
            Icons.chevron_right_rounded,
            size: (effective.fontSize ?? 14) + 2,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ],
      ),
    );
  }
}

/// Save button pinned to the bottom of a form screen, above the system
/// navigation bar, so it stays in reach however long the form is.
class StickySaveBar extends StatelessWidget {
  const StickySaveBar({super.key, required this.saving, required this.onSave});

  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(20, 10, 20, 12),
        child: FilledButton(
          onPressed: saving ? null : onSave,
          child: saving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Text(S.save),
        ),
      ),
    );
  }
}

/// Asks what to do when leaving a form that has edits. Only steps in while
/// [dirty] is true, so an untouched form closes silently.
class UnsavedChangesGuard extends StatelessWidget {
  const UnsavedChangesGuard({
    super.key,
    required this.dirty,
    required this.onSave,
    required this.child,
  });

  final bool dirty;

  /// The screen's own save, which closes the screen when it succeeds.
  final Future<void> Function() onSave;

  final Widget child;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !dirty,
    onPopInvokedWithResult: (didPop, _) async {
      if (didPop) return;
      final navigator = Navigator.of(context);
      final save = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(S.unsavedChanges),
          content: Text(S.unsavedChangesBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(S.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(S.discardChanges),
            ),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(S.save),
            ),
          ],
        ),
      );
      if (save == null) return;
      if (save) {
        await onSave();
      } else {
        navigator.pop();
      }
    },
    child: child,
  );
}

/// Card at the top of the readings screen while any reading is flagged as
/// unusual: a red marker, the count-free label and a chevron into the
/// unusual readings page. Only the hint line can be dismissed, and it comes
/// back the next time the screen is built.
class UnusualCard extends StatelessWidget {
  const UnusualCard({
    super.key,
    required this.hintDismissed,
    required this.onDismissHint,
    required this.onTap,
  });

  final bool hintDismissed;
  final VoidCallback onDismissHint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Material(
        color: AppColors.failed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: AppColors.failed,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        S.unusualReadings,
                        style: const TextStyle(
                          color: AppColors.failed,
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
                if (!hintDismissed) ...[
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          S.unusualBanner,
                          maxLines: 3,
                          style: const TextStyle(fontSize: 12.5, height: 1.4),
                        ),
                      ),
                      SizedBox(
                        height: 28,
                        width: 28,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          tooltip: S.close,
                          onPressed: onDismissHint,
                          icon: const Icon(Icons.close_rounded, size: 16),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
