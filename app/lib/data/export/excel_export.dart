import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

import '../../core/strings.dart';
import '../models.dart';

/// Builds an .xlsx workbook from the (possibly filtered) readings list.
/// Rows are the raw API objects from GET /api/readings. [settings] comes
/// from the server (a moderator sets it) and decides the columns and their
/// order, the file's language, date and number formats, whether each
/// meter type gets its own sheet, and whether the readings are laid out
/// one per row or transposed (dates down, meters across; see
/// [_addTransposedSheet]).
///
/// The file is written in the language [settings] asks for, which is not
/// necessarily the one the app is in: everything translatable reads from
/// [S], so the build runs with that language in place and puts the app's
/// own back afterwards. It is synchronous, so nothing else can observe the
/// swap. Meter names, areas and numbers come from the data and are written
/// exactly as they are stored, in either language.
Uint8List buildReadingsWorkbook(
  List<Map<String, dynamic>> readings, {
  ExportSettings settings = const ExportSettings(),
}) {
  final appLanguage = S.language;
  S.language = settings.language.resolve();
  try {
    return _buildWorkbook(readings, settings);
  } finally {
    S.language = appLanguage;
  }
}

Uint8List _buildWorkbook(
  List<Map<String, dynamic>> readings,
  ExportSettings settings,
) {
  final excel = Excel.createExcel();
  final columns = settings.columns;
  // The locale spells out month names (MMMM) in the file's language.
  final dateFmt = DateFormat(settings.dateFormat, S.localeCode);
  final rtl = !S.isEnglish;
  final headerStyle = CellStyle(bold: true);
  // "#,##0.00" style code from the chosen decimals / separator.
  final decimals = settings.decimals == 0 ? '' : '.${'0' * settings.decimals}';
  final numberStyle = CellStyle(
    numberFormat: NumFormat.custom(
      formatCode: '${settings.thousandsSeparator ? '#,##0' : '0'}$decimals',
    ),
  );

  String date(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final dt = DateTime.tryParse(iso);
    return dt == null ? iso : dateFmt.format(dt.toLocal());
  }

  CellValue? cell(ExportColumn column, Map<String, dynamic> r, MeterType type) {
    switch (column) {
      case ExportColumn.loggedAt:
        return TextCellValue(date(r['logged_at'] as String?));
      case ExportColumn.meterName:
        return TextCellValue(r['meter_name'] as String? ?? '');
      case ExportColumn.meterType:
        return TextCellValue(type.label);
      case ExportColumn.meterArea:
        return TextCellValue(r['meter_area'] as String? ?? '');
      case ExportColumn.meterNumber:
        // A whole number; text only if the server still holds an old one.
        final raw = r['meter_number'];
        final number = parseMeterNumber(raw);
        if (number != null) return IntCellValue(number);
        return raw is String ? TextCellValue(raw) : null;
      case ExportColumn.value:
        return DoubleCellValue((r['value'] as num).toDouble());
      case ExportColumn.gain:
        final gain = r['gain'] as num?;
        return gain == null ? null : DoubleCellValue(gain.toDouble());
      case ExportColumn.unit:
        return TextCellValue(type.unit);
      case ExportColumn.loggedBy:
        return TextCellValue(r['logged_by_name'] as String? ?? '');
      case ExportColumn.syncedAt:
        return TextCellValue(date(r['synced_at'] as String?));
      case ExportColumn.readingId:
        return TextCellValue(r['id'] as String);
    }
  }

  /// Header row and column widths for one sheet (the direction is set on
  /// the finished file, below).
  Sheet startSheet(String name) {
    final sheet = excel[name];
    sheet.appendRow([for (final c in columns) TextCellValue(c.label)]);
    for (var i = 0; i < columns.length; i++) {
      sheet
              .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
              .cellStyle =
          headerStyle;
      sheet.setColumnWidth(i, columns[i].width);
    }
    return sheet;
  }

  void addRow(Sheet sheet, Map<String, dynamic> r) {
    final type = MeterType.fromApi(r['meter_type'] as String);
    final row = sheet.maxRows;
    sheet.appendRow([for (final c in columns) cell(c, r, type)]);
    for (var i = 0; i < columns.length; i++) {
      final column = columns[i];
      if (column != ExportColumn.value && column != ExportColumn.gain) continue;
      sheet
              .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: row))
              .cellStyle =
          numberStyle;
    }
  }

  if (settings.transpose) {
    final days = _dayRange(readings);
    final styles = (header: headerStyle, number: numberStyle);
    if (settings.sheetPerType) {
      for (final type in MeterType.values) {
        final rows = readings
            .where((r) => r['meter_type'] == type.name)
            .toList(growable: false);
        if (rows.isEmpty) continue;
        _addTransposedSheet(excel[type.label], rows, days, settings, styles);
      }
    }
    if (!settings.sheetPerType || excel.sheets.length <= 1) {
      _addTransposedSheet(excel[S.sheetName], readings, days, settings, styles);
    }
  } else if (settings.sheetPerType) {
    // One sheet per type, tab named after it; types with no readings are
    // skipped, and the sheets keep the electricity / water / gas order.
    for (final type in MeterType.values) {
      final rows = readings
          .where((r) => r['meter_type'] == type.name)
          .toList(growable: false);
      if (rows.isEmpty) continue;
      final sheet = startSheet(type.label);
      for (final r in rows) {
        addRow(sheet, r);
      }
    }
  }
  // A single sheet, and also the fallback when no type had any readings.
  if (!settings.transpose &&
      (!settings.sheetPerType || excel.sheets.length <= 1)) {
    final sheet = startSheet(S.sheetName);
    for (final r in readings) {
      addRow(sheet, r);
    }
  }

  final first = excel.sheets.keys.firstWhere((n) => n != _defaultSheetName);
  excel.setDefaultSheet(first);
  if (excel.sheets.containsKey(_defaultSheetName)) {
    excel.delete(_defaultSheetName);
  }
  final bytes = excel.encode()!;
  if (!rtl) return Uint8List.fromList(bytes);
  // The excel package writes the right-to-left flag only for sheets that
  // were in the file when it was opened (its template's own "Sheet1"),
  // never for sheets added since — which is every sheet here. Opening the
  // finished file again makes them such sheets; values, styles, merges and
  // formulas come through unchanged.
  final reopened = Excel.decodeBytes(bytes);
  for (final name in reopened.sheets.keys) {
    reopened[name].isRTL = true;
  }
  return Uint8List.fromList(reopened.encode()!);
}

/// The empty sheet `Excel.createExcel()` starts with.
const _defaultSheetName = 'Sheet1';

// ---- transposed layout -----------------------------------------------------

/// One meter as a block of columns in the transposed layout.
class _PivotMeter {
  _PivotMeter(Map<String, dynamic> r)
    : id = r['meter_id'] as String,
      name = r['meter_name'] as String? ?? '',
      type = MeterType.fromApi(r['meter_type'] as String),
      number = parseMeterNumber(r['meter_number']),
      area = r['meter_area'] as String? ?? '',
      group = (r['meter_group'] as String?)?.trim() ?? '',
      exportOrder = r['meter_export_order'] as int?;

  final String id;
  final String name;
  final MeterType type;
  final int? number;
  final String area;

  /// '' = no group.
  final String group;
  final int? exportOrder;

  /// Meter type first (electricity, water, gas), then export order (unset
  /// last), then name: the order the meters run across the sheet.
  static int compare(_PivotMeter a, _PivotMeter b) {
    final byType = a.type.index.compareTo(b.type.index);
    if (byType != 0) return byType;
    final ao = a.exportOrder, bo = b.exportOrder;
    if (ao != bo) {
      if (ao == null) return 1;
      if (bo == null) return -1;
      return ao.compareTo(bo);
    }
    final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
    return byName != 0 ? byName : a.id.compareTo(b.id);
  }
}

/// A meter's readings on one local day: the day's last reading, and the
/// day's consumption (its readings' gains added up — with one reading a day,
/// exactly the gain the app shows for it; null when none has a gain).
class _PivotCell {
  DateTime? lastAt;
  double? value;
  double? consumption;

  void add(DateTime at, double v, double? gain) {
    if (lastAt == null || at.isAfter(lastAt!)) {
      lastAt = at;
      value = v;
    }
    if (gain != null) consumption = (consumption ?? 0) + gain;
  }
}

DateTime _localDay(String iso) {
  final t = DateTime.parse(iso).toLocal();
  return DateTime(t.year, t.month, t.day);
}

/// Every local day from the first reading's to the last one's, so a day
/// nobody read anything still gets its (empty) row, as on paper.
List<DateTime> _dayRange(List<Map<String, dynamic>> readings) {
  if (readings.isEmpty) return const [];
  var first = _localDay(readings.first['logged_at'] as String);
  var last = first;
  for (final r in readings) {
    final day = _localDay(r['logged_at'] as String);
    if (day.isBefore(first)) first = day;
    if (day.isAfter(last)) last = day;
  }
  return [
    // Calendar steps, not 24-hour ones, so a DST change can't skip a day.
    for (
      var d = first;
      !d.isAfter(last);
      d = DateTime(d.year, d.month, d.day + 1)
    )
      d,
  ];
}

/// The chosen date pattern without its time, since a row is a whole day;
/// a pattern without the day of the month ("MMMM yyyy") gets one.
String _dayPattern(String pattern) {
  final date = pattern.replaceAll(RegExp(r'\s*HH:mm'), '').trim();
  return date.contains('d') ? date : 'd MMMM yyyy';
}

/// Dates down the side, one row per day, and meters across the top, by
/// meter type and then export order (the sheet's direction comes from the
/// file's language). Each meter has a reading column and/or a consumption
/// column — the Reading and Increase columns of the settings; reading only
/// if neither is chosen — under a header with its name, plus its number
/// and area when those columns are chosen. With group headers, meters that
/// share a group sit under one merged header and the rest span both header
/// rows; with totals, a last row sums each consumption column.
void _addTransposedSheet(
  Sheet sheet,
  List<Map<String, dynamic>> readings,
  List<DateTime> days,
  ExportSettings settings,
  ({CellStyle header, CellStyle number}) styles,
) {
  final columns = settings.columns;
  final showConsumption = columns.contains(ExportColumn.gain);
  final showValue = columns.contains(ExportColumn.value) || !showConsumption;
  final measures = [
    if (showValue) ExportColumn.value,
    if (showConsumption) ExportColumn.gain,
  ];
  final withNumber = columns.contains(ExportColumn.meterNumber);
  final withArea = columns.contains(ExportColumn.meterArea);

  final metersById = <String, _PivotMeter>{};
  final cells = <String, Map<DateTime, _PivotCell>>{};
  for (final r in readings) {
    final meter = metersById.putIfAbsent(
      r['meter_id'] as String,
      () => _PivotMeter(r),
    );
    final at = DateTime.parse(r['logged_at'] as String).toLocal();
    cells
        .putIfAbsent(meter.id, () => {})
        .putIfAbsent(DateTime(at.year, at.month, at.day), _PivotCell.new)
        .add(
          at,
          (r['value'] as num).toDouble(),
          (r['gain'] as num?)?.toDouble(),
        );
  }
  final meters = metersById.values.toList()..sort(_PivotMeter.compare);

  final grouped =
      settings.groupHeaders && meters.any((m) => m.group.isNotEmpty);
  final groupRow = grouped ? 0 : null;
  final meterRow = grouped ? 1 : 0;
  final measureRow = meterRow + 1;
  final firstDataRow = measureRow + 1;
  final width = measures.length;
  final header = CellStyle(
    bold: true,
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
    textWrapping: TextWrapping.WrapText,
  );
  CellIndex at(int column, int row) =>
      CellIndex.indexByColumnRow(columnIndex: column, rowIndex: row);
  void put(int column, int row, CellValue? value, CellStyle style) {
    final cell = sheet.cell(at(column, row));
    cell.value = value;
    cell.cellStyle = style;
  }

  void span(int c1, int r1, int c2, int r2, String text) {
    if (c1 != c2 || r1 != r2) {
      sheet.merge(at(c1, r1), at(c2, r2));
    }
    // Styled after merging: merging replaces the cell, and the package's
    // setMergedCellStyle only applies styles that have borders.
    put(c1, r1, TextCellValue(text), header);
  }

  // The date column spans every header row.
  span(0, 0, 0, measureRow, S.colDate);
  sheet.setColumnWidth(0, 16);

  String label(_PivotMeter m) => [
    m.name,
    if (withNumber && m.number != null) '${m.number}',
    if (withArea && m.area.isNotEmpty) m.area,
  ].join(' · ');

  for (final (i, m) in meters.indexed) {
    final first = 1 + i * width;
    final last = first + width - 1;
    // A meter outside any group fills the group row too.
    final top = grouped && m.group.isEmpty ? groupRow! : meterRow;
    span(first, top, last, meterRow, label(m));
    for (final (j, measure) in measures.indexed) {
      final name = measure == ExportColumn.value
          ? S.colValue
          : S.colConsumption;
      put(
        first + j,
        measureRow,
        TextCellValue('$name (${m.type.unit})'),
        header,
      );
      sheet.setColumnWidth(first + j, 14);
    }
  }

  // Runs of neighbouring meters in the same group share one header.
  if (grouped) {
    var i = 0;
    while (i < meters.length) {
      final group = meters[i].group;
      var j = i;
      while (j + 1 < meters.length &&
          group.isNotEmpty &&
          meters[j + 1].group.toLowerCase() == group.toLowerCase()) {
        j++;
      }
      if (group.isNotEmpty) {
        span(1 + i * width, groupRow!, (j + 1) * width, groupRow, group);
      }
      i = j + 1;
    }
  }

  final dayFmt = DateFormat(_dayPattern(settings.dateFormat), S.localeCode);
  for (final (d, day) in days.indexed) {
    final row = firstDataRow + d;
    put(0, row, TextCellValue(dayFmt.format(day)), styles.header);
    for (final (i, m) in meters.indexed) {
      final cell = cells[m.id]?[day];
      if (cell == null) continue;
      for (final (j, measure) in measures.indexed) {
        final v = measure == ExportColumn.value ? cell.value : cell.consumption;
        if (v != null) {
          put(1 + i * width + j, row, DoubleCellValue(v), styles.number);
        }
      }
    }
  }

  if (settings.totals && showConsumption && days.isNotEmpty) {
    final row = firstDataRow + days.length;
    final j = measures.indexOf(ExportColumn.gain);
    put(0, row, TextCellValue(S.exportTotalRow), styles.header);
    for (var i = 0; i < meters.length; i++) {
      final column = 1 + i * width + j;
      final letter = getColumnAlphabet(column);
      put(
        column,
        row,
        FormulaCellValue('SUM($letter${firstDataRow + 1}:$letter$row)'),
        styles.number.copyWith(boldVal: true),
      );
    }
  }
}
