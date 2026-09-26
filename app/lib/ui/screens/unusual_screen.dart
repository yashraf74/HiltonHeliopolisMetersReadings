import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/api/api_client.dart';
import '../../data/models.dart';
import '../../state/app_events.dart';
import '../../state/session_controller.dart';
import '../popups.dart';
import '../widgets/status_widgets.dart';

/// Every reading flagged as unusual, for moderators and engineers. Tapping
/// one opens it, where it can be edited, deleted or marked as normal. Once
/// the last one is handled the page closes itself.
class UnusualScreen extends StatefulWidget {
  const UnusualScreen({super.key, this.range});

  /// Period to start on; null means every date since the system went live
  /// (the export warning passes the period being exported).
  final DateTimeRange? range;

  static Future<void> open(BuildContext context, {DateTimeRange? range}) =>
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => UnusualScreen(range: range)));

  @override
  State<UnusualScreen> createState() => _UnusualScreenState();
}

class _UnusualScreenState extends State<UnusualScreen> {
  late DateTimeRange? _range = widget.range;
  List<Map<String, dynamic>> _rows = const [];
  bool _loading = true;
  String? _error;

  /// Set once the list has been non-empty, so arriving at an already empty
  /// page doesn't look like the user just fixed everything.
  bool _hadAny = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await context.read<ApiClient>().fetchUnusual(
        from: _range?.start,
        to: _range == null ? null : _endOfDay(_range!.end),
      );
      if (!mounted) return;
      setState(() {
        _rows = result.rows;
        _loading = false;
        _hadAny = _hadAny || result.rows.isNotEmpty;
      });
      // Everything handled: tell the readings screen and step back out.
      if (result.count == 0 && _hadAny && mounted) {
        context.read<AppEvents>().unusualChanged();
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(S.allUnusualResolved)));
        Navigator.of(context).pop();
      }
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

  static DateTime _endOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59);

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: BuildConfig.dataStart,
      lastDate: now,
      initialDateRange: _range,
    );
    if (picked == null || !mounted) return;
    setState(() => _range = picked);
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
    final fmt = DateFormat('d/M/yyyy', S.localeCode);
    return Scaffold(
      appBar: AppBar(title: Text(S.unusualReadings)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickRange,
                    icon: const Icon(Icons.date_range_rounded, size: 18),
                    label: Text(
                      _range == null
                          ? S.rangeAllDates
                          : '${fmt.format(_range!.start)} – ${fmt.format(_range!.end)}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                if (_range != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: S.rangeClear,
                    onPressed: () {
                      setState(() => _range = null);
                      _load();
                    },
                    icon: const Icon(Icons.filter_alt_off_outlined),
                  ),
                ],
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
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          EmptyState(
            icon: Icons.check_circle_outline_rounded,
            title: S.noUnusual,
          ),
        ],
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
