import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

import '../../core/strings.dart';
import '../models.dart';

/// Builds an .xlsx workbook from the (possibly filtered) readings list.
/// Rows are the raw API objects from GET /api/readings.
Uint8List buildReadingsWorkbook(List<Map<String, dynamic>> readings) {
  final excel = Excel.createExcel();
  final sheet = excel[S.sheetName];
  excel.setDefaultSheet(S.sheetName);
  for (final name in excel.sheets.keys.toList()) {
    if (name != S.sheetName) excel.delete(name);
  }
  sheet.isRTL = true;

  final headerStyle = CellStyle(bold: true);
  final headers = [
    S.colDateTime,
    S.colMeterName,
    S.colType,
    S.colMeterArea,
    S.colLocation,
    S.colFloor,
    S.colMeterNumber,
    S.colValue,
    S.colLoggedBy,
    S.colSyncedAt,
    S.colReadingId,
  ];
  sheet.appendRow(headers.map(TextCellValue.new).toList());
  for (var c = 0; c < headers.length; c++) {
    sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0))
            .cellStyle =
        headerStyle;
  }

  final fmt = DateFormat('yyyy-MM-dd HH:mm');
  String local(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final dt = DateTime.tryParse(iso);
    return dt == null ? iso : fmt.format(dt.toLocal());
  }

  for (final r in readings) {
    sheet.appendRow([
      TextCellValue(local(r['logged_at'] as String?)),
      TextCellValue(r['meter_name'] as String? ?? ''),
      TextCellValue(MeterType.fromApi(r['meter_type'] as String).label),
      TextCellValue(r['meter_area'] as String? ?? ''),
      TextCellValue(r['meter_location'] as String? ?? ''),
      IntCellValue(r['meter_floor'] as int? ?? 0),
      TextCellValue(r['meter_number'] as String? ?? ''),
      DoubleCellValue((r['value'] as num).toDouble()),
      TextCellValue(r['logged_by_name'] as String? ?? ''),
      TextCellValue(local(r['synced_at'] as String?)),
      TextCellValue(r['id'] as String),
    ]);
  }

  final widths = [
    18.0,
    22.0,
    12.0,
    20.0,
    26.0,
    8.0,
    16.0,
    14.0,
    20.0,
    18.0,
    38.0,
  ];
  for (var c = 0; c < widths.length; c++) {
    sheet.setColumnWidth(c, widths[c]);
  }

  return Uint8List.fromList(excel.encode()!);
}
