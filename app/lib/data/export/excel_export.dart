import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

import '../../core/strings.dart';
import '../models.dart';

/// Builds an .xlsx workbook from the (possibly filtered) readings list.
/// Rows are the raw API objects from GET /api/readings. [settings] comes
/// from the server (a moderator sets it) and decides the columns and their
/// order, the sheet direction, date and number formats, and whether each
/// meter type gets its own sheet.
Uint8List buildReadingsWorkbook(
  List<Map<String, dynamic>> readings, {
  ExportSettings settings = const ExportSettings(),
}) {
  final excel = Excel.createExcel();
  final columns = settings.columns;
  final dateFmt = DateFormat(settings.dateFormat);
  final rtl = switch (settings.direction) {
    ExportDirection.auto => !S.isEnglish,
    ExportDirection.rtl => true,
    ExportDirection.ltr => false,
  };
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
        return TextCellValue(r['meter_number'] as String? ?? '');
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

  /// Header row, column widths and direction for one sheet.
  Sheet startSheet(String name) {
    final sheet = excel[name];
    sheet.isRTL = rtl;
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

  if (settings.sheetPerType) {
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
  if (!settings.sheetPerType || excel.sheets.length <= 1) {
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
  return Uint8List.fromList(excel.encode()!);
}

/// The empty sheet `Excel.createExcel()` starts with.
const _defaultSheetName = 'Sheet1';
