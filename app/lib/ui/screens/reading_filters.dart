import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../core/config.dart';
import '../../core/strings.dart';
import '../../data/models.dart';
import '../widgets/status_widgets.dart';

/// What a sort level orders the readings by.
enum ReadingSortField {
  day('day'),
  loggedAt('logged_at'),
  value('value'),
  gain('gain'),
  meterName('meter_name'),
  meterNumber('meter_number'),
  meterArea('meter_area'),
  meterType('meter_type'),
  user('technician');

  const ReadingSortField(this.apiName);

  final String apiName;

  String get label => switch (this) {
    day => S.sortDay,
    loggedAt => S.sortDateTime,
    value => S.sortValue,
    gain => S.sortGain,
    meterName => S.sortMeterName,
    meterNumber => S.meterNumber,
    meterArea => S.sortArea,
    meterType => S.sortType,
    user => S.sortUser,
  };

  /// The direction a field starts in when picked: dates and amounts newest
  /// / highest first, names, numbers and types from the start.
  bool get startsDescending => switch (this) {
    day || loggedAt || value || gain => true,
    meterName || meterNumber || meterArea || meterType || user => false,
  };
}

/// One level of a multi-level sort.
@immutable
class SortLevel {
  const SortLevel(this.field, {this.descending = false});

  final ReadingSortField field;
  final bool descending;

  String get arrow => descending ? '↓' : '↑';

  @override
  bool operator ==(Object other) =>
      other is SortLevel &&
      other.field == field &&
      other.descending == descending;

  @override
  int get hashCode => Object.hash(field, descending);
}

class ReadingFilters {
  const ReadingFilters({
    this.types = const {},
    this.number = '',
    this.userId,
    this.from,
    this.to,
    this.search = '',
    this.sort = const [],
    this.descending = false,
  });

  final Set<MeterType> types;
  final String number;
  final String? userId;
  final DateTime? from;
  final DateTime? to;
  final String search;

  /// Up to [maxSortLevels] levels, each a different field; empty is the
  /// default sort.
  final List<SortLevel> sort;

  /// The default sort only (newest day first, then meter type, then export
  /// order): flips the export order, ascending unless chosen otherwise.
  final bool descending;

  static const maxSortLevels = 3;

  bool get isEmpty => !hasActiveFilters && search.isEmpty;
  bool get hasActiveFilters =>
      types.isNotEmpty ||
      number.isNotEmpty ||
      userId != null ||
      from != null ||
      to != null;
  bool get isDefaultSort => sort.isEmpty && !descending;

  /// "Meter type ↑, Reading ↓", or "Default ↓" for the default sort.
  String get sortLabel => sort.isEmpty
      ? '${S.sortDefault} ${descending ? '↓' : '↑'}'
      : sort
            .map((l) => '${l.field.label} ${l.arrow}')
            .join(S.isEnglish ? ', ' : '، ');

  ReadingFilters copyWith({
    Set<MeterType>? types,
    String? number,
    String? userId,
    bool clearUser = false,
    DateTime? from,
    DateTime? to,
    bool clearDates = false,
    String? search,
    List<SortLevel>? sort,
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
  /// Levels go as matching comma lists ("meter_type,value" + "asc,desc");
  /// a single level is exactly what older servers took.
  Map<String, String> toReadingsQuery() => {
    ...toQuery(),
    if (sort.isEmpty) ...{
      'sort': 'default',
      'dir': descending ? 'desc' : 'asc',
    } else ...{
      'sort': sort.map((l) => l.field.apiName).join(','),
      'dir': sort.map((l) => l.descending ? 'desc' : 'asc').join(','),
    },
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
  // One slot per level; null = not used (level 1: the default sort). A
  // level can only use a field no earlier level uses, and only once the
  // level before it is set, so whatever is picked here is always valid.
  late final List<ReadingSortField?> _fields = [
    for (var i = 0; i < ReadingFilters.maxSortLevels; i++)
      i < widget.initial.sort.length ? widget.initial.sort[i].field : null,
  ];
  late final List<bool> _desc = [
    for (var i = 0; i < ReadingFilters.maxSortLevels; i++)
      i < widget.initial.sort.length
          ? widget.initial.sort[i].descending
          : (i == 0 && widget.initial.descending),
  ];

  List<ReadingSortField> get _offered => ReadingSortField.values
      .where((f) => widget.showUser || f != ReadingSortField.user)
      .toList();

  /// Fields level [i] may use: those no earlier level has taken.
  List<ReadingSortField> _optionsFor(int i) =>
      _offered.where((f) => !_fields.take(i).contains(f)).toList();

  void _pick(int i, ReadingSortField? field) => setState(() {
    _fields[i] = field;
    // A field starts in its natural direction; the default sort ascending.
    _desc[i] = field?.startsDescending ?? false;
    // Later levels give way: nothing after an empty level, and no field
    // twice (picking here what a later level had clears that level).
    for (var j = i + 1; j < _fields.length; j++) {
      if (_fields[j - 1] == null || _fields.take(j).contains(_fields[j])) {
        _fields[j] = null;
      }
    }
  });

  ReadingFilters get _result {
    final levels = [
      for (final (i, f) in _fields.indexed)
        if (f != null) SortLevel(f, descending: _desc[i]),
    ];
    return widget.initial.copyWith(
      sort: levels,
      descending: levels.isEmpty && _desc[0],
    );
  }

  Widget _level(BuildContext context, int i) {
    final enabled = i == 0 || _fields[i - 1] != null;
    final field = _fields[i];
    return Row(
      children: [
        Expanded(
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: S.sortLevel(i + 1),
              isDense: true,
              enabled: enabled,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<ReadingSortField?>(
                value: field,
                isDense: true,
                isExpanded: true,
                onChanged: enabled ? (v) => _pick(i, v) : null,
                items: [
                  DropdownMenuItem<ReadingSortField?>(
                    value: null,
                    child: Text(i == 0 ? S.sortDefault : S.sortNone),
                  ),
                  for (final f in _optionsFor(i))
                    DropdownMenuItem<ReadingSortField?>(
                      value: f,
                      child: Text(f.label),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // The default sort has a direction too (its export order); an
        // unused later level has none.
        SegmentedButton<bool>(
          showSelectedIcon: false,
          style: const ButtonStyle(
            visualDensity: VisualDensity(horizontal: -3, vertical: -2),
          ),
          segments: [
            ButtonSegment(
              value: false,
              tooltip: S.sortAsc,
              icon: const Icon(Icons.arrow_upward_rounded, size: 18),
            ),
            ButtonSegment(
              value: true,
              tooltip: S.sortDesc,
              icon: const Icon(Icons.arrow_downward_rounded, size: 18),
            ),
          ],
          selected: {_desc[i]},
          onSelectionChanged: enabled && (i == 0 || field != null)
              ? (s) => setState(() => _desc[i] = s.first)
              : null,
        ),
      ],
    );
  }

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
          const SizedBox(height: 12),
          for (var i = 0; i < ReadingFilters.maxSortLevels; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _level(context, i),
          ],
          if (_fields[0] == null) ...[
            const SizedBox(height: 8),
            Text(
              S.sortDefaultHint,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12.5,
              ),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => Navigator.pop(context, _result),
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
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: maxMeterNumberDigits,
              textDirection: TextDirection.ltr,
              contextMenuBuilder: appContextMenuBuilder,
              decoration: InputDecoration(
                labelText: S.filterNumber,
                isDense: true,
                counterText: '',
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
