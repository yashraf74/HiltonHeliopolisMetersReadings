import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';

import '../core/strings.dart';
import '../data/api/api_client.dart';
import '../data/db/database.dart';
import '../data/models.dart';
import '../state/app_status_controller.dart';
import '../state/session_controller.dart';
import 'reading_actions.dart';
import 'screens/meter_form_screen.dart';
import 'screens/user_form_screen.dart';
import 'widgets/status_widgets.dart';

// Popups opened by tapping a meter, user or reading anywhere in the app
// (see TapLink). Each is a bottom sheet with the details, the full photo
// (tap for pinch-zoom) and, for moderators, an edit button.

/// Whether the signed-in user may open user popups: technicians never see
/// other users' details.
bool canViewUsers(BuildContext context) =>
    context.read<SessionController>().user?.role != UserRole.technician;

NetworkImage _photo(BuildContext context, String key) {
  final api = context.read<ApiClient>();
  return NetworkImage(api.photoUri(key).toString(), headers: api.authHeaders);
}

Future<void> _openSheet(BuildContext context, WidgetBuilder builder) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: builder,
    );

/// Meter popup, from the local meter cache (works offline, for every role).
Future<void> showMeterPopup(BuildContext context, String meterId) async {
  final meter = await context.read<AppDatabase>().meterById(meterId);
  if (!context.mounted) return;
  if (meter == null) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(S.meterNotFound)));
    return;
  }
  // The form opens from the page, not the sheet, which is gone by then.
  final canManage = context.read<SessionController>().user?.canManage ?? false;
  await _openSheet(
    context,
    (_) => _MeterSheet(
      meter: meter,
      onEdit: canManage
          ? () => MeterFormScreen.open(context, existing: meter)
          : null,
    ),
  );
}

/// User popup for moderators and engineers; loaded from the server.
Future<void> showUserPopup(BuildContext context, String userId) {
  if (!canViewUsers(context)) return Future.value();
  final canManage = context.read<SessionController>().user?.canManage ?? false;
  return _openSheet(
    context,
    (_) => _UserSheet(
      userId: userId,
      onEdit: canManage
          ? (user) => UserFormScreen.open(context, existing: user)
          : null,
    ),
  );
}

/// Reading popup from a dashboard row that carries the reading's fields
/// (id, value, gain, logged_at, logged_by, meter_id, photo keys...), with
/// edit and delete. [onChanged] runs after either, once the sheet has
/// closed (gains are recomputed on the server, so the caller reloads).
Future<void> showReadingPopup(
  BuildContext context,
  Map<String, dynamic> row, {
  VoidCallback? onChanged,
}) => _openSheet(context, (_) => _ReadingSheet(row: row, onChanged: onChanged));

/// Scrollable sheet body with the standard padding.
class _SheetBody extends StatelessWidget {
  const _SheetBody({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.fromLTRB(
      20,
      0,
      20,
      20 + MediaQuery.viewPaddingOf(context).bottom,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
}

/// Full-width photo that opens the pinch-zoom viewer when tapped.
class _SheetPhoto extends StatelessWidget {
  const _SheetPhoto(this.image);

  final ImageProvider image;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PhotoViewerScreen(image: image),
          fullscreenDialog: true,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: Image(
            image: image,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              color: scheme.surfaceContainerHighest,
              alignment: Alignment.center,
              child: Text(
                S.photoLoadFailed,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.title, this.subtitle, {this.leading});

  final String title;
  final String subtitle;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 12)],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                ),
              ),
              if (subtitle.isNotEmpty)
                Text(
                  subtitle,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EditButton extends StatelessWidget {
  const _EditButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.edit_outlined, size: 18),
      label: Text(S.edit),
    ),
  );
}

String _dateTime(String? iso) {
  final dt = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
  return dt == null
      ? ''
      : DateFormat('d/M/yyyy · HH:mm', S.localeCode).format(dt);
}

// ---- meter ------------------------------------------------------------------

class _MeterSheet extends StatelessWidget {
  const _MeterSheet({required this.meter, this.onEdit});

  final Meter meter;

  /// Moderators only; called after the sheet closes.
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final type = MeterType.fromApi(meter.type);
    final number = meter.number;
    final last = meter.lastValue;
    // The to-do and export orders are moderator-only settings.
    final isModerator =
        context.read<SessionController>().user?.canManage ?? false;
    return _SheetBody(
      children: [
        _Title(
          meter.name,
          meter.area.isEmpty ? type.label : '${type.label} · ${meter.area}',
          leading: MeterTypeBadge(type),
        ),
        const SizedBox(height: 14),
        if (meter.photoKey != null) ...[
          _SheetPhoto(_photo(context, meter.photoKey!)),
          const SizedBox(height: 14),
        ],
        DetailRow(S.meterType, type.label),
        if (meter.area.isNotEmpty) DetailRow(S.meterArea, meter.area),
        if (number != null && number.isNotEmpty)
          DetailRow(S.meterNumber, number),
        if (last != null)
          DetailRow(
            S.lastReading,
            '${NumberFormat.decimalPattern('en').format(last)} ${type.unit}'
            ' · ${_dateTime(meter.lastLoggedAt)}',
          ),
        if (isModerator && meter.todoOrder != null)
          DetailRow(S.todoOrder, '${meter.todoOrder}'),
        if (isModerator && meter.exportOrder != null)
          DetailRow(S.exportOrder, '${meter.exportOrder}'),
        if (onEdit != null)
          _EditButton(
            onPressed: () {
              Navigator.of(context).pop();
              onEdit!();
            },
          ),
      ],
    );
  }
}

// ---- user -------------------------------------------------------------------

class _UserSheet extends StatefulWidget {
  const _UserSheet({required this.userId, this.onEdit});

  final String userId;

  /// Moderators only; called after the sheet closes.
  final void Function(AppUser user)? onEdit;

  @override
  State<_UserSheet> createState() => _UserSheetState();
}

class _UserSheetState extends State<_UserSheet> {
  late final Future<AppUser> _user = context.read<ApiClient>().fetchUser(
    widget.userId,
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppUser>(
      future: _user,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 160,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snap.data;
        if (user == null) {
          return SizedBox(
            height: 140,
            child: Center(
              child: Text(
                snap.error is NetworkException
                    ? S.onlineRequired
                    : S.userLoadFailed,
              ),
            ),
          );
        }
        final phone = user.phone;
        return _SheetBody(
          children: [
            _Title(
              user.fullName,
              '${user.role.label} · @${user.username}',
              // Tap the photo for the full-size, pinch-zoom view.
              leading: UserAvatar(user: user, size: 64, zoomOnTap: true),
            ),
            const SizedBox(height: 14),
            DetailRow(S.email, user.hasEmail ? user.email : S.emailMissing),
            if (phone != null && phone.isNotEmpty) DetailRow(S.phone, phone),
            if (widget.onEdit != null)
              _EditButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onEdit!(user);
                },
              ),
          ],
        );
      },
    );
  }
}

/// Round user photo, or the initial of their name.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.user,
    this.size = 44,
    this.zoomOnTap = false,
  });

  final AppUser user;
  final double size;
  final bool zoomOnTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final key = user.photoKey;
    final image = key == null ? null : _photo(context, key);
    final initial = user.fullName.trim().isEmpty
        ? '?'
        : user.fullName.trim().characters.first;
    final avatar = CircleAvatar(
      radius: size / 2,
      backgroundColor: scheme.primaryContainer,
      foregroundImage: image,
      onForegroundImageError: image == null ? null : (_, _) {},
      child: Text(
        initial,
        style: TextStyle(
          color: scheme.onPrimaryContainer,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.4,
        ),
      ),
    );
    if (!zoomOnTap || image == null) return avatar;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PhotoViewerScreen(image: image),
          fullscreenDialog: true,
        ),
      ),
      child: avatar,
    );
  }
}

// ---- reading ----------------------------------------------------------------

class _ReadingSheet extends StatefulWidget {
  const _ReadingSheet({required this.row, this.onChanged});

  final Map<String, dynamic> row;
  final VoidCallback? onChanged;

  @override
  State<_ReadingSheet> createState() => _ReadingSheetState();
}

class _ReadingSheetState extends State<_ReadingSheet> {
  bool _busy = false;

  Map<String, dynamic> get row => widget.row;

  /// Runs [action]; when it changed the reading, closes the sheet and lets
  /// the caller reload.
  Future<void> _run(Future<bool> Function() action) async {
    setState(() => _busy = true);
    final changed = await action();
    if (!mounted) return;
    setState(() => _busy = false);
    if (changed) {
      Navigator.of(context).pop();
      widget.onChanged?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = MeterType.fromApi(row['type'] as String);
    final value = row['value'] as num;
    final gain = row['gain'] as num?;
    final meterId = row['meter_id'] as String;
    final userId = row['logged_by'] as String?;
    final userName = row['logged_by_name'] as String? ?? '';
    final photoKey = row['reading_photo_key'] as String?;
    final area = row['area'] as String? ?? '';
    final deleteEnabled = context
        .watch<AppStatusController>()
        .config
        .readingDeleteEnabled;
    return _SheetBody(
      children: [
        _Title(
          S.readingDetails,
          _dateTime(row['logged_at'] as String?),
          leading: MeterTypeBadge(type),
        ),
        const SizedBox(height: 14),
        ReadingPhoto(
          image: photoKey == null ? null : _photo(context, photoKey),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            ValueText(value, unit: type.unit, fontSize: 24),
            const SizedBox(width: 10),
            GainText(gain, unit: type.unit, fontSize: 14),
          ],
        ),
        const SizedBox(height: 10),
        DetailRow(
          S.meterName,
          row['name'] as String,
          onTap: () => showMeterPopup(context, meterId),
        ),
        if (area.isNotEmpty) DetailRow(S.meterArea, area),
        if (userName.isNotEmpty)
          DetailRow(
            S.loggedBy,
            userName,
            onTap: userId != null && canViewUsers(context)
                ? () => showUserPopup(context, userId)
                : null,
          ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                        final v = await editReadingValue(
                          context,
                          id: row['id'] as String,
                          current: value,
                        );
                        return v != null;
                      }),
                icon: const Icon(Icons.edit_outlined),
                label: Text(S.editReading),
              ),
            ),
            if (deleteEnabled) ...[
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                    // Same height as the filled edit button beside it.
                    minimumSize: const Size.fromHeight(52),
                  ),
                  onPressed: _busy
                      ? null
                      : () => _run(
                          () => deleteReadingConfirmed(
                            context,
                            row['id'] as String,
                          ),
                        ),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: Text(S.deleteReading),
                ),
              ),
            ],
          ],
        ),
        // Its own row: three buttons side by side squeeze the labels.
        if (row['kind'] != null) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _busy
                ? null
                : () => _run(() async {
                    await context.read<ApiClient>().markReadingNormal(
                      row['id'] as String,
                      normal: true,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(S.markedNormal)));
                    }
                    return true;
                  }),
            icon: const Icon(Icons.check_circle_outline_rounded),
            label: Text(S.markNormal),
          ),
        ],
      ],
    );
  }
}
