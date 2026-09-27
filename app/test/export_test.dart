import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:meters_app/data/export/excel_export.dart';
import 'package:meters_app/core/strings.dart';
import 'package:meters_app/data/models.dart';
import 'package:meters_app/ui/screens/reading_filters.dart';

void main() {
  // Month names in either language, as main() sets up on a real device.
  setUpAll(() async {
    await initializeDateFormatting('ar');
    await initializeDateFormatting('en');
  });

  test(
    'workbook has one Arabic sheet with a header and one row per reading',
    () {
      S.language = AppLanguage.ar;
      final rows = [
        {
          'id': 'r1',
          'value': 12345.6,
          'gain': 12.5,
          'photo_key': 'readings/x.jpg',
          'logged_by': 'u1',
          'logged_by_name': 'فني',
          'logged_at': '2026-09-13T10:00:00.000Z',
          'synced_at': '2026-09-13T10:01:00.000Z',
          'meter_id': 'm1',
          'meter_name': 'عداد المسبح',
          'meter_type': 'water',
          'meter_area': 'المبنى الرئيسي',
          'meter_number': 'SN-7',
        },
      ];
      final bytes = buildReadingsWorkbook(rows);
      final excel = Excel.decodeBytes(bytes);
      expect(excel.sheets.keys, ['القراءات']);
      final sheet = excel.sheets['القراءات']!;
      expect(sheet.maxRows, 2);
      expect(sheet.rows[1][1]?.value.toString(), 'عداد المسبح');
      expect(sheet.rows[1][3]?.value.toString(), 'المبنى الرئيسي');
      expect(sheet.rows[1][4]?.value.toString(), 'SN-7');
      expect(sheet.rows[1][5]?.value, isA<DoubleCellValue>());
      expect(sheet.rows[1][6]?.value, isA<DoubleCellValue>());
      expect(sheet.rows[1][7]?.value.toString(), 'م³');
    },
  );

  test('filters map to API query params', () {
    const f = ReadingFilters(
      number: 'W-9',
      userId: 'u1',
      search: 'مطبخ',
      types: {MeterType.water, MeterType.gas},
    );
    final q = f.toQuery();
    expect(q['number'], 'W-9');
    expect(q['userId'], 'u1');
    expect(q['search'], 'مطبخ');
    expect(q['type'], 'water,gas');
    expect(q.containsKey('sort'), isFalse);
    expect(f.toReadingsQuery()['sort'], 'default');
    expect(f.toReadingsQuery()['dir'], 'asc');
    expect(const ReadingFilters().isEmpty, isTrue);
    expect(const ReadingFilters().isDefaultSort, isTrue);
    expect(f.hasActiveFilters, isTrue);
    expect(
      const ReadingFilters(
        sort: ReadingSort.value,
        descending: true,
      ).toReadingsQuery()['dir'],
      'desc',
    );
  });

  test('a one-day filter covers that whole local day', () {
    final day = DateTime(2026, 9, 26);
    final q = ReadingFilters(from: day, to: day).toQuery();
    final from = DateTime.parse(q['dateFrom']!).toLocal();
    final to = DateTime.parse(q['dateTo']!).toLocal();
    expect(from, DateTime(2026, 9, 26));
    expect(to.isAfter(DateTime(2026, 9, 26, 23, 59)), isTrue);
    expect(to.day, 26);
    // The unusual check has to ask with the very same bounds.
    expect(ReadingFilters(from: day, to: day).toQuery(), q);
  });

  test('export settings pick the columns, order and sheets', () {
    S.language = AppLanguage.en;
    final rows = [
      {
        'id': 'r1',
        'value': 12345.6,
        'gain': 12.5,
        'logged_at': '2026-09-13T10:00:00.000Z',
        'synced_at': null,
        'meter_id': 'm1',
        'meter_name': 'Pool meter',
        'meter_type': 'water',
        'meter_area': 'Pool',
        'meter_number': 'SN-7',
        'logged_by_name': 'Tech',
      },
      {
        'id': 'r2',
        'value': 20.0,
        'gain': null,
        'logged_at': '2026-09-13T11:00:00.000Z',
        'synced_at': null,
        'meter_id': 'm2',
        'meter_name': 'Main panel',
        'meter_type': 'electricity',
        'meter_area': 'Plant',
        'meter_number': '3',
        'logged_by_name': 'Tech',
      },
    ];

    // Two columns, value first, as one sheet.
    var excel = Excel.decodeBytes(
      buildReadingsWorkbook(
        rows,
        settings: const ExportSettings(
          columns: [ExportColumn.value, ExportColumn.meterName],
        ),
      ),
    );
    var sheet = excel.sheets[S.sheetName]!;
    expect(sheet.rows.first.map((c) => c?.value.toString()), [
      S.colValue,
      S.colMeterName,
    ]);
    expect(sheet.rows[1][1]?.value.toString(), 'Pool meter');
    expect(sheet.maxColumns, 2);

    // A sheet per meter type, named after it, holding only its readings.
    excel = Excel.decodeBytes(
      buildReadingsWorkbook(
        rows,
        settings: const ExportSettings(sheetPerType: true),
      ),
    );
    expect(excel.sheets.keys, [
      MeterType.electricity.label,
      MeterType.water.label,
    ]);
    expect(excel.sheets[MeterType.water.label]!.maxRows, 2);
    expect(excel.sheets[MeterType.electricity.label]!.maxRows, 2);

    // Dates follow the chosen pattern.
    excel = Excel.decodeBytes(
      buildReadingsWorkbook(
        rows,
        settings: const ExportSettings(
          columns: [ExportColumn.loggedAt],
          dateFormat: 'yyyy-MM-dd',
        ),
      ),
    );
    expect(
      excel.sheets[S.sheetName]!.rows[1][0]?.value.toString(),
      '2026-09-13',
    );
  });

  test('the file is written in the language the setting asks for', () {
    S.language = AppLanguage.ar;
    final rows = [
      {
        'id': 'r1',
        'value': 10.0,
        'gain': 1.0,
        'logged_by': 'u1',
        'logged_by_name': 'Adham',
        'logged_at': '2026-09-26T09:00:00.000Z',
        'synced_at': '2026-09-26T09:01:00.000Z',
        'meter_id': 'm1',
        'meter_name': 'مطبخ الحفلات',
        'meter_type': 'water',
        'meter_area': 'المطبخ',
        'meter_number': 'W-9',
      },
    ];
    final english = Excel.decodeBytes(
      buildReadingsWorkbook(
        rows,
        settings: const ExportSettings(
          language: ExportLanguage.en,
          dateFormat: 'd MMMM yyyy',
        ),
      ),
    );
    final sheet = english.tables[english.tables.keys.first]!;
    final header = [for (final c in sheet.rows.first) c?.value.toString()];
    final body = [for (final c in sheet.rows[1]) c?.value.toString()];
    // Headers and the meter type are translated...
    expect(header, contains('Meter name'));
    expect(body, contains('Water'));
    // ...the month is spelled out in the file's language...
    expect(body.any((v) => v?.contains('September') ?? false), isTrue);
    // ...and the data itself is untouched.
    expect(body, contains('مطبخ الحفلات'));
    expect(body, contains('المطبخ'));
    expect(body, contains('W-9'));
    // The app's own language is left as it was.
    expect(S.language, AppLanguage.ar);
  });
}
