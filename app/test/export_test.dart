import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meters_app/data/export/excel_export.dart';
import 'package:meters_app/ui/screens/readings_screen.dart';

void main() {
  test(
    'workbook has one Arabic sheet with a header and one row per reading',
    () {
      final rows = [
        {
          'id': 'r1',
          'value': 12345.6,
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
          'meter_location': 'المطبخ',
          'meter_floor': 2,
          'meter_description': null,
        },
      ];
      final bytes = buildReadingsWorkbook(rows);
      final excel = Excel.decodeBytes(bytes);
      expect(excel.sheets.keys, ['القراءات']);
      final sheet = excel.sheets['القراءات']!;
      expect(sheet.maxRows, 2);
      expect(sheet.rows[1][1]?.value.toString(), 'عداد المسبح');
      expect(sheet.rows[1][3]?.value.toString(), 'المبنى الرئيسي');
      expect(sheet.rows[1][4]?.value.toString(), 'المطبخ');
      expect(sheet.rows[1][6]?.value.toString(), 'SN-7');
      expect(sheet.rows[1][7]?.value, isA<DoubleCellValue>());
    },
  );

  test('filters map to API query params', () {
    const f = ReadingFilters(floor: 3, technician: 'أحمد', search: 'مطبخ');
    final q = f.toQuery();
    expect(q['floor'], '3');
    expect(q['technician'], 'أحمد');
    expect(q['search'], 'مطبخ');
    expect(q.containsKey('type'), isFalse);
    expect(q['sort'], 'logged_at');
    expect(q['dir'], 'desc');
    expect(const ReadingFilters().isEmpty, isTrue);
    expect(f.activeCount, 2);
    expect(const ReadingFilters(floor: -1).toQuery()['floor'], '-1');
    expect(
      const ReadingFilters(
        sort: ReadingSort.value,
        descending: false,
      ).toQuery()['dir'],
      'asc',
    );
  });
}
