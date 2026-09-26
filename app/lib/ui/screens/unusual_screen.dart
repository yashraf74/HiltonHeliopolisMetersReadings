import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/api/api_client.dart';
import '../../data/models.dart';
import '../../state/app_events.dart';
import '../../state/session_controller.dart';
import '../popups.dart';
import '../widgets/status_widgets.dart';
import 'reading_filters.dart';

/// Every reading flagged as unusual, for moderators and engineers. Tapping
/// one opens it, where it can be edited, deleted or marked as normal.
///
/// The page opens on whatever the readings list is filtered by and then
/// keeps its own copy: filters changed here never travel back.
class UnusualScreen extends StatefulWidget {
  const UnusualScreen({super.key, this.filters = const ReadingFilters()});

  /// The readings screen's filters at the moment it was left.
  final ReadingFilters filters;

  static Future<void> open(
    BuildContext context, {
    ReadingFilters filters = const ReadingFilters(),
  }) => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => UnusualScreen(filters: filters)));

  @override
  State<UnusualScreen> createState() => _UnusualScreenState();
}

class _UnusualScreenState extends State<UnusualScreen> {
  late ReadingFilters _filters = widget.filters;
  late final _search = TextEditingController(text: widget.filters.search);
  List<Map<String, dynamic>> _rows = const [];
  List<UserName> _userNames = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
      _loadUserNames();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await context.read<ApiClient>().fetchUnusual(
        _filters.toQuery(),
      );
      if (!mounted) return;
      setState(() {
        _rows = result.rows;
        _loading = false;
      });
    } on NetworkException {
      if (mounted) {
        setState(() {
          _error = S.readingsNeedInternet;
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.isUnauthorized) {
        context.read<SessionController>().markTokenRejected();
      }
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _loadUserNames() async {
    try {
      final names = await context.read<ApiClient>().fetchUserNames();
      if (mounted) setState(() => _userNames = names);
    } catch (_) {
      // The dropdown just stays empty; not worth surfacing.
    }
  }

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<ReadingFilters>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => ReadingFilterSheet(
        initial: _filters,
        showUser: true,
        users: _userNames,
      ),
    );
    if (result == null) return;
    setState(() => _filters = result);
    if (_search.text != result.search) _search.text = result.search;
    _load();
  }

  /// A reading changed (marked normal, edited, deleted): reload, and let the
  /// readings screen's card recount.
  void _onReadingChanged() {
    context.read<AppEvents>().unusualChanged();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(S.unusualReadings)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
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
                                  () =>
                                      _filters = _filters.copyWith(search: ''),
                                );
                                _load();
                              },
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Badge(
                  isLabelVisible: _filters.hasActiveFilters,
                  child: IconButton.filledTonal(
                    tooltip: S.filters,
                    onPressed: _openFilters,
                    icon: const Icon(Icons.tune_rounded),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${S.readingsCount}: ${_rows.length} · ${_rangeLabel()}',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!_filters.isEmpty)
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
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _buildBody(scheme),
            ),
          ),
        ],
      ),
    );
  }

  /// The period in words, so it's clear what the list covers.
  String _rangeLabel() {
    final fmt = DateFormat('d/M/yyyy', S.localeCode);
    if (_filters.from == null && _filters.to == null) return S.rangeAllDates;
    final from = _filters.from, to = _filters.to;
    if (from != null && to != null) {
      return from == to
          ? fmt.format(from)
          : '${fmt.format(from)} – ${fmt.format(to)}';
    }
    return fmt.format(from ?? to!);
  }

  Widget _buildBody(ColorScheme scheme) {
    if (_loading && _rows.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        children: [
          const SizedBox(height: 60),
          EmptyState(icon: Icons.cloud_off_rounded, title: _error!),
          Center(
            child: TextButton(onPressed: _load, child: Text(S.retry)),
          ),
        ],
      );
    }
    if (_rows.isEmpty) {
      // Nothing flagged in this filter: stay put and say so.
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [SizedBox(height: 80), AllClear()],
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: _rows.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) =>
          _UnusualCard(row: _rows[i], onChanged: _onReadingChanged),
    );
  }
}

/// One flagged reading: the meter, when it was logged, and why it stands out.
class _UnusualCard extends StatelessWidget {
  const _UnusualCard({required this.row, required this.onChanged});

  final Map<String, dynamic> row;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final type = MeterType.fromApi(row['type'] as String);
    final negative = row['kind'] == 'negative';
    final usual = row['usual'] as num?;
    final daily = row['daily'] as num;
    final gain = row['gain'] as num;
    final area = row['area'] as String? ?? '';
    final when = DateFormat(
      'd/M/yyyy · HH:mm',
      S.localeCode,
    ).format(DateTime.parse(row['logged_at'] as String).toLocal());
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => showReadingPopup(context, row, onChanged: onChanged),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              MeterTypeBadge(type),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row['name'] as String,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      area.isEmpty ? when : '$area · $when',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      negative || usual == null || usual <= 0
                          ? S.unusualNegative
                          : '${(daily / usual).toStringAsFixed(1)} ${S.timesUsual}',
                      style: TextStyle(
                        color: negative ? AppColors.failed : AppColors.pending,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ValueText(row['value'] as num, unit: type.unit, fontSize: 15),
                  GainText(
                    num.parse(gain.toStringAsFixed(1)),
                    unit: type.unit,
                    fontSize: 12,
                  ),
                ],
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
