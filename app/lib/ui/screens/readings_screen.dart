import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';

import '../../core/strings.dart';
import '../../data/api/api_client.dart';
import '../../data/db/database.dart';
import '../../data/export/excel_export.dart';
import '../../data/models.dart';
import '../../data/photo_store.dart';
import '../../state/app_status_controller.dart';
import '../../state/session_controller.dart';
import '../../state/sync_controller.dart';
import '../../state/app_events.dart';
import '../popups.dart';
import 'reading_filters.dart';
import 'unusual_screen.dart';
import '../reading_actions.dart';
import '../widgets/status_widgets.dart';

/// Server-backed readings list for every role. Technicians see their own
/// readings (the server scopes them); moderators and engineers see all.
/// Readings still queued on this device are pinned at the top.
class ReadingsScreen extends StatefulWidget {
  const ReadingsScreen({super.key});

  @override
  State<ReadingsScreen> createState() => _ReadingsScreenState();
}

class _ReadingsScreenState extends State<ReadingsScreen> {
  ReadingFilters _filters = const ReadingFilters();
  final _search = TextEditingController();
  final _scroll = ScrollController();
  // Held from initState: providers can't be looked up during dispose.
  late final AppEvents _events;
  List<Map<String, dynamic>> _rows = const [];
  String? _nextCursor;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  bool _exporting = false;
  List<UserName> _userNames = const [];

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _events = context.read<AppEvents>();
    _events.addListener(_onUsersChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // _load() re-checks the unusual card once the list is in.
      _load();
      _loadUserNames();
    });
  }

  @override
  void dispose() {
    _events.removeListener(_onUsersChanged);
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) {
      return;
    }
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  /// A moderator may have added, removed or hidden an account; a reading may
  /// have stopped being unusual.
  void _onUsersChanged() {
    _loadUserNames();
    _loadUnusualCount();
  }

  /// Unusual readings among the readings currently filtered for, so the
  /// card follows the list: it goes away when nothing matching is flagged.
  int _unusualTotal = 0;

  Future<void> _loadUnusualCount() async {
    final user = context.read<SessionController>().user;
    if (user == null || !user.canSeeAllReadings) return;
    final asked = _filters;
    try {
      final result = await context.read<ApiClient>().fetchUnusual(
        asked.toQuery(),
      );
      // A later filter change may have already asked again; ignore the
      // answer to the older question.
      if (mounted && identical(asked, _filters)) {
        setState(() => _unusualTotal = result.count);
      }
    } catch (_) {
      // Offline or refused: the card just stays as it is.
    }
  }

  Future<void> _loadUserNames() async {
    final user = context.read<SessionController>().user;
    if (user == null || !user.canSeeAllReadings) {
      return;
    }
    try {
      final names = await context.read<ApiClient>().fetchUserNames();
      if (mounted) setState(() => _userNames = names);
    } catch (_) {
      // The dropdown just stays empty; not worth surfacing.
    }
  }

  void _handleError(Object e) {
    if (e is NetworkException) {
      _error = S.readingsNeedInternet;
    } else if (e is ApiException) {
      if (e.isUnauthorized) {
        context.read<SessionController>().markTokenRejected();
      }
      _error = '${S.loadFailed}: ${e.message}';
    } else {
      _error = S.loadFailed;
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _nextCursor = null;
    });
    try {
      final page = await context.read<ApiClient>().fetchReadings(
        _filters.toReadingsQuery(),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _rows = page.rows;
        _nextCursor = page.nextCursor;
      });
      _loadUnusualCount();
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _handleError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    final cursor = _nextCursor;
    if (cursor == null || _loadingMore || _loading) {
      return;
    }
    setState(() => _loadingMore = true);
    try {
      final page = await context.read<ApiClient>().fetchReadings(
        _filters.toReadingsQuery(),
        cursor: cursor,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _rows = [..._rows, ...page.rows];
        _nextCursor = page.nextCursor;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is NetworkException ? S.readingsNeedInternet : S.loadFailed,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  /// The unusual readings page starts from this list's filters, then keeps
  /// its own: what happens there never changes the filters here.
  Future<void> _openUnusual() async {
    await UnusualScreen.open(context, filters: _filters);
    // Readings may have been edited or deleted over there; _load() also
    // re-checks the card.
    if (mounted) _load();
  }

  Future<void> _openFilters(bool showUser) async {
    final result = await showModalBottomSheet<ReadingFilters>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => ReadingFilterSheet(
        initial: _filters,
        showUser: showUser,
        users: _userNames,
      ),
    );
    if (result == null) {
      return;
    }
    setState(() => _filters = result);
    // "Clear filters" in the sheet drops the search term as well.
    if (_search.text != result.search) _search.text = result.search;
    _load();
  }

  Future<void> _openSort(bool showUser) async {
    final result = await showModalBottomSheet<ReadingFilters>(
      context: context,
      // Without this the sheet is capped at 9/16 of the screen, which cut
      // off the apply button on shorter screens or with larger system text.
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => ReadingSortSheet(initial: _filters, showUser: showUser),
    );
    if (result == null) {
      return;
    }
    setState(() => _filters = result);
    _load();
  }

  /// Exports every reading matching the current filters (not just the pages
  /// loaded so far), then saves the file on the device, emails it to the
  /// user, or both, as they choose.
  /// Warns moderators and engineers when the readings they're about to
  /// export contain unusual ones, offering to review them on the dashboard
  /// (with the same period applied). Returns false to stop the export.
  Future<bool> _confirmUnusual() async {
    final user = context.read<SessionController>().user;
    final config = context.read<AppStatusController>().config;
    if (user == null ||
        !user.canSeeAllReadings ||
        !config.exportUnusualWarningEnabled) {
      return true;
    }
    final int count;
    try {
      // The very query the export itself runs, so the warning can't miss
      // readings the file will contain.
      count = (await context.read<ApiClient>().fetchUnusual(_filters.toQuery()))
          .count;
    } catch (_) {
      // Can't check (offline, say): don't stand in the way of the export.
      return true;
    }
    if (count == 0 || !mounted) return true;

    final choice = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.unusualBeforeExport),
        content: Text(S.unusualBeforeExportBody(count)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(S.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(S.exportAnyway),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(S.reviewUnusual),
          ),
        ],
      ),
    );
    if (choice == true) return true;
    if (choice == false && mounted) {
      // Review: the same readings the export would have covered.
      await _openUnusual();
    }
    return false;
  }

  Future<void> _export() async {
    if (_rows.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(S.exportNothing)));
      return;
    }
    if (!await _confirmUnusual() || !mounted) return;
    final target = await showModalBottomSheet<_ExportTarget>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const _ExportTargetSheet(),
    );
    if (target == null || !mounted) return;

    setState(() => _exporting = true);
    final messenger = ScaffoldMessenger.of(context);
    final api = context.read<ApiClient>();
    final exportSettings = context.read<AppStatusController>().config.export;
    final results = <String>[];
    try {
      final all = await api.fetchAllReadings(_filters.toReadingsQuery());
      final bytes = buildReadingsWorkbook(all, settings: exportSettings);
      final stamp = DateFormat('yyyy-MM-dd_HHmm').format(DateTime.now());
      final fileName = 'meter-readings-$stamp.xlsx';

      if (target != _ExportTarget.email) {
        final saved = await FilePicker.saveFile(
          dialogTitle: S.exportExcel,
          fileName: fileName,
          mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          type: FileType.custom,
          allowedExtensions: const ['xlsx'],
          bytes: bytes,
        );
        results.add(saved == null ? S.exportCancelled : S.exportDone);
      }
      if (target != _ExportTarget.device) {
        try {
          final sentTo = await api.emailExport(fileName, bytes);
          results.add('${S.exportEmailed} $sentTo');
        } on ApiException catch (e) {
          results.add(switch (e.code) {
            'no_email' => S.exportNoEmail,
            'email_not_configured' => S.exportEmailNotConfigured,
            'export_disabled' => S.exportDisabledByAdmin,
            _ => S.exportEmailFailed,
          });
        }
      }
    } on NetworkException {
      results.add(S.readingsNeedInternet);
    } on ApiException catch (e) {
      results.add(
        e.code == 'export_disabled' ? S.exportDisabledByAdmin : e.message,
      );
    } catch (e) {
      results.add('${S.exportFailed}: $e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
    messenger.showSnackBar(SnackBar(content: Text(results.join('\n'))));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final user = context.watch<SessionController>().user!;
    final isAdmin = user.canSeeAllReadings;
    final config = context.watch<AppStatusController>().config;
    final db = context.read<AppDatabase>();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  textInputAction: TextInputAction.search,
                  contextMenuBuilder: appContextMenuBuilder,
                  onSubmitted: (v) {
                    setState(
                      () => _filters = _filters.copyWith(search: v.trim()),
                    );
                    _load();
                  },
                  decoration: InputDecoration(
                    hintText: S.searchReadings,
                    isDense: true,
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () {
                              _search.clear();
                              setState(
                                () => _filters = _filters.copyWith(search: ''),
                              );
                              _load();
                            },
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Badge(
                isLabelVisible: !_filters.isDefaultSort,
                child: IconButton.filledTonal(
                  tooltip: S.sort,
                  onPressed: () => _openSort(isAdmin),
                  icon: const Icon(Icons.swap_vert_rounded),
                ),
              ),
              Badge(
                isLabelVisible: _filters.hasActiveFilters,
                child: IconButton.filledTonal(
                  tooltip: S.filters,
                  onPressed: () => _openFilters(isAdmin),
                  icon: const Icon(Icons.tune_rounded),
                ),
              ),
              if (isAdmin && config.exportEnabled)
                IconButton.filledTonal(
                  tooltip: S.exportExcel,
                  onPressed: _exporting || _loading ? null : _export,
                  icon: _exporting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.ios_share_rounded),
                ),
            ],
          ),
        ),
        if (!_filters.isEmpty || !_filters.isDefaultSort)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${S.readingsCount}: ${_rows.length}${_nextCursor != null ? '+' : ''}'
                    ' · ${S.sortBy}: ${_filters.sort.label} ${_filters.descending ? '↓' : '↑'}',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    _search.clear();
                    setState(() => _filters = const ReadingFilters());
                    _load();
                  },
                  icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                  label: Text(S.clearFilters),
                ),
              ],
            ),
          ),
        // Below the filters and above the list, and outside it: the card
        // stays put while the readings scroll.
        if (_unusualTotal > 0) UnusualCard(onTap: _openUnusual),
        Expanded(
          child: StreamBuilder<List<Reading>>(
            stream: db.watchQueue(user.id),
            builder: (context, queueSnap) {
              final queue = queueSnap.data ?? const <Reading>[];
              return RefreshIndicator(
                onRefresh: _load,
                child: _buildBody(queue, config.readingDeleteEnabled, scheme),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBody(List<Reading> queue, bool canDelete, ColorScheme scheme) {
    final header = queue.isEmpty ? 0 : queue.length + 1;
    final footer = _nextCursor != null ? 1 : 0;

    if (_loading && queue.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final showError = !_loading && _error != null;
    final showEmpty = !_loading && _error == null && _rows.isEmpty;
    final serverCount = showError || showEmpty || _loading ? 1 : _rows.length;

    return ListView.separated(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: header + serverCount + footer,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        if (header > 0 && i == 0) {
          return Text(
            S.pendingSection,
            style: TextStyle(
              color: SyncStatus.pending.color,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          );
        }
        if (i < header) {
          return _PendingReadingCard(reading: queue[i - 1]);
        }
        final j = i - header;
        if (j == serverCount) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Text(
                  S.loadingMore,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          );
        }
        if (_loading) {
          return const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (showError) {
          return Column(
            children: [
              const SizedBox(height: 40),
              EmptyState(icon: Icons.cloud_off_rounded, title: _error!),
              TextButton(onPressed: _load, child: Text(S.retry)),
            ],
          );
        }
        if (showEmpty) {
          return Padding(
            padding: EdgeInsets.only(top: 40),
            child: EmptyState(
              icon: Icons.list_alt_rounded,
              title: S.noReadingsMatch,
            ),
          );
        }
        return _ReadingCard(
          row: _rows[j],
          canDelete: canDelete,
          onDeleted: () => setState(() => _rows = [..._rows]..removeAt(j)),
          onValueChanged: (v) => setState(() {
            final copy = [..._rows];
            copy[j] = {...copy[j], 'value': v};
            _rows = copy;
          }),
        );
      },
    );
  }
}

// ---- pending (local) card --------------------------------------------------

class _PendingReadingCard extends StatelessWidget {
  const _PendingReadingCard({required this.reading});

  final Reading reading;

  Future<(Meter?, File?)> _load(AppDatabase db) async => (
    await db.meterById(reading.meterId),
    await PhotoStore.resolve(reading.localPhotoPath),
  );

  Future<void> _discard(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.deleteLocalReading),
        content: Text(S.deleteLocalReadingConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(S.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              minimumSize: const Size(0, 44),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(S.deleteReading),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<SyncController>().discard(reading);
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = context.read<AppDatabase>();
    final scheme = Theme.of(context).colorScheme;
    final status = SyncStatus.fromDb(reading.syncStatus);
    final fmt = DateFormat('d/M/yyyy · HH:mm', S.localeCode);
    final loggedAt = DateTime.parse(reading.loggedAt).toLocal();

    return FutureBuilder<(Meter?, File?)>(
      future: _load(db),
      builder: (context, snap) {
        final meter = snap.data?.$1;
        final photo = snap.data?.$2;
        final type = meter != null
            ? MeterType.fromApi(meter.type)
            : MeterType.electricity;
        final image = photo != null ? FileImage(photo) : null;
        return Card(
          clipBehavior: Clip.antiAlias,
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 4,
              ),
              leading: PhotoThumb(type: type, image: image),
              title: Text(
                meter?.name ?? reading.meterId,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                fmt.format(loggedAt),
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 12.5,
                ),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ValueText(reading.value, unit: type.unit),
                  const SizedBox(height: 2),
                  SyncStatusChip(status),
                ],
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (meter != null) ...[
                        DetailRow(
                          S.meterName,
                          meter.name,
                          onTap: () => showMeterPopup(context, meter.id),
                        ),
                        DetailRow(S.meterType, type.label),
                        DetailRow(S.meterArea, meter.area),
                        if (meter.number?.isNotEmpty == true)
                          DetailRow(S.meterNumber, meter.number!),
                      ],
                      DetailRow(S.loggedAt, fmt.format(loggedAt)),
                      DetailRow(S.readingId, reading.id, mono: true),
                      if (status == SyncStatus.failed) ...[
                        const SizedBox(height: 8),
                        Text(
                          '${S.lastErrorLabel}: ${reading.lastError ?? '—'}',
                          style: TextStyle(color: scheme.error, fontSize: 12.5),
                        ),
                      ],
                      const SizedBox(height: 12),
                      ReadingPhoto(image: image),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (status == SyncStatus.failed)
                            Expanded(
                              child: FilledButton.tonalIcon(
                                onPressed: () => context
                                    .read<SyncController>()
                                    .retry(reading.id),
                                icon: const Icon(Icons.refresh_rounded),
                                label: Text(S.retrySync),
                              ),
                            ),
                          if (status == SyncStatus.failed)
                            const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton.tonalIcon(
                              style: FilledButton.styleFrom(
                                backgroundColor: scheme.errorContainer,
                                foregroundColor: scheme.onErrorContainer,
                              ),
                              onPressed: () => _discard(context),
                              icon: const Icon(Icons.delete_outline_rounded),
                              label: Text(S.deleteReading),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ---- server card -----------------------------------------------------------

class _ReadingCard extends StatefulWidget {
  const _ReadingCard({
    required this.row,
    required this.canDelete,
    required this.onDeleted,
    required this.onValueChanged,
  });

  final Map<String, dynamic> row;
  final bool canDelete;
  final VoidCallback onDeleted;
  final ValueChanged<double> onValueChanged;

  @override
  State<_ReadingCard> createState() => _ReadingCardState();
}

class _ReadingCardState extends State<_ReadingCard> {
  bool _busy = false;

  Future<void> _edit() async {
    setState(() => _busy = true);
    final value = await editReadingValue(
      context,
      id: widget.row['id'] as String,
      current: widget.row['value'] as num,
    );
    if (value != null) widget.onValueChanged(value);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _delete() async {
    setState(() => _busy = true);
    final deleted = await deleteReadingConfirmed(
      context,
      widget.row['id'] as String,
    );
    if (deleted) widget.onDeleted();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final type = MeterType.fromApi(row['meter_type'] as String);
    final scheme = Theme.of(context).colorScheme;
    final loggedAt = DateTime.parse(row['logged_at'] as String).toLocal();
    final syncedAt = row['synced_at'] != null
        ? DateTime.parse(row['synced_at'] as String).toLocal()
        : null;
    final fmt = DateFormat('d/M/yyyy · HH:mm', S.localeCode);
    final api = context.read<ApiClient>();
    final photoKey = row['photo_key'] as String?;
    final image = photoKey == null
        ? null
        : NetworkImage(
            api.photoUri(photoKey).toString(),
            headers: api.authHeaders,
          );
    final gain = row['gain'] as num?;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: PhotoThumb(type: type, image: image),
          title: Text(
            row['meter_name'] as String,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            '${row['logged_by_name']} · ${fmt.format(loggedAt)}',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ValueText(row['value'] as num, unit: type.unit),
              GainText(gain),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DetailRow(
                    S.meterName,
                    (row['meter_name'] as String?) ?? '',
                    onTap: () =>
                        showMeterPopup(context, row['meter_id'] as String),
                  ),
                  DetailRow(S.meterType, type.label),
                  DetailRow(S.meterArea, (row['meter_area'] as String?) ?? ''),
                  DetailRow(
                    S.loggedBy,
                    row['logged_by_name'] as String,
                    onTap: canViewUsers(context)
                        ? () =>
                              showUserPopup(context, row['logged_by'] as String)
                        : null,
                  ),
                  DetailRow(S.loggedAt, fmt.format(loggedAt)),
                  if (syncedAt != null)
                    DetailRow(S.syncedAtLabel, fmt.format(syncedAt)),
                  const SizedBox(height: 12),
                  ReadingPhoto(image: image),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: _busy ? null : _edit,
                          icon: const Icon(Icons.edit_outlined),
                          label: Text(S.editReading),
                        ),
                      ),
                      if (widget.canDelete) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.tonalIcon(
                            style: FilledButton.styleFrom(
                              backgroundColor: scheme.errorContainer,
                              foregroundColor: scheme.onErrorContainer,
                            ),
                            onPressed: _busy ? null : _delete,
                            icon: _busy
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.delete_outline_rounded),
                            label: Text(S.deleteReading),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---- export target ---------------------------------------------------------

enum _ExportTarget { device, email, both }

class _ExportTargetSheet extends StatelessWidget {
  const _ExportTargetSheet();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Watched, not read: the moment an email is added or removed (here or
    // by a moderator, picked up by the startup refresh), the two email
    // options follow.
    final user = context.watch<SessionController>().user;
    final email = user?.email;
    final canEmail = user?.hasEmail ?? false;
    Widget option(_ExportTarget target, IconData icon, String title) {
      final enabled = target == _ExportTarget.device || canEmail;
      return ListTile(
        enabled: enabled,
        leading: Icon(
          icon,
          color: enabled ? scheme.primary : scheme.onSurfaceVariant,
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          enabled
              ? switch (target) {
                  _ExportTarget.device => S.exportDeviceHint,
                  _ExportTarget.email => S.exportEmailHint(email),
                  _ExportTarget.both => S.exportBothHint(email),
                }
              : S.emailNeededForExport,
        ),
        onTap: enabled ? () => Navigator.pop(context, target) : null,
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        12,
        0,
        12,
        16 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Text(
              S.exportHow,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          option(
            _ExportTarget.device,
            Icons.download_rounded,
            S.exportToDevice,
          ),
          option(_ExportTarget.email, Icons.email_outlined, S.exportToEmail),
          option(_ExportTarget.both, Icons.all_inbox_outlined, S.exportToBoth),
        ],
      ),
    );
  }
}
