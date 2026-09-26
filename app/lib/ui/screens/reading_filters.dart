import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../core/config.dart';
import '../../core/strings.dart';
import '../../data/models.dart';
import '../widgets/status_widgets.dart';

enum ReadingSort {
  byDefault('default'),
  loggedAt('logged_at'),
  value('value'),
  meterName('meter_name'),
  meterType('meter_type'),
  user('technician');

  const ReadingSort(this.apiName);

  final String apiName;

  String get label => switch (this) {
    byDefault => S.sortDefault,
    loggedAt => S.sortDate,
    value => S.sortValue,
    meterName => S.sortMeterName,
    meterType => S.sortType,
    user => S.sortUser,
  };
}

class ReadingFilters {
  const ReadingFilters({
    this.types = const {},
    this.number = '',
    this.userId,
    this.from,
    this.to,
    this.search = '',
    this.sort = ReadingSort.byDefault,
    this.descending = false,
  });

  final Set<MeterType> types;
  final String number;
  final String? userId;
  final DateTime? from;
  final DateTime? to;
  final String search;
  final ReadingSort sort;

  /// The default sort is newest day first, then export order: this flag
  /// flips only the export order (ascending unless chosen otherwise). The
  /// others default to newest / highest first.
  final bool descending;

  bool get isEmpty => !hasActiveFilters && search.isEmpty;
  bool get hasActiveFilters =>
      types.isNotEmpty ||
      number.isNotEmpty ||
      userId != null ||
      from != null ||
      to != null;
  bool get isDefaultSort => sort == ReadingSort.byDefault && !descending;

  ReadingFilters copyWith({
    Set<MeterType>? types,
    String? number,
    String? userId,
    bool clearUser = false,
    DateTime? from,
    DateTime? to,
    bool clearDates = false,
    String? search,
    ReadingSort? sort,
    bool? descending,
  }) => ReadingFilters(
    types: types ?? this.types,
    number: number ?? this.number,
    userId: clearUser ? null : (userId ?? this.userId),
    from: clearDates ? null : (from ?? this.from),
    to: clearDates ? null : (to ?? this.to),
    search: search ?? this.search,
    sort: sort ?? this.sort,
    descending: descending ?? this.descending,
  );

  /// The filters as the API takes them. Dates cover whole local days: the
  /// first moment of [from] to the last of [to], so a one-day filter is a
  /// full day and not an empty instant. Every request that has to match
  /// this list of readings — the list itself, the export, the unusual
  /// check — goes through here, so they can never drift apart.
  Map<String, String> toQuery() => {
    if (types.isNotEmpty) 'type': types.map((t) => t.name).join(','),
    if (number.isNotEmpty) 'number': number,
    'userId': ?userId,
    if (from != null) 'dateFrom': _startOfDay(from!).toUtc().toIso8601String(),
    if (to != null) 'dateTo': _endOfDay(to!).toUtc().toIso8601String(),
    if (search.isNotEmpty) 'search': search,
  };

  /// The same filters plus the sort, for the readings list and the export.
  Map<String, String> toReadingsQuery() => {
    ...toQuery(),
    'sort': sort.apiName,
    'dir': descending ? 'desc' : 'asc',
  };

  static DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime _endOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59, 999);
}

// ---- sort sheet ------------------------------------------------------------

class ReadingSortSheet extends StatefulWidget {
  const ReadingSortSheet({
    super.key,
    required this.initial,
    required this.showUser,
  });

  final ReadingFilters initial;
  final bool showUser;

  @override
  State<ReadingSortSheet> createState() => _ReadingSortSheetState();
}

class _ReadingSortSheetState extends State<ReadingSortSheet> {
  late ReadingSort _sort = widget.initial.sort;
  late bool _desc = widget.initial.descending;

  @override
  Widget build(BuildContext context) {
    final options = ReadingSort.values.where(
      (s) => widget.showUser || s != ReadingSort.user,
    );
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
          RadioGroup<ReadingSort>(
            groupValue: _sort,
            onChanged: (v) => setState(() {
              _sort = v!;
              // Sensible direction per field: default = ascending export
              // order within each day; everything else newest / highest first.
              _desc = _sort != ReadingSort.byDefault;
            }),
            child: Column(
              children: [
                for (final s in options)
                  RadioListTile<ReadingSort>(
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
            onPressed: () => Navigator.pop(
              context,
              widget.initial.copyWith(sort: _sort, descending: _desc),
            ),
            child: Text(S.applyFilters),
          ),
        ],
      ),
    );
  }
}

// ---- filter sheet ----------------------------------------------------------

class ReadingFilterSheet extends StatefulWidget {
  const ReadingFilterSheet({
    super.key,
    required this.initial,
    required this.showUser,
    required this.users,
  });

  final ReadingFilters initial;
  final bool showUser;
  final List<UserName> users;

  @override
  State<ReadingFilterSheet> createState() => _ReadingFilterSheetState();
}

class _ReadingFilterSheetState extends State<ReadingFilterSheet> {
  late ReadingFilters _f = widget.initial;
  late Set<MeterType> _types = {...widget.initial.types};
  late final _number = TextEditingController(text: widget.initial.number);
  late String? _userId = widget.users.any((u) => u.id == widget.initial.userId)
      ? widget.initial.userId
      : null;

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  Future<void> _pickDates() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: BuildConfig.dataStart,
      lastDate: DateTime(now.year + 1),
      initialDateRange: _f.from != null && _f.to != null
          ? DateTimeRange(start: _f.from!, end: _f.to!)
          : null,
    );
    if (range == null) {
      return;
    }
    setState(() => _f = _f.copyWith(from: range.start, to: range.end));
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d/M/yyyy', S.localeCode);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 +
            MediaQuery.viewInsetsOf(context).bottom +
            MediaQuery.viewPaddingOf(context).bottom,
      ),
      child: SingleChildScrollView(
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
                  label: Text(S.filterAllTypes),
                  selected: _types.isEmpty,
                  onSelected: (_) => setState(() => _types = {}),
                ),
                for (final t in MeterType.values)
                  TypeChip(
                    type: t,
                    selected: _types.contains(t),
                    onSelected: (on) => setState(() {
                      _types = on ? {..._types, t} : ({..._types}..remove(t));
                      // Every type selected is the same as "all".
                      if (_types.length == MeterType.values.length) {
                        _types = {};
                      }
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _number,
              textDirection: TextDirection.ltr,
              contextMenuBuilder: appContextMenuBuilder,
              decoration: InputDecoration(
                labelText: S.filterNumber,
                isDense: true,
                prefixIcon: Icon(Icons.tag_rounded),
              ),
            ),
            if (widget.showUser) ...[
              const SizedBox(height: 14),
              DropdownButtonFormField<String?>(
                initialValue: _userId,
                isExpanded: true,
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(S.filterAllUsers),
                  ),
                  for (final u in widget.users)
                    DropdownMenuItem<String?>(
                      value: u.id,
                      child: Text(u.fullName),
                    ),
                ],
                decoration: InputDecoration(
                  labelText: S.filterUser,
                  isDense: true,
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                onChanged: (v) => setState(() => _userId = v),
              ),
            ],
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
                    onPressed: () => Navigator.pop(
                      context,
                      ReadingFilters(sort: _f.sort, descending: _f.descending),
                    ),
                    child: Text(S.clearFilters),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(
                      context,
                      ReadingFilters(
                        types: _types,
                        number: _number.text.trim(),
                        userId: widget.showUser ? _userId : null,
                        from: _f.from,
                        to: _f.to,
                        search: widget.initial.search,
                        sort: _f.sort,
                        descending: _f.descending,
                      ),
                    ),
                    child: Text(S.applyFilters),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
