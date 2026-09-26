import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/api/api_client.dart';
import '../../data/models.dart';
import '../../state/session_controller.dart';
import '../popups.dart';
import '../widgets/status_widgets.dart';

/// Moderator / engineer overview for a date range (default: last 7 days).
/// Consumption comes from gains, spread by the server over the days since
/// each meter's previous reading; a meter's first reading has no gain, so a
/// newly added meter never inflates the numbers.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  /// null means every date since the system went live.
  DateTimeRange? _range = _lastWeek();
  _Data? _data;
  bool _loading = true;
  String? _error;

  final _scroll = ScrollController();

  static DateTimeRange _lastWeek() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return DateTimeRange(
      start: today.subtract(const Duration(days: 6)),
      end: today,
    );
  }

  DateTime get _from => _range?.start ?? BuildConfig.dataStart;

  DateTime get _to {
    final end = _range?.end ?? DateTime.now();
    return DateTime(end.year, end.month, end.day, 23, 59, 59);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final json = await context.read<ApiClient>().fetchDashboard(_from, _to);
      if (!mounted) {
        return;
      }
      setState(() => _data = _Data.fromJson(json));
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

  /// Period picker: the usual last 7 days, every date, or a range chosen on
  /// the calendar (which never goes back past the system's first day).
  Future<void> _pickRange() async {
    final choice = await showModalBottomSheet<_RangeChoice>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const _RangeSheet(),
    );
    if (choice == null || !mounted) return;
    switch (choice) {
      case _RangeChoice.lastWeek:
        setState(() => _range = _lastWeek());
      case _RangeChoice.allDates:
        setState(() => _range = null);
      case _RangeChoice.custom:
        final now = DateTime.now();
        final picked = await showDateRangePicker(
          context: context,
          firstDate: BuildConfig.dataStart,
          lastDate: now,
          initialDateRange: _range,
        );
        if (picked == null || !mounted) return;
        setState(() => _range = picked);
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d/M', S.localeCode);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
        children: [
          OutlinedButton.icon(
            onPressed: _pickRange,
            icon: const Icon(Icons.date_range_rounded, size: 18),
            label: Text(
              _range == null
                  ? S.rangeAllDates
                  : '${fmt.format(_from)} – ${fmt.format(_to)}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 14),
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null) ...[
            const SizedBox(height: 60),
            EmptyState(icon: Icons.cloud_off_rounded, title: _error!),
            Center(
              child: TextButton(onPressed: _load, child: Text(S.retry)),
            ),
          ] else
            ..._buildContent(_data!),
        ],
      ),
    );
  }

  List<Widget> _buildContent(_Data d) {
    final canManage =
        context.read<SessionController>().user?.role.canManage ?? false;
    final series = _Series.of(d);
    const gap = SizedBox(height: 18);
    return [
      Row(
        children: [
          Expanded(
            child: _StatTile(
              label: S.statReadings,
              value: '${d.readings}',
              icon: Icons.list_alt_rounded,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatTile(
              label: S.statMetersRead,
              value: '${d.metersRead} / ${d.activeMeters}',
              icon: Icons.speed_rounded,
            ),
          ),
        ],
      ),
      if (d.most != null || d.least != null) ...[
        const SizedBox(height: 10),
        _HighlightsCard(most: d.most, least: d.least),
      ],
      gap,
      _SectionHeader(S.completion, subtitle: S.completionHint),
      _CompletionCard(series: series),
      gap,
      _SectionHeader(S.consumption, subtitle: series.bucket.label),
      for (final t in MeterType.values) ...[
        _ConsumptionCard(type: t, series: series),
        if (t != MeterType.values.last) const SizedBox(height: 10),
      ],
      gap,
      _SectionHeader(S.changeVsAverage, subtitle: S.changeVsAverageHint),
      _ChangeCard(series: series),
      gap,
      _SectionHeader(S.cost),
      _CostCard(series: series, prices: d.prices, canManage: canManage),
      gap,
      _TopConsumersSection(consumers: d.consumers),
      gap,
      _SectionHeader(
        S.overdueMeters,
        subtitle: S.overdueHint,
        count: d.overdue.length,
      ),
      _ExpandableCard(
        empty: S.noOverdue,
        children: [for (final o in d.overdue) _OverdueRow(o)],
      ),
    ];
  }
}

// ---- data -------------------------------------------------------------------

typedef _Json = Map<String, dynamic>;

class _MeterRef {
  _MeterRef(_Json j)
    : id = j['meter_id'] as String? ?? j['id'] as String,
      name = j['name'] as String,
      type = MeterType.fromApi(j['type'] as String),
      area = j['area'] as String? ?? '',
      photoKey = j['photo_key'] as String?;

  final String id;
  final String name;
  final MeterType type;
  final String area;
  final String? photoKey;
}

class _Data {
  _Data.fromJson(_Json j)
    : days = [for (final d in j['days'] as List) DateTime.parse(d as String)],
      prices = AppSettings.pricesFromJson(j['prices'] as _Json?),
      readings = j['readings'] as int,
      metersRead = j['metersRead'] as int,
      activeMeters = j['activeMeters'] as int,
      most = j['most'] == null ? null : (j['most'] as _Json),
      least = j['least'] == null ? null : (j['least'] as _Json),
      consumption = {
        for (final t in MeterType.values)
          t: [
            for (final v in (j['consumption'] as _Json)[t.name] as List)
              (v as num?)?.toDouble(),
          ],
      },
      completion = [
        for (final v in j['completion'] as List) (v as num).toDouble(),
      ],
      consumers = (j['consumers'] as List).cast<_Json>(),
      unusual = (j['unusual'] as List).cast<_Json>(),
      overdue = (j['overdue'] as List).cast<_Json>();

  final List<DateTime> days;
  final Map<MeterType, double> prices;
  final int readings;
  final int metersRead;
  final int activeMeters;
  final _Json? most;
  final _Json? least;
  final Map<MeterType, List<double?>> consumption;
  final List<double> completion;
  final List<_Json> consumers;
  final List<_Json> unusual;
  final List<_Json> overdue;
}

/// Chart-ready buckets: one per day, or per week (starting Monday) once the
/// range is longer than 60 days. Consumption sums; completion averages.
/// How the range is grouped into chart columns.
enum _Bucket {
  daily,
  weekly,
  monthly;

  String get label => switch (this) {
    daily => S.perDay,
    weekly => S.perWeek,
    monthly => S.perMonth,
  };

  /// Chart labels: day and month, or month and year for monthly columns.
  String format(DateTime d) =>
      (this == monthly
              ? DateFormat('M/yyyy', S.localeCode)
              : DateFormat('d/M', S.localeCode))
          .format(d);

  /// The column a day belongs to.
  DateTime keyOf(DateTime day) => switch (this) {
    daily => day,
    weekly => day.subtract(Duration(days: day.weekday - 1)),
    monthly => DateTime(day.year, day.month),
  };
}

/// Chart-ready columns: per day, per week (from Monday) or per month, so a
/// long range never crowds the charts. Consumption sums; completion
/// averages over the days in the column.
class _Series {
  _Series(this.labels, this.consumption, this.completion, this.bucket);

  /// Above this many columns, the range is grouped more coarsely.
  static const maxColumns = 21;

  factory _Series.of(_Data d) {
    final bucket = _bucketFor(d.days);
    if (bucket == _Bucket.daily) {
      return _Series(d.days, d.consumption, d.completion, bucket);
    }
    final labels = <DateTime>[];
    final index = <int>[];
    for (final day in d.days) {
      final key = bucket.keyOf(day);
      if (labels.isEmpty || labels.last != key) labels.add(key);
      index.add(labels.length - 1);
    }
    final consumption = <MeterType, List<double?>>{};
    for (final t in MeterType.values) {
      final out = List<double?>.filled(labels.length, null);
      final values = d.consumption[t]!;
      for (var i = 0; i < values.length; i++) {
        final v = values[i];
        if (v != null) out[index[i]] = (out[index[i]] ?? 0) + v;
      }
      consumption[t] = out;
    }
    final sums = List<double>.filled(labels.length, 0);
    final counts = List<int>.filled(labels.length, 0);
    for (var i = 0; i < d.completion.length; i++) {
      sums[index[i]] += d.completion[i];
      counts[index[i]]++;
    }
    return _Series(labels, consumption, [
      for (var i = 0; i < labels.length; i++) sums[i] / max(1, counts[i]),
    ], bucket);
  }

  /// The finest grouping that keeps the range within [maxColumns] columns.
  static _Bucket _bucketFor(List<DateTime> days) {
    for (final bucket in _Bucket.values) {
      final keys = <DateTime>{for (final d in days) bucket.keyOf(d)};
      if (keys.length <= maxColumns) return bucket;
    }
    return _Bucket.monthly;
  }

  final List<DateTime> labels;
  final Map<MeterType, List<double?>> consumption;
  final List<double> completion;
  final _Bucket bucket;

  int get length => labels.length;

  String labelAt(int i) => bucket.format(labels[i]);

  double total(MeterType t) =>
      consumption[t]!.fold(0.0, (sum, v) => sum + (v ?? 0));

  /// Each bucket as % above/below the type's own average over the range.
  List<double?> change(MeterType t) {
    final values = consumption[t]!;
    final known = values.whereType<double>().toList();
    if (known.isEmpty) return List.filled(values.length, null);
    final avg = known.reduce((a, b) => a + b) / known.length;
    if (avg <= 0) return List.filled(values.length, null);
    return [for (final v in values) v == null ? null : (v / avg - 1) * 100];
  }
}

// ---- shared chart styling ---------------------------------------------------

final _numFmt = NumberFormat('#,##0.#', 'en');
final _compactFmt = NumberFormat.compact(locale: 'en');

TextStyle _axisStyle(ColorScheme scheme) =>
    TextStyle(fontSize: 10, color: scheme.onSurfaceVariant);

FlGridData _grid(ColorScheme scheme, double interval) => FlGridData(
  drawVerticalLine: false,
  horizontalInterval: interval,
  getDrawingHorizontalLine: (_) => FlLine(
    color: scheme.outlineVariant.withValues(alpha: 0.45),
    strokeWidth: 1,
  ),
);

/// Bottom date labels (at most ten, so they never crowd) plus compact left
/// values.
FlTitlesData _titles(
  ColorScheme scheme,
  _Series series, {
  required String Function(double) left,
  required double leftInterval,

  /// Draw the label at the very top of the axis (the completion chart's
  /// 100%); elsewhere it would collide with the chart's own headroom.
  bool showMax = false,
}) {
  // At most ten date labels: every column up to ten, every other up to
  // twenty, and so on.
  final step = max(1, (series.length / 10).ceil());
  return FlTitlesData(
    topTitles: const AxisTitles(),
    rightTitles: const AxisTitles(),
    leftTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 34,
        interval: leftInterval,
        getTitlesWidget: (v, meta) =>
            (v == meta.max && !showMax) || (v == meta.min && v != 0)
            ? const SizedBox.shrink()
            : Text(
                left(v),
                textDirection: TextDirection.ltr,
                style: _axisStyle(scheme),
              ),
      ),
    ),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 20,
        interval: step.toDouble(),
        getTitlesWidget: (v, _) {
          final i = v.round();
          // Bar charts ask for every column, so skip the in-between ones here
          // as well as through `interval` (which only line charts honour).
          if (i < 0 || i >= series.length || v != i || i % step != 0) {
            return const SizedBox.shrink();
          }
          return Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(series.labelAt(i), style: _axisStyle(scheme)),
          );
        },
      ),
    ),
  );
}

/// Light tooltip: white card, hairline border, dark date line.
LineTouchData _lineTouch(
  ColorScheme scheme,
  _Series series,
  String Function(LineBarSpot) text,
) => LineTouchData(
  touchTooltipData: LineTouchTooltipData(
    getTooltipColor: (_) => Colors.white,
    tooltipBorder: BorderSide(color: scheme.outlineVariant),
    tooltipBorderRadius: BorderRadius.circular(10),
    tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    tooltipMargin: 10,
    fitInsideHorizontally: true,
    fitInsideVertically: true,
    getTooltipItems: (spots) => [
      for (var i = 0; i < spots.length; i++)
        LineTooltipItem(
          i == 0 ? '${series.labelAt(spots[i].x.round())}\n' : '',
          TextStyle(
            color: scheme.onSurfaceVariant,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
          children: [
            TextSpan(
              text: text(spots[i]),
              style: TextStyle(
                color: spots[i].bar.color,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
    ],
  ),
);

BarTouchTooltipData _barTooltip(
  ColorScheme scheme,
  BarTooltipItem Function(BarChartGroupData, BarChartRodData) item,
) => BarTouchTooltipData(
  getTooltipColor: (_) => Colors.white,
  tooltipBorder: BorderSide(color: scheme.outlineVariant),
  tooltipBorderRadius: BorderRadius.circular(10),
  tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
  tooltipMargin: 6,
  fitInsideHorizontally: true,
  fitInsideVertically: true,
  getTooltipItem: (group, _, rod, _) => item(group, rod),
);

/// A round step (1, 2 or 5 × 10ⁿ) giving about [lines] grid lines up to [top].
double _niceInterval(double top, {int lines = 2}) {
  if (top <= 0) return 1;
  final raw = top / lines;
  final magnitude = pow(10, (log(raw) / ln10).floor()).toDouble();
  final step = [1, 2, 5, 10].firstWhere((m) => m * magnitude >= raw);
  return step * magnitude;
}

double _barWidth(int count) => count <= 10
    ? 16
    : count <= 20
    ? 9
    : 5;

List<FlSpot> _spots(List<double?> values) => [
  for (var i = 0; i < values.length; i++)
    values[i] == null ? FlSpot.nullSpot : FlSpot(i.toDouble(), values[i]!),
];

// ---- layout pieces ----------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, {this.subtitle, this.count, this.trailing});

  final String title;
  final String? subtitle;
  final int? count;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, right: 2, left: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        height: 1.3,
                      ),
                    ),
                    if (count != null && count! > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
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
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            Icon(icon, color: scheme.primary, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      value,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12,
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

/// Meter photo thumbnail (tap to zoom), or the type badge without one.
/// Meter thumbnail; tapping it does the same as tapping its row (the meter
/// or reading popup, where the photo opens full size).
class _MeterPhoto extends StatelessWidget {
  const _MeterPhoto(this.meter, {this.size = 40, this.onTap});

  final _MeterRef meter;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final api = context.read<ApiClient>();
    final key = meter.photoKey;
    final thumb = PhotoThumb(
      type: meter.type,
      size: size,
      image: key == null
          ? null
          : NetworkImage(
              api.photoUri(key).toString(),
              headers: api.authHeaders,
            ),
    );
    if (onTap == null) return thumb;
    return GestureDetector(onTap: onTap, child: thumb);
  }
}

/// Name + "type · area" beside a meter photo, with a trailing widget. The
/// whole row is tappable and opens the meter popup; the chevron after the
/// name is the only cue.
class _MeterRow extends StatelessWidget {
  const _MeterRow({required this.meter, required this.trailing, this.caption});

  final _MeterRef meter;
  final Widget trailing;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = TextStyle(color: scheme.onSurfaceVariant, fontSize: 12);
    void open() => showMeterPopup(context, meter.id);
    return InkWell(
      onTap: open,
      borderRadius: BorderRadius.circular(10),
      child: Row(
        children: [
          _MeterPhoto(meter, onTap: open),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (caption != null)
                  Text(
                    caption!,
                    style: muted.copyWith(fontWeight: FontWeight.w700),
                  ),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        meter.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          height: 1.35,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ],
                ),
                Text(
                  meter.area.isEmpty
                      ? meter.type.label
                      : '${meter.type.label} · ${meter.area}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: muted,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }
}

class _HighlightsCard extends StatelessWidget {
  const _HighlightsCard({required this.most, required this.least});

  final _Json? most;
  final _Json? least;

  @override
  Widget build(BuildContext context) {
    Widget row(_Json m, String caption) => _MeterRow(
      meter: _MeterRef(m),
      caption: caption,
      trailing: _CountText(m['readings'] as int),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          children: [
            if (most != null) row(most!, S.mostReadMeter),
            if (most != null && least != null) const Divider(height: 20),
            if (least != null) row(least!, S.leastReadMeter),
          ],
        ),
      ),
    );
  }
}

class _CountText extends StatelessWidget {
  const _CountText(this.count);

  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '$count',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
        ),
        Text(
          S.readingsUnit(count),
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11.5),
        ),
      ],
    );
  }
}

class _NoData extends StatelessWidget {
  const _NoData({this.text, this.height = 72});

  /// Defaults to "no data in this period".
  final String? text;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: Center(
      child: Text(
        text ?? S.noDataInRange,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 12.5,
        ),
      ),
    ),
  );
}

/// Card with a small header row (leading, title, big value) over a chart.
class _ChartCard extends StatelessWidget {
  const _ChartCard({
    this.chart,
    this.leading,
    this.title,
    this.value,
    this.footer,
  });

  final Widget? leading;
  final String? title;
  final Widget? value;
  final Widget? chart;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (leading != null || title != null || value != null) ...[
              Row(
                children: [
                  ?leading,
                  if (leading != null) const SizedBox(width: 8),
                  if (title != null)
                    Text(
                      title!,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  const Spacer(),
                  ?value,
                ],
              ),
              if (chart != null) const SizedBox(height: 10),
            ],
            ?chart,
            if (footer != null) ...[const SizedBox(height: 8), footer!],
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend(this.entries);

  final List<(Color, String)> entries;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 14,
      runSpacing: 4,
      children: [
        for (final (color, label) in entries)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _TypeIcon extends StatelessWidget {
  const _TypeIcon(this.type);

  final MeterType type;

  @override
  Widget build(BuildContext context) => Container(
    width: 28,
    height: 28,
    decoration: BoxDecoration(
      color: type.color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Icon(type.icon, color: type.color, size: 17),
  );
}

// ---- charts -----------------------------------------------------------------

class _CompletionCard extends StatelessWidget {
  const _CompletionCard({required this.series});

  final _Series series;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final values = series.completion;
    final last = values.isEmpty ? 0.0 : values.last;
    return _ChartCard(
      title: series.bucket.label,
      value: Text(
        '${last.round()}%',
        textDirection: TextDirection.ltr,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: scheme.primary,
        ),
      ),
      chart: SizedBox(
        height: 110,
        child: BarChart(
          BarChartData(
            minY: 0,
            maxY: 100,
            alignment: BarChartAlignment.spaceAround,
            gridData: _grid(scheme, 50),
            borderData: FlBorderData(show: false),
            titlesData: _titles(
              scheme,
              series,
              left: (v) => '${v.round()}%',
              leftInterval: 50,
              showMax: true,
            ),
            barTouchData: BarTouchData(
              touchTooltipData: _barTooltip(
                scheme,
                (group, rod) => BarTooltipItem(
                  '${series.labelAt(group.x)}\n',
                  TextStyle(color: scheme.onSurfaceVariant, fontSize: 11),
                  children: [
                    TextSpan(
                      text: '${rod.toY.round()}%',
                      style: TextStyle(
                        color: scheme.primary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            barGroups: [
              for (var i = 0; i < values.length; i++)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: values[i],
                      width: _barWidth(values.length),
                      color: scheme.primary,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                      backDrawRodData: BackgroundBarChartRodData(
                        show: true,
                        toY: 100,
                        color: scheme.primary.withValues(alpha: 0.07),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConsumptionCard extends StatelessWidget {
  const _ConsumptionCard({required this.type, required this.series});

  final MeterType type;
  final _Series series;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final values = series.consumption[type]!;
    final known = values.whereType<double>();
    final hasData = known.isNotEmpty;
    final hi = hasData ? known.reduce(max) : 1.0;
    final lo = hasData ? known.reduce(min) : 0.0;
    final span = max(hi - min(lo, 0), 1.0);
    final interval = _niceInterval(span);
    return _ChartCard(
      leading: _TypeIcon(type),
      title: type.label,
      value: hasData
          ? ValueText(
              num.parse(series.total(type).toStringAsFixed(1)),
              unit: type.unit,
              fontSize: 18,
            )
          : Text(
              S.noDataInRange,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
            ),
      chart: !hasData
          ? null
          : SizedBox(
              height: 110,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: max(1, values.length - 1).toDouble(),
                  minY: lo < 0 ? (lo / interval).floor() * interval : 0,
                  maxY: hi + span * 0.18,
                  gridData: _grid(scheme, interval),
                  borderData: FlBorderData(show: false),
                  titlesData: _titles(
                    scheme,
                    series,
                    left: _compactFmt.format,
                    leftInterval: interval,
                  ),
                  lineTouchData: _lineTouch(
                    scheme,
                    series,
                    (s) => '${_numFmt.format(s.y)} ${type.unit}',
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _spots(values),
                      color: type.color,
                      barWidth: 2.2,
                      isCurved: true,
                      curveSmoothness: 0.25,
                      preventCurveOverShooting: true,
                      dotData: FlDotData(
                        show: values.length <= 14,
                        getDotPainter: (_, _, bar, _) => FlDotCirclePainter(
                          radius: 2.6,
                          color: Colors.white,
                          strokeWidth: 2,
                          strokeColor: type.color,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            type.color.withValues(alpha: 0.18),
                            type.color.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _ChangeCard extends StatelessWidget {
  const _ChangeCard({required this.series});

  final _Series series;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lines = {for (final t in MeterType.values) t: series.change(t)};
    final shown = MeterType.values
        .where((t) => lines[t]!.any((v) => v != null))
        .toList();
    if (shown.isEmpty) return const Card(child: _NoData());
    var extent = 10.0;
    for (final t in shown) {
      for (final v in lines[t]!.whereType<double>()) {
        extent = max(extent, v.abs());
      }
    }
    final interval = _niceInterval(extent);
    extent = interval * ((extent * 1.1) / interval).ceil();
    return _ChartCard(
      chart: SizedBox(
        height: 150,
        child: LineChart(
          LineChartData(
            minX: 0,
            maxX: max(1, series.length - 1).toDouble(),
            minY: -extent,
            maxY: extent,
            gridData: _grid(scheme, interval),
            borderData: FlBorderData(show: false),
            titlesData: _titles(
              scheme,
              series,
              left: (v) => '${v > 0 ? '+' : ''}${v.round()}%',
              leftInterval: interval,
            ),
            extraLinesData: ExtraLinesData(
              horizontalLines: [
                HorizontalLine(
                  y: 0,
                  color: scheme.outline.withValues(alpha: 0.6),
                  strokeWidth: 1,
                  dashArray: [4, 4],
                ),
              ],
            ),
            lineTouchData: _lineTouch(
              scheme,
              series,
              (s) =>
                  '${shown[s.barIndex].label} ${s.y > 0 ? '+' : ''}${s.y.round()}%',
            ),
            lineBarsData: [
              for (final t in shown)
                LineChartBarData(
                  spots: _spots(lines[t]!),
                  color: t.color,
                  barWidth: 2,
                  isCurved: true,
                  curveSmoothness: 0.25,
                  preventCurveOverShooting: true,
                  dotData: FlDotData(
                    show: series.length <= 14,
                    getDotPainter: (_, _, bar, _) => FlDotCirclePainter(
                      radius: 2.2,
                      color: t.color,
                      strokeWidth: 0,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      footer: _Legend([for (final t in shown) (t.color, t.label)]),
    );
  }
}

class _CostCard extends StatelessWidget {
  const _CostCard({
    required this.series,
    required this.prices,
    required this.canManage,
  });

  final _Series series;
  final Map<MeterType, double> prices;
  final bool canManage;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final priced = MeterType.values.where((t) => (prices[t] ?? 0) > 0).toList();
    if (priced.isEmpty) {
      return Card(
        child: _NoData(
          text: canManage ? S.costNoPrices : S.costNoPricesEngineer,
          height: 56,
        ),
      );
    }
    double cost(MeterType t, int i) =>
        max(0, series.consumption[t]![i] ?? 0) * prices[t]!;
    final totals = {
      for (final t in priced)
        t: [for (var i = 0; i < series.length; i++) cost(t, i)]
            .fold(0.0, (a, b) => a + b),
    };
    final total = totals.values.fold(0.0, (a, b) => a + b);
    var top = 1.0;
    for (var i = 0; i < series.length; i++) {
      top = max(top, priced.fold(0.0, (sum, t) => sum + cost(t, i)));
    }
    final interval = _niceInterval(top);
    return _ChartCard(
      title: series.bucket.label,
      value: ValueText(total.round(), unit: S.currency, fontSize: 18),
      chart: SizedBox(
        height: 130,
        child: BarChart(
          BarChartData(
            minY: 0,
            maxY: top * 1.15,
            alignment: BarChartAlignment.spaceAround,
            gridData: _grid(scheme, interval),
            borderData: FlBorderData(show: false),
            titlesData: _titles(
              scheme,
              series,
              left: _compactFmt.format,
              leftInterval: interval,
            ),
            barTouchData: BarTouchData(
              touchTooltipData: _barTooltip(
                scheme,
                (group, rod) => BarTooltipItem(
                  series.labelAt(group.x),
                  TextStyle(color: scheme.onSurfaceVariant, fontSize: 11),
                  children: [
                    for (final t in priced)
                      TextSpan(
                        text:
                            '\n${t.label}: ${_numFmt.format(cost(t, group.x).round())}',
                        style: TextStyle(
                          color: t.color,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    TextSpan(
                      text:
                          '\n${_numFmt.format(rod.toY.round())} ${S.currency}',
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            barGroups: [
              for (var i = 0; i < series.length; i++)
                _stackedGroup(i, priced, (t) => cost(t, i)),
            ],
          ),
        ),
      ),
      footer: _Legend([
        for (final t in priced)
          (t.color, '${t.label} ${_numFmt.format(totals[t]!.round())}'),
      ]),
    );
  }

  BarChartGroupData _stackedGroup(
    int x,
    List<MeterType> types,
    double Function(MeterType) value,
  ) {
    final items = <BarChartRodStackItem>[];
    var y = 0.0;
    for (final t in types) {
      final v = value(t);
      items.add(BarChartRodStackItem(y, y + v, t.color));
      y += v;
    }
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          width: _barWidth(series.length),
          rodStackItems: items,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
        ),
      ],
    );
  }
}

// ---- lists ------------------------------------------------------------------

class _TopConsumersSection extends StatefulWidget {
  const _TopConsumersSection({required this.consumers});

  final List<_Json> consumers;

  @override
  State<_TopConsumersSection> createState() => _TopConsumersSectionState();
}

class _TopConsumersSectionState extends State<_TopConsumersSection> {
  static const _limit = 5;

  late MeterType _type = MeterType.values.firstWhere(
    (t) => widget.consumers.any((c) => c['type'] == t.name),
    orElse: () => MeterType.electricity,
  );
  bool _byArea = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ofType = widget.consumers
        .where((c) => c['type'] == _type.name && (c['amount'] as num) > 0)
        .toList();

    // (label, subtitle, amount, meter for the photo)
    final rows = <(String, String, double, _MeterRef?)>[];
    if (_byArea) {
      final sums = <String, double>{};
      final counts = <String, int>{};
      for (final c in ofType) {
        final area = c['area'] as String? ?? '';
        sums[area] = (sums[area] ?? 0) + (c['amount'] as num);
        counts[area] = (counts[area] ?? 0) + 1;
      }
      final sorted = sums.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      for (final e in sorted.take(_limit)) {
        rows.add((e.key, '${counts[e.key]} ${S.byMeter}', e.value, null));
      }
    } else {
      for (final c in ofType.take(_limit)) {
        final m = _MeterRef(c);
        rows.add((m.name, m.area, (c['amount'] as num).toDouble(), m));
      }
    }
    final top = rows.isEmpty ? 1.0 : rows.first.$3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(
          S.topConsumers,
          trailing: SegmentedButton<bool>(
            showSelectedIcon: false,
            style: const ButtonStyle(
              visualDensity: VisualDensity(horizontal: -3, vertical: -3),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: WidgetStatePropertyAll(
                TextStyle(fontSize: 12.5, fontFamily: 'Cairo'),
              ),
            ),
            segments: [
              ButtonSegment(value: false, label: Text(S.byMeter)),
              ButtonSegment(value: true, label: Text(S.byArea)),
            ],
            selected: {_byArea},
            onSelectionChanged: (s) => setState(() => _byArea = s.first),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    for (final t in MeterType.values) ...[
                      Expanded(
                        child: TypeChip(
                          type: t,
                          selected: _type == t,
                          onSelected: (_) => setState(() => _type = t),
                        ),
                      ),
                      if (t != MeterType.values.last) const SizedBox(width: 6),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                if (rows.isEmpty)
                  const _NoData(height: 56)
                else
                  for (final (label, subtitle, amount, meter) in rows)
                    InkWell(
                      onTap: meter == null
                          ? null
                          : () => showMeterPopup(context, meter.id),
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Row(
                          children: [
                            if (meter != null) ...[
                              _MeterPhoto(
                                meter,
                                size: 36,
                                onTap: () => showMeterPopup(context, meter.id),
                              ),
                              const SizedBox(width: 10),
                            ],
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          label.isEmpty ? '—' : label,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13.5,
                                          ),
                                        ),
                                      ),
                                      if (meter != null)
                                        Icon(
                                          Icons.chevron_right_rounded,
                                          size: 16,
                                          color: scheme.onSurfaceVariant
                                              .withValues(alpha: 0.6),
                                        ),
                                      const SizedBox(width: 8),
                                      ValueText(
                                        double.parse(amount.toStringAsFixed(1)),
                                        unit: _type.unit,
                                        fontSize: 13.5,
                                      ),
                                    ],
                                  ),
                                  if (subtitle.isNotEmpty)
                                    Text(
                                      subtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: scheme.onSurfaceVariant,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  const SizedBox(height: 5),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(3),
                                    child: LinearProgressIndicator(
                                      value: amount / top,
                                      minHeight: 5,
                                      color: _type.color,
                                      backgroundColor: _type.color.withValues(
                                        alpha: 0.1,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A card listing the first few rows, with "show all" for the rest.
class _ExpandableCard extends StatefulWidget {
  const _ExpandableCard({required this.children, required this.empty});

  final List<Widget> children;
  final String empty;

  @override
  State<_ExpandableCard> createState() => _ExpandableCardState();
}

class _ExpandableCardState extends State<_ExpandableCard> {
  static const _collapsed = 3;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final all = widget.children;
    if (all.isEmpty) {
      return Card(child: _NoData(text: widget.empty, height: 56));
    }
    final shown = _expanded ? all : all.take(_collapsed).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < shown.length; i++) ...[
              if (i > 0) const Divider(height: 18),
              shown[i],
            ],
            if (all.length > _collapsed)
              TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                child: Text(
                  _expanded ? S.showLess : '${S.showAll} (${all.length})',
                ),
              )
            else
              const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _OverdueRow extends StatelessWidget {
  const _OverdueRow(this.row);

  final _Json row;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final days = row['days'] as int?;
    return _MeterRow(
      meter: _MeterRef(row),
      trailing: days == null
          ? Text(
              S.neverRead,
              style: const TextStyle(
                color: AppColors.failed,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$days ${S.daysUnit(days)}',
                  style: TextStyle(
                    color: days >= 7 ? AppColors.failed : AppColors.pending,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                Text(
                  S.lastReadDaysAgo,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
    );
  }
}

/// What the period picker offers.
enum _RangeChoice { lastWeek, allDates, custom }

class _RangeSheet extends StatelessWidget {
  const _RangeSheet();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget option(_RangeChoice choice, IconData icon, String label) => ListTile(
      leading: Icon(icon, color: scheme.primary),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      onTap: () => Navigator.pop(context, choice),
    );
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          option(_RangeChoice.lastWeek, Icons.today_rounded, S.rangeLast7),
          option(
            _RangeChoice.allDates,
            Icons.filter_alt_off_outlined,
            S.rangeAllDates,
          ),
          option(_RangeChoice.custom, Icons.date_range_rounded, S.rangeCustom),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
