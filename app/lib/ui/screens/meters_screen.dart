import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/strings.dart';
import '../../data/api/api_client.dart';
import '../../data/db/database.dart';
import '../../data/models.dart';
import '../../state/meters_controller.dart';
import '../popups.dart';
import '../widgets/status_widgets.dart';
import 'meter_form_screen.dart';

/// Moderator's meter list from the local cache, filterable by type and
/// sortable. Tapping a meter opens its popup (with edit); add via the button.
class MetersScreen extends StatefulWidget {
  const MetersScreen({super.key});

  @override
  State<MetersScreen> createState() => _MetersScreenState();
}

/// Sort options for the meter management list. Meter numbers compare
/// numerically when both are numbers.
enum MeterSort {
  todoOrder,
  exportOrder,
  name,
  area,
  number;

  String get label => switch (this) {
    todoOrder => S.todoOrder,
    exportOrder => S.exportOrder,
    name => S.meterName,
    area => S.meterArea,
    number => S.meterNumber,
  };

  int compare(Meter a, Meter b) => switch (this) {
    todoOrder => _compareNullable(a.todoOrder, b.todoOrder),
    exportOrder => _compareNullable(a.exportOrder, b.exportOrder),
    name => _compareText(a.name, b.name),
    area => _compareText(a.area, b.area),
    number => _compareNumber(a.number, b.number),
  };

  // Empty values are ranked separately (see _sorted), so these only order
  // two present values.
  static int _compareNullable(int? a, int? b) =>
      a == null || b == null ? 0 : a.compareTo(b);

  static int _compareText(String a, String b) =>
      a.toLowerCase().compareTo(b.toLowerCase());

  static int _compareNumber(String? a, String? b) {
    final na = int.tryParse(a ?? '');
    final nb = int.tryParse(b ?? '');
    if (na != null && nb != null) return na.compareTo(nb);
    return _compareText(a ?? '', b ?? '');
  }
}

class _MetersScreenState extends State<MetersScreen> {
  MeterType? _filter;
  MeterSort _sort = MeterSort.todoOrder;
  bool _descending = false;

  /// Empty values stay last in both directions; ties fall back to the name.
  List<Meter> _sorted(List<Meter> meters) {
    int emptyRank(Meter m) => switch (_sort) {
      MeterSort.todoOrder => m.todoOrder == null ? 1 : 0,
      MeterSort.exportOrder => m.exportOrder == null ? 1 : 0,
      MeterSort.name => m.name.isEmpty ? 1 : 0,
      MeterSort.area => m.area.isEmpty ? 1 : 0,
      MeterSort.number => (m.number ?? '').isEmpty ? 1 : 0,
    };
    return [...meters]..sort((a, b) {
      final empty = emptyRank(a) - emptyRank(b);
      if (empty != 0) return empty;
      final c = _sort.compare(a, b);
      if (c != 0) return _descending ? -c : c;
      return MeterSort.name.compare(a, b);
    });
  }

  Future<void> _openSort() async {
    final result = await showModalBottomSheet<(MeterSort, bool)>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _MeterSortSheet(sort: _sort, descending: _descending),
    );
    if (result == null) return;
    setState(() {
      _sort = result.$1;
      _descending = result.$2;
    });
  }

  Future<void> _refresh(BuildContext context) async {
    final ok = await context.read<MetersController>().refresh();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? S.metersRefreshed : S.metersRefreshFailed)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = context.read<AppDatabase>();
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => MeterFormScreen.open(context),
        icon: const Icon(Icons.add_rounded),
        label: Text(S.addMeter),
      ),
      body: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 8, 4),
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: Text(S.filterAll),
                        selected: _filter == null,
                        onSelected: (_) => setState(() => _filter = null),
                      ),
                      for (final t in MeterType.values) ...[
                        const SizedBox(width: 8),
                        TypeChip(
                          type: t,
                          selected: _filter == t,
                          onSelected: (_) => setState(() => _filter = t),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                // Same 16 from the edge as the readings screen's buttons.
                padding: const EdgeInsetsDirectional.only(end: 16, top: 6),
                child: IconButton.filledTonal(
                  tooltip: S.sortBy,
                  onPressed: _openSort,
                  icon: const Icon(Icons.swap_vert_rounded),
                ),
              ),
            ],
          ),
          Expanded(
            child: StreamBuilder<List<Meter>>(
              stream: db.watchActiveMeters(type: _filter?.name),
              builder: (context, snapshot) {
                final meters = _sorted(snapshot.data ?? const <Meter>[]);
                return RefreshIndicator(
                  onRefresh: () => _refresh(context),
                  child: meters.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            const SizedBox(height: 100),
                            EmptyState(
                              icon: _filter?.icon ?? Icons.speed_rounded,
                              title: _filter == null
                                  ? S.noMeters
                                  : S.noMetersForFilter,
                              body: _filter == null ? S.noMetersHint : null,
                            ),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                          itemCount: meters.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, i) => MeterTile(
                            meter: meters[i],
                            onTap: () => showMeterPopup(context, meters[i].id),
                          ),
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared meter row: the reference photo (with the type icon in the
/// corner) when the meter has one, otherwise the plain type badge. Tapping
/// the photo opens the meter popup (full photo, pinch-zoom) unless
/// [photoOpensPopup] is false, when it does the same as [onTap] (the daily
/// reading list, where any tap starts a reading). [doneToday] shows the
/// daily to-do tick in the reading flow.
class MeterTile extends StatelessWidget {
  const MeterTile({
    super.key,
    required this.meter,
    this.onTap,
    this.doneToday,
    this.photoOpensPopup = true,
  });

  final Meter meter;
  final VoidCallback? onTap;
  final bool? doneToday;
  final bool photoOpensPopup;

  @override
  Widget build(BuildContext context) {
    final type = MeterType.fromApi(meter.type);
    final scheme = Theme.of(context).colorScheme;
    final api = context.read<ApiClient>();
    final photoKey = meter.photoKey;
    final number = meter.number;
    final done = doneToday;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              GestureDetector(
                onTap: photoOpensPopup
                    ? () => showMeterPopup(context, meter.id)
                    : onTap,
                child: PhotoThumb(
                  type: type,
                  size: 52,
                  image: photoKey == null
                      ? null
                      : NetworkImage(
                          api.photoUri(photoKey).toString(),
                          headers: api.authHeaders,
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meter.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${meter.area}'
                      '${number?.isNotEmpty == true ? ' · ${S.meterNumber} $number' : ''}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                    if (done != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        done ? S.doneToday : S.notDoneToday,
                        style: TextStyle(
                          color: done
                              ? SyncStatus.synced.color
                              : SyncStatus.pending.color,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (done != null)
                Icon(
                  done
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: done ? SyncStatus.synced.color : scheme.outline,
                  size: 26,
                )
              else if (onTap != null)
                Icon(Icons.chevron_left_rounded, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}

/// Field + direction picker for the meter list; pops `(sort, descending)`.
class _MeterSortSheet extends StatefulWidget {
  const _MeterSortSheet({required this.sort, required this.descending});

  final MeterSort sort;
  final bool descending;

  @override
  State<_MeterSortSheet> createState() => _MeterSortSheetState();
}

class _MeterSortSheetState extends State<_MeterSortSheet> {
  late MeterSort _sort = widget.sort;
  late bool _desc = widget.descending;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        24 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.sortBy,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          RadioGroup<MeterSort>(
            groupValue: _sort,
            onChanged: (v) => setState(() => _sort = v!),
            child: Column(
              children: [
                for (final s in MeterSort.values)
                  RadioListTile<MeterSort>(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(s.label),
                    value: s,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                  value: false,
                  label: Text(S.sortAsc),
                  icon: Icon(Icons.arrow_upward_rounded, size: 16),
                ),
                ButtonSegment(
                  value: true,
                  label: Text(S.sortDesc),
                  icon: Icon(Icons.arrow_downward_rounded, size: 16),
                ),
              ],
              selected: {_desc},
              onSelectionChanged: (s) => setState(() => _desc = s.first),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => Navigator.pop(context, (_sort, _desc)),
            child: Text(S.applyFilters),
          ),
        ],
      ),
    );
  }
}
