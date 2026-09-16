import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';

import '../../core/strings.dart';
import '../../data/api/api_client.dart';
import '../../data/models.dart';
import '../../state/session_controller.dart';
import '../widgets/status_widgets.dart';

/// Moderator / engineer overview for a date range (default: last 7 days).
/// Consumption = sum of gains; the first reading of a meter carries no gain
/// so a newly added meter never inflates the numbers.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late DateTime _from;
  late DateTime _to;
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _setLastWeek();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _setLastWeek() {
    final now = DateTime.now();
    _to = DateTime(now.year, now.month, now.day, 23, 59, 59);
    _from = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 6));
  }

  bool get _isLastWeek {
    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 6));
    return _from == start && _to.day == now.day && _to.month == now.month;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await context.read<ApiClient>().fetchDashboard(_from, _to);
      if (!mounted) {
        return;
      }
      setState(() => _data = data);
    } on NetworkException {
      if (mounted) setState(() => _error = S.dashboardNeedInternet);
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      if (e.isUnauthorized) {
        context.read<SessionController>().markTokenRejected();
      }
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
      initialDateRange: DateTimeRange(start: _from, end: _to),
    );
    if (range == null) {
      return;
    }
    setState(() {
      _from = DateTime(range.start.year, range.start.month, range.start.day);
      _to = DateTime(
        range.end.year,
        range.end.month,
        range.end.day,
        23,
        59,
        59,
      );
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fmt = DateFormat('d/M', 'ar');
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
        children: [
          // Range picker row
          Row(
            children: [
              ChoiceChip(
                label: const Text(S.rangeLastWeek),
                selected: _isLastWeek,
                onSelected: (_) {
                  setState(_setLastWeek);
                  _load();
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickRange,
                  icon: const Icon(Icons.date_range_rounded, size: 18),
                  label: Text(
                    _isLastWeek
                        ? S.rangeCustom
                        : '${fmt.format(_from)} – ${fmt.format(_to)}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null) ...[
            const SizedBox(height: 60),
            EmptyState(icon: Icons.cloud_off_rounded, title: _error!),
            Center(
              child: TextButton(onPressed: _load, child: const Text(S.retry)),
            ),
          ] else
            ..._buildContent(scheme),
        ],
      ),
    );
  }

  List<Widget> _buildContent(ColorScheme scheme) {
    final d = _data!;
    final readings = d['readings'] as int;
    final metersRead = d['metersRead'] as int;
    final activeMeters = d['activeMeters'] as int;
    final most = d['most'] as Map<String, dynamic>?;
    final least = d['least'] as Map<String, dynamic>?;
    final totals = (d['totals'] as List<dynamic>).cast<Map<String, dynamic>>();
    final daily = (d['daily'] as List<dynamic>).cast<Map<String, dynamic>>();

    return [
      Row(
        children: [
          Expanded(
            child: _StatTile(
              label: S.statReadings,
              value: '$readings',
              icon: Icons.list_alt_rounded,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatTile(
              label: S.statMetersRead,
              value: '$metersRead / $activeMeters',
              icon: Icons.speed_rounded,
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      if (most != null)
        _MeterHighlight(
          label: S.mostReadMeter,
          meter: most,
          icon: Icons.trending_up_rounded,
        ),
      if (least != null) ...[
        const SizedBox(height: 10),
        _MeterHighlight(
          label: S.leastReadMeter,
          meter: least,
          icon: Icons.trending_down_rounded,
        ),
      ],
      const SizedBox(height: 22),
      _SectionTitle(S.totalConsumption),
      const SizedBox(height: 8),
      Row(
        children: [
          for (final t in MeterType.values) ...[
            Expanded(
              child: _TotalTile(type: t, total: _totalFor(totals, t)),
            ),
            if (t != MeterType.values.last) const SizedBox(width: 10),
          ],
        ],
      ),
      const SizedBox(height: 22),
      _SectionTitle(_weekly(daily) ? S.gainTrendWeekly : S.gainTrend),
      const SizedBox(height: 8),
      Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 18, 16, 10),
          child: daily.isEmpty
              ? SizedBox(
                  height: 160,
                  child: Center(
                    child: Text(
                      S.noDataInRange,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ),
                )
              : _TrendChart(daily: daily, weekly: _weekly(daily)),
        ),
      ),
    ];
  }

  static num _totalFor(List<Map<String, dynamic>> totals, MeterType t) {
    for (final row in totals) {
      if (row['type'] == t.name) return (row['gain'] as num?) ?? 0;
    }
    return 0;
  }

  /// Over ~60 distinct days the daily line gets noisy; bucket by ISO week.
  static bool _weekly(List<Map<String, dynamic>> daily) =>
      daily.map((r) => r['day']).toSet().length > 60;
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
  );
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: scheme.primary, size: 22),
            const SizedBox(height: 8),
            Text(
              value,
              textDirection: TextDirection.ltr,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            Text(
              label,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _MeterHighlight extends StatelessWidget {
  const _MeterHighlight({
    required this.label,
    required this.meter,
    required this.icon,
  });

  final String label;
  final Map<String, dynamic> meter;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final type = MeterType.fromApi(meter['type'] as String);
    final count = meter['readings'] as int;
    return Card(
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
                  Row(
                    children: [
                      Icon(icon, size: 16, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        label,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    meter['name'] as String,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    '${type.label} · ${meter['area'] ?? ''}',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  S.readingsSuffix,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12,
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

class _TotalTile extends StatelessWidget {
  const _TotalTile({required this.type, required this.total});

  final MeterType type;
  final num total;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(type.icon, color: type.color, size: 18),
                const SizedBox(width: 6),
                Text(
                  type.label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                NumberFormat.decimalPattern('en').format(total),
                textDirection: TextDirection.ltr,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: type.color,
                ),
              ),
            ),
            Text(
              type.unit,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.daily, required this.weekly});

  final List<Map<String, dynamic>> daily;
  final bool weekly;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Bucket key: the day, or the Monday of its week.
    String bucketOf(String day) {
      if (!weekly) {
        return day;
      }
      final d = DateTime.parse(day);
      final monday = d.subtract(Duration(days: d.weekday - 1));
      return DateFormat('yyyy-MM-dd').format(monday);
    }

    final buckets = <String>{};
    final series = {for (final t in MeterType.values) t: <String, double>{}};
    for (final row in daily) {
      final key = bucketOf(row['day'] as String);
      final type = MeterType.fromApi(row['type'] as String);
      final gain = (row['gain'] as num?)?.toDouble() ?? 0;
      buckets.add(key);
      series[type]![key] = (series[type]![key] ?? 0) + gain;
    }
    final keys = buckets.toList()..sort();
    final labelFmt = DateFormat('d/M', 'ar');
    var maxY = 0.0;
    for (final m in series.values) {
      for (final v in m.values) {
        if (v > maxY) {
          maxY = v;
        }
      }
    }
    if (maxY <= 0) {
      maxY = 1;
    }

    return Column(
      children: [
        SizedBox(
          height: 220,
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: maxY * 1.15,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: scheme.outlineVariant.withValues(alpha: 0.5),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 44,
                    getTitlesWidget: (v, _) => Text(
                      NumberFormat.compact(locale: 'en').format(v),
                      style: TextStyle(
                        fontSize: 10,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: (keys.length / 6).ceilToDouble().clamp(
                      1,
                      double.infinity,
                    ),
                    getTitlesWidget: (v, _) {
                      final i = v.round();
                      if (i < 0 || i >= keys.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          labelFmt.format(DateTime.parse(keys[i])),
                          style: TextStyle(
                            fontSize: 10,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (spots) => spots
                      .map(
                        (s) => LineTooltipItem(
                          '${NumberFormat.decimalPattern('en').format(s.y)} ${MeterType.values[s.barIndex].unit}',
                          TextStyle(
                            color: MeterType.values[s.barIndex].color,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              lineBarsData: [
                for (final t in MeterType.values)
                  LineChartBarData(
                    color: t.color,
                    barWidth: 2.5,
                    isCurved: true,
                    curveSmoothness: 0.25,
                    preventCurveOverShooting: true,
                    dotData: FlDotData(show: keys.length <= 14),
                    belowBarData: BarAreaData(
                      show: true,
                      color: t.color.withValues(alpha: 0.08),
                    ),
                    spots: [
                      for (var i = 0; i < keys.length; i++)
                        FlSpot(i.toDouble(), series[t]![keys[i]] ?? 0),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 14,
          children: [
            for (final t in MeterType.values)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: t.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${t.label} (${t.unit})',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
