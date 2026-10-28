import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meters_app/core/strings.dart';
import 'package:meters_app/ui/screens/reading_filters.dart';

/// Opens the sort sheet over [initial]; the sheet's result lands in the
/// returned holder once Apply is tapped.
Future<List<ReadingFilters?>> _open(
  WidgetTester tester, {
  ReadingFilters initial = const ReadingFilters(),
  bool showUser = true,
}) async {
  final result = <ReadingFilters?>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => result.add(
              await showModalBottomSheet<ReadingFilters>(
                context: context,
                isScrollControlled: true,
                builder: (_) =>
                    ReadingSortSheet(initial: initial, showUser: showUser),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return result;
}

DropdownButton<ReadingSortField?> _level(WidgetTester tester, int i) => tester
    .widgetList<DropdownButton<ReadingSortField?>>(
      find.byType(DropdownButton<ReadingSortField?>),
    )
    .elementAt(i);

/// Picks [label] in level [i]'s dropdown.
Future<void> _pick(WidgetTester tester, int i, String label) async {
  await tester.tap(find.byType(DropdownButton<ReadingSortField?>).at(i));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

List<ReadingSortField?> _offered(WidgetTester tester, int i) => [
  for (final item in _level(tester, i).items!) item.value,
];

void main() {
  setUp(() => S.language = AppLanguage.en);

  testWidgets('each level offers only fields no earlier level uses', (
    tester,
  ) async {
    final result = await _open(tester);
    // Nothing chosen: the default sort, and the later levels wait for it.
    expect(_level(tester, 1).onChanged, isNull);
    expect(_level(tester, 2).onChanged, isNull);

    await _pick(tester, 0, S.sortType);
    expect(_level(tester, 1).onChanged, isNotNull);
    expect(_offered(tester, 1), isNot(contains(ReadingSortField.meterType)));
    expect(_level(tester, 2).onChanged, isNull);

    await _pick(tester, 1, S.meterNumber);
    expect(
      _offered(tester, 2),
      isNot(
        anyOf(
          contains(ReadingSortField.meterType),
          contains(ReadingSortField.meterNumber),
        ),
      ),
    );
    await _pick(tester, 2, S.sortValue);

    await tester.tap(find.text(S.applyFilters));
    await tester.pumpAndSettle();
    final sort = result.single!.sort;
    expect(sort.map((l) => l.field), [
      ReadingSortField.meterType,
      ReadingSortField.meterNumber,
      ReadingSortField.value,
    ]);
    // Each starts in its natural direction.
    expect(sort.map((l) => l.descending), [false, false, true]);
  });

  testWidgets('changing an earlier level clears what no longer fits', (
    tester,
  ) async {
    final result = await _open(
      tester,
      initial: const ReadingFilters(
        sort: [
          SortLevel(ReadingSortField.meterType),
          SortLevel(ReadingSortField.value, descending: true),
          SortLevel(ReadingSortField.day),
        ],
      ),
    );
    // Level 1 takes level 2's field: level 2 is cleared, and level 3 with
    // it, since a level can't follow an empty one.
    await _pick(tester, 0, S.sortValue);
    expect(_level(tester, 1).value, isNull);
    expect(_level(tester, 2).value, isNull);
    expect(_level(tester, 2).onChanged, isNull);

    await tester.tap(find.text(S.applyFilters));
    await tester.pumpAndSettle();
    expect(result.single!.sort, [
      const SortLevel(ReadingSortField.value, descending: true),
    ]);
  });

  testWidgets('back to the default sort keeps only its direction', (
    tester,
  ) async {
    final result = await _open(
      tester,
      initial: const ReadingFilters(
        sort: [
          SortLevel(ReadingSortField.gain),
          SortLevel(ReadingSortField.day),
        ],
      ),
      showUser: false,
    );
    // Technicians don't sort by user.
    expect(_offered(tester, 0), isNot(contains(ReadingSortField.user)));
    await _pick(tester, 0, S.sortDefault);
    expect(_level(tester, 1).value, isNull);
    await tester.tap(find.text(S.applyFilters));
    await tester.pumpAndSettle();
    expect(result.single!.sort, isEmpty);
    expect(result.single!.isDefaultSort, isTrue);
  });
}
