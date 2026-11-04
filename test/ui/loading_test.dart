import 'package:fl_steam_lua/ui/ui.dart' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('indeterminate progress bar animates across a full track', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 220,
            child: ui.CommonProgressBar(value: null, height: 6),
          ),
        ),
      ),
    );
    final finder = find.byWidgetPredicate(
      (widget) =>
          widget is CustomPaint &&
          widget.painter.runtimeType.toString().contains(
            'IndeterminateProgress',
          ),
    );
    expect(finder, findsOneWidget);
    final before =
        (tester.widget<CustomPaint>(finder).painter as dynamic).progress
            as double;
    await tester.pump(const Duration(milliseconds: 250));
    final after =
        (tester.widget<CustomPaint>(finder).painter as dynamic).progress
            as double;
    expect(after, isNot(before));
  });
}
