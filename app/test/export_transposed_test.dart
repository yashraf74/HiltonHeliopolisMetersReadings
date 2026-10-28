import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:meters_app/core/strings.dart';
import 'package:meters_app/data/export/excel_export.dart';
import 'package:meters_app/data/models.dart';

/// A reading as GET /api/readings returns it (numbers come as text).
Map<String, dynamic> _reading(
  String id,
  String meter,
  String type,
  String at,
  double value,
  double? gain, {
  int? order,
  String? group,
  String? number,
  String area = 'Main',
}) => {
  'id': id,
  'value': value,
  'gain': gain,
  'logged_at': at,
  'synced_at': at,
  'logged_by_name': 'Tech',
  'meter_id': 'id-$meter',
  'meter_name': meter,
  'meter_type': type,
  'meter_area': area,
  'meter_number': number,
  'meter_export_order': order,
  'meter_group': group,
};

// Out of order on purpose: the layout must not depend on the list's sort.
final _rows = [
  _reading('r1', 'Boiler', 'gas', '2026-09-20T12:00:00Z', 9, null),
  _reading('r2', 'Laundry', 'water', '2026-09-22T12:00:00Z', 70, 5, order: 3),
  _reading(
    'r3',
    'West Wing',
    'water',
    '2026-09-20T12:00:00Z',
    30,
    3,
    order: 2,
    group: 'guest rooms',
  ),
  _reading(
    'r4',
    'East Wing',
    'water',
    '2026-09-20T12:00:00Z',
    20,
    2,
    order: 1,
    group: 'Guest Rooms',
    number: '42',
  ),
  // Lobby is read twice on the 22nd: the later reading wins, and the day's
  // consumption is both gains.
  _reading(
    'r5',
    'Lobby',
    'electricity',
    '2026-09-22T09:00:00Z',
    530,
    30,
    order: 2,
  ),
  _reading(
    'r6',
    'Lobby',
    'electricity',
    '2026-09-22T15:00:00Z',
    540,
    10,
    order: 2,
  ),
  _reading(
    'r7',
    'Lobby',
    'electricity',
    '2026-09-20T12:00:00Z',
    500,
    null,
    order: 2,
  ),
  _reading(
    'r8',
    'Roof',
    'electricity',
    '2026-09-20T12:00:00Z',
    50,
    4,
    order: 1,
  ),
];

Sheet _sheet(ExportSettings settings, [String? name]) {
  final excel = Excel.decodeBytes(
    buildReadingsWorkbook(_rows, settings: settings),
  );
  return excel.sheets[name ?? excel.sheets.keys.first]!;
}

String? _text(Sheet s, int column, int row) => s
    .cell(CellIndex.indexByColumnRow(columnIndex: column, rowIndex: row))
    .value
    ?.toString();

double? _number(Sheet s, int column, int row) {
  final v = s
      .cell(CellIndex.indexByColumnRow(columnIndex: column, rowIndex: row))
      .value;
  return switch (v) {
    DoubleCellValue(:final value) => value,
    IntCellValue(:final value) => value.toDouble(),
    _ => null,
  };
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
    await initializeDateFormatting('en');
  });

  const transposed = ExportSettings(
    transpose: true,
    language: ExportLanguage.en,
    dateFormat: 'yyyy-MM-dd HH:mm',
    columns: [ExportColumn.value, ExportColumn.gain],
  );

  test('meters run by type, then export order; days run down the side', () {
    final s = _sheet(transposed);
    expect(_text(s, 0, 0), 'Date');
    // Electricity, water, gas; each by export order (unset last).
    expect(
      [for (var c = 1; c < s.maxColumns; c += 2) _text(s, c, 0)],
      ['Roof', 'Lobby', 'East Wing', 'West Wing', 'Laundry', 'Boiler'],
    );
    expect(_text(s, 1, 1), 'Reading (kWh)');
    expect(_text(s, 2, 1), 'Consumption (kWh)');
    expect(_text(s, 5, 1), 'Reading (m³)');
    // Every day from the first to the last, the time dropped, even the
    // 21st when nothing was read.
    expect(
      [for (var r = 2; r < 5; r++) _text(s, 0, r)],
      ['2026-09-20', '2026-09-21', '2026-09-22'],
    );
    expect(s.maxRows, 5);
    expect(_number(s, 3, 3), isNull);
    // Lobby on the 22nd: the day's last reading and the day's consumption.
    expect(_number(s, 3, 4), 540);
    expect(_number(s, 4, 4), 40);
    // Each consumption is the reading's own gain, on that reading's day;
    // a first reading (no gain) leaves it empty.
    expect(_number(s, 2, 2), 4);
    expect(_number(s, 4, 2), isNull);
    expect(_number(s, 11, 2), 9);
    expect(_number(s, 12, 2), isNull);
  });

  test('the chosen columns decide what each meter shows', () {
    final readingsOnly = _sheet(
      transposed.copyWith(
        columns: [ExportColumn.value, ExportColumn.meterNumber],
      ),
    );
    // One column per meter, the number joining the name.
    expect(readingsOnly.maxColumns, 7);
    expect(_text(readingsOnly, 3, 0), 'East Wing · 42');
    expect(_text(readingsOnly, 3, 1), 'Reading (m³)');

    final consumptionOnly = _sheet(
      transposed.copyWith(columns: [ExportColumn.gain, ExportColumn.meterArea]),
    );
    expect(consumptionOnly.maxColumns, 7);
    expect(_text(consumptionOnly, 1, 0), 'Roof · Main');
    expect(_number(consumptionOnly, 2, 4), 40);
  });

  test('meters in a group share one header; the rest span both rows', () {
    final s = _sheet(transposed.copyWith(groupHeaders: true));
    // East and West Wing (groups match whatever the case) under one header.
    expect(_text(s, 5, 0), 'Guest Rooms');
    expect(s.spannedItems, contains('F1:I1'));
    expect(_text(s, 5, 1), 'East Wing');
    expect(_text(s, 7, 1), 'West Wing');
    // Laundry has no group: its name fills the group row too.
    expect(_text(s, 9, 0), 'Laundry');
    expect(s.spannedItems, contains('J1:K2'));
    // The date column spans all three header rows.
    expect(s.spannedItems, contains('A1:A3'));
    // Merged headers keep the header style.
    expect(s.cell(CellIndex.indexByString('F1')).cellStyle?.isBold, isTrue);
    expect(_text(s, 0, 3), '2026-09-20');

    // Nobody grouped: no group row at all.
    final plain = Excel.decodeBytes(
      buildReadingsWorkbook([
        _reading('r1', 'Roof', 'electricity', '2026-09-20T12:00:00Z', 50, 4),
      ], settings: transposed.copyWith(groupHeaders: true)),
    );
    final sheet = plain.sheets.values.first;
    expect(_text(sheet, 1, 0), 'Roof');
    expect(_text(sheet, 0, 2), '2026-09-20');
  });

  test('the total row sums each consumption column', () {
    final s = _sheet(transposed.copyWith(totals: true));
    expect(_text(s, 0, 5), 'Total');
    final lobby = s
        .cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 5))
        .value;
    expect(lobby, isA<FormulaCellValue>());
    expect(lobby.toString(), 'SUM(E3:E5)');
    // Reading columns get no total.
    expect(
      s.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 5)).value,
      isNull,
    );
    // Without consumption columns there is nothing to total.
    final readingsOnly = _sheet(
      transposed.copyWith(totals: true, columns: [ExportColumn.value]),
    );
    expect(readingsOnly.maxRows, 5);
  });

  test('a sheet per type, each in the file\'s direction', () {
    final excel = Excel.decodeBytes(
      buildReadingsWorkbook(
        _rows,
        settings: transposed.copyWith(
          sheetPerType: true,
          language: ExportLanguage.ar,
        ),
      ),
    );
    S.language = AppLanguage.ar;
    expect(excel.sheets.keys, [
      MeterType.electricity.label,
      MeterType.water.label,
      MeterType.gas.label,
    ]);
    final water = excel.sheets[MeterType.water.label]!;
    expect(water.isRTL, isTrue);
    expect(_text(water, 1, 0), 'East Wing');
    expect(water.maxColumns, 7);
    // Every sheet covers the same days.
    expect(excel.sheets[MeterType.gas.label]!.maxRows, 5);
  });
}
