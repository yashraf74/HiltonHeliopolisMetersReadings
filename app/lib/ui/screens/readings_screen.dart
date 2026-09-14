import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';

import '../../core/strings.dart';
import '../../data/api/api_client.dart';
import '../../data/db/database.dart';
import '../../data/export/excel_export.dart';
import '../../data/models.dart';
import '../../state/session_controller.dart';
import '../widgets/status_widgets.dart';

class ReadingFilters {
  const ReadingFilters({
    this.type,
    this.floor,
    this.technician = '',
    this.from,
    this.to,
    this.search = '',
  });

  final MeterType? type;
  final int? floor;
  final String technician;
  final DateTime? from;
  final DateTime? to;
  final String search;

  bool get isEmpty =>
      type == null &&
      floor == null &&
      technician.isEmpty &&
      from == null &&
      to == null &&
      search.isEmpty;

  int get activeCount =>
      (type != null ? 1 : 0) +
      (floor != null ? 1 : 0) +
      (technician.isNotEmpty ? 1 : 0) +
      (from != null || to != null ? 1 : 0);

  ReadingFilters copyWith({
    MeterType? type,
    bool clearType = false,
    int? floor,
    bool clearFloor = false,
    String? technician,
    DateTime? from,
    DateTime? to,
    bool clearDates = false,
    String? search,
  }) => ReadingFilters(
    type: clearType ? null : (type ?? this.type),
    floor: clearFloor ? null : (floor ?? this.floor),
    technician: technician ?? this.technician,
    from: clearDates ? null : (from ?? this.from),
    to: clearDates ? null : (to ?? this.to),
    search: search ?? this.search,
  );

  Map<String, String> toQuery() => {
    if (type != null) 'type': type!.name,
    if (floor != null) 'floor': floor.toString(),
    if (technician.isNotEmpty) 'technician': technician,
    if (from != null)
      'dateFrom': DateTime(
        from!.year,
        from!.month,
        from!.day,
      ).toUtc().toIso8601String(),
    if (to != null)
      'dateTo': DateTime(
        to!.year,
        to!.month,
        to!.day,
        23,
        59,
        59,
      ).toUtc().toIso8601String(),
    if (search.isNotEmpty) 'search': search,
  };
}

/// Engineer's server-side list of every reading, with filters and export.
class ReadingsScreen extends StatefulWidget {
  const ReadingsScreen({super.key});

  @override
  State<ReadingsScreen> createState() => _ReadingsScreenState();
}

class _ReadingsScreenState extends State<ReadingsScreen> {
  ReadingFilters _filters = const ReadingFilters();
  final _search = TextEditingController();
  final _scroll = ScrollController();
  List<Map<String, dynamic>> _rows = const [];
  String? _nextCursor;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final nearBottom =
        _scroll.position.pixels >= _scroll.position.maxScrollExtent - 400;
    if (nearBottom) _loadMore();
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

  /// First page for the current filters (also used by pull-to-refresh).
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _nextCursor = null;
    });
    try {
      final page = await context.read<ApiClient>().fetchReadings(
        _filters.toQuery(),
      );
      if (!mounted) return;
      setState(() {
        _rows = page.rows;
        _nextCursor = page.nextCursor;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _handleError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    final cursor = _nextCursor;
    if (cursor == null || _loadingMore || _loading) return;
    setState(() => _loadingMore = true);
    try {
      final page = await context.read<ApiClient>().fetchReadings(
        _filters.toQuery(),
        cursor: cursor,
      );
      if (!mounted) return;
      setState(() {
        _rows = [..._rows, ...page.rows];
        _nextCursor = page.nextCursor;
      });
    } catch (e) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
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

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<ReadingFilters>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _FilterSheet(initial: _filters),
    );
    if (result == null) return;
    setState(() => _filters = result);
    _load();
  }

  /// Exports every reading matching the current filters, not just the pages
  /// loaded so far.
  Future<void> _export() async {
    if (_rows.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text(S.exportNothing)));
      return;
    }
    setState(() => _exporting = true);
    final messenger = ScaffoldMessenger.of(context);
    final api = context.read<ApiClient>();
    try {
      final all = _nextCursor == null
          ? _rows
          : await api.fetchAllReadings(_filters.toQuery());
      final bytes = buildReadingsWorkbook(all);
      final stamp = DateFormat('yyyy-MM-dd_HHmm').format(DateTime.now());
      final saved = await FilePicker.saveFile(
        dialogTitle: S.exportExcel,
        fileName: 'meter-readings-$stamp.xlsx',
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        type: FileType.custom,
        allowedExtensions: const ['xlsx'],
        bytes: bytes,
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text(saved == null ? S.exportCancelled : S.exportDone),
        ),
      );
    } on NetworkException {
      messenger.showSnackBar(
        const SnackBar(content: Text(S.readingsNeedInternet)),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('${S.exportFailed}: $e')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
              const SizedBox(width: 8),
              Badge(
                isLabelVisible: _filters.activeCount > 0,
                label: Text('${_filters.activeCount}'),
                child: IconButton.filledTonal(
                  tooltip: S.filters,
                  onPressed: _openFilters,
                  icon: const Icon(Icons.tune_rounded),
                ),
              ),
              IconButton.filledTonal(
                tooltip: S.exportExcel,
                onPressed: _exporting || _loading ? null : _export,
                icon: _exporting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.table_view_rounded),
              ),
            ],
          ),
        ),
        if (!_filters.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  '${S.readingsCount}: ${_rows.length}${_nextCursor != null ? '+' : ''}',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12.5,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    _search.clear();
                    setState(() => _filters = const ReadingFilters());
                    _load();
                  },
                  icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                  label: const Text(S.clearFilters),
                ),
              ],
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 100),
                      EmptyState(icon: Icons.cloud_off_rounded, title: _error!),
                      Center(
                        child: TextButton(
                          onPressed: _load,
                          child: const Text(S.retry),
                        ),
                      ),
                    ],
                  )
                : _rows.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 100),
                      EmptyState(
                        icon: Icons.list_alt_rounded,
                        title: S.noReadingsMatch,
                      ),
                    ],
                  )
                : ListView.separated(
                    controller: _scroll,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: _rows.length + (_nextCursor != null ? 1 : 0),
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      if (i == _rows.length) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                S.loadingMore,
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return _ReadingCard(
                        row: _rows[i],
                        onDeleted: () =>
                            setState(() => _rows = [..._rows]..removeAt(i)),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class _ReadingCard extends StatefulWidget {
  const _ReadingCard({required this.row, required this.onDeleted});

  final Map<String, dynamic> row;
  final VoidCallback onDeleted;

  @override
  State<_ReadingCard> createState() => _ReadingCardState();
}

class _ReadingCardState extends State<_ReadingCard> {
  bool _deleting = false;

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(S.deleteReading),
        content: const Text(S.deleteReadingConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(S.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              minimumSize: const Size(0, 44),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(S.deleteReading),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleting = true);
    final messenger = ScaffoldMessenger.of(context);
    final id = widget.row['id'] as String;
    try {
      await context.read<ApiClient>().deleteReading(id);
      // If the engineer logged it on this device, drop the local copy too.
      if (mounted) await context.read<AppDatabase>().deleteReading(id);
      messenger.showSnackBar(const SnackBar(content: Text(S.readingDeleted)));
      widget.onDeleted();
    } on NetworkException {
      messenger.showSnackBar(
        const SnackBar(content: Text(S.deleteNeedsInternet)),
      );
    } on ApiException catch (e) {
      if (e.isUnauthorized && mounted) {
        context.read<SessionController>().markTokenRejected();
      }
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
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
    final fmt = DateFormat('d/M/yyyy · HH:mm', 'ar');
    final api = context.read<ApiClient>();
    final value = NumberFormat.decimalPattern('en').format(row['value'] as num);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: MeterTypeBadge(type, compact: true),
          title: Text(
            row['meter_location'] as String,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            '${row['logged_by_name']} · ${fmt.format(loggedAt)}',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
          ),
          trailing: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DetailRow(S.meterType, type.label),
                  DetailRow(S.meterFloor, '${row['meter_floor']}'),
                  if ((row['meter_description'] as String?)?.isNotEmpty == true)
                    DetailRow(
                      S.meterDescription,
                      row['meter_description'] as String,
                    ),
                  DetailRow(S.loggedBy, row['logged_by_name'] as String),
                  DetailRow(S.loggedAt, fmt.format(loggedAt)),
                  if (syncedAt != null)
                    DetailRow(S.syncedAtLabel, fmt.format(syncedAt)),
                  DetailRow(S.readingId, row['id'] as String, mono: true),
                  NotesBlock(row['notes'] as String?),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio: 4 / 3,
                      child: Image.network(
                        api.photoUri(row['photo_key'] as String).toString(),
                        headers: api.authHeaders,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) =>
                            progress == null
                            ? child
                            : Container(
                                color: scheme.surfaceContainerHighest,
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                        errorBuilder: (context, _, _) => Container(
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
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        backgroundColor: scheme.errorContainer,
                        foregroundColor: scheme.onErrorContainer,
                        minimumSize: const Size.fromHeight(44),
                      ),
                      onPressed: _deleting ? null : _delete,
                      icon: _deleting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.delete_outline_rounded),
                      label: const Text(S.deleteReading),
                    ),
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

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.initial});

  final ReadingFilters initial;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late ReadingFilters _f = widget.initial;
  late final _floor = TextEditingController(
    text: widget.initial.floor?.toString() ?? '',
  );
  late final _tech = TextEditingController(text: widget.initial.technician);

  @override
  void dispose() {
    _floor.dispose();
    _tech.dispose();
    super.dispose();
  }

  Future<void> _pickDates() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _f.from != null && _f.to != null
          ? DateTimeRange(start: _f.from!, end: _f.to!)
          : null,
    );
    if (range == null) return;
    setState(() => _f = _f.copyWith(from: range.start, to: range.end));
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d/M/yyyy', 'ar');
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.filters,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          Text(
            S.filterType,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text(S.filterAllTypes),
                selected: _f.type == null,
                onSelected: (_) =>
                    setState(() => _f = _f.copyWith(clearType: true)),
              ),
              for (final t in MeterType.values)
                ChoiceChip(
                  label: Text(t.label),
                  avatar: Icon(
                    t.icon,
                    size: 18,
                    color: _f.type == t ? Colors.white : t.color,
                  ),
                  selected: _f.type == t,
                  selectedColor: t.color,
                  labelStyle: TextStyle(
                    color: _f.type == t ? Colors.white : null,
                  ),
                  onSelected: (_) => setState(() => _f = _f.copyWith(type: t)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _floor,
                  keyboardType: const TextInputType.numberWithOptions(
                    signed: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[-0-9]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: S.filterFloor,
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _tech,
                  decoration: const InputDecoration(
                    labelText: S.filterTechnician,
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            S.filterDateRange,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDates,
                  icon: const Icon(Icons.date_range_rounded),
                  label: Text(
                    _f.from == null
                        ? S.pickDates
                        : '${fmt.format(_f.from!)} – ${fmt.format(_f.to ?? _f.from!)}',
                  ),
                ),
              ),
              if (_f.from != null)
                IconButton(
                  onPressed: () =>
                      setState(() => _f = _f.copyWith(clearDates: true)),
                  icon: const Icon(Icons.close_rounded),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () =>
                      Navigator.pop(context, const ReadingFilters()),
                  child: const Text(S.clearFilters),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    final floorText = _floor.text.trim();
                    Navigator.pop(
                      context,
                      ReadingFilters(
                        type: _f.type,
                        floor: floorText.isEmpty
                            ? null
                            : int.tryParse(floorText),
                        technician: _tech.text.trim(),
                        from: _f.from,
                        to: _f.to,
                        search: widget.initial.search,
                      ),
                    );
                  },
                  child: const Text(S.applyFilters),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
