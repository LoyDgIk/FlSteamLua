import 'package:fl_steam_lua/ui/ui.dart' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
  theme: ui.buildAppTheme(),
  home: Scaffold(body: child),
);

void main() {
  testWidgets('form row input has no outline when focused', (tester) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);
    await tester.pumpWidget(
      _host(
        Center(
          child: SizedBox(
            width: 440,
            child: ui.generateGroup([
              ui.FormRow(
                title: 'Name',
                trailing: ui.FormRowTextField(
                  focusNode: focusNode,
                  initialValue: 'FlSteamLua',
                ),
              ),
            ]),
          ),
        ),
      ),
    );

    final card = tester.widget<ui.CommonCard>(
      find.descendant(
        of: find.byType(ui.FormRow),
        matching: find.byType(ui.CommonCard),
      ),
    );
    expect(card.focusRing, isFalse);

    focusNode.requestFocus();
    await tester.pump();
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.decoration?.border?.isOutline, isFalse);
    expect(field.decoration?.focusedBorder?.isOutline, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('generic FlClash presentation components render', (tester) async {
    await tester.pumpWidget(
      _host(
        SingleChildScrollView(
          child: Column(
            children: [
              ui.TonalButtonGroup(
                children: [
                  IconButton(onPressed: () {}, icon: const Icon(Icons.add)),
                  IconButton(onPressed: () {}, icon: const Icon(Icons.close)),
                ],
              ),
              const ui.CommonChip(label: 'Lua'),
              ui.TonalChip(
                label: 'Active',
                color: Colors.blue,
                foregroundColor: Colors.white,
              ),
              const ui.MetaChip(label: 'AppID 440'),
              const ui.CommonCircleLoading(size: 24),
              const ui.SkeletonPill(width: 160, height: 16),
              const ui.CommonExpandIcon(expand: true),
              const ui.SelectionBadge(),
              ui.AnimatedEntries(
                children: const [
                  ListTile(key: ValueKey('one'), title: Text('One')),
                  ListTile(key: ValueKey('two'), title: Text('Two')),
                ],
              ),
              SizedBox(
                height: 120,
                child: ui.KeyedAnimatedList<int>(
                  items: const [1, 2],
                  keyOf: (item) => item,
                  itemBuilder: (_, item) => ListTile(title: Text('$item')),
                ),
              ),
              SizedBox(
                height: 120,
                child: ui.FloatingHeaderBody(
                  backgroundColor: Colors.white,
                  header: const SizedBox(height: 68, child: Text('Header')),
                  body: ListView(children: const [SizedBox(height: 400)]),
                ),
              ),
              SizedBox(
                height: 80,
                child: ui.LineChart(
                  values: const [1, 3, 2, 5],
                  revision: 4,
                  capacity: 12,
                  minScale: 1,
                  color: Colors.blue,
                  baselineRatio: .8,
                ),
              ),
              ui.TableCells(
                columns: const [
                  ui.TableColumn('name', 'Name', flex: 1),
                  ui.TableColumn('value', 'Value', width: 80, end: true),
                ],
                widths: const [240, 80],
                height: 48,
                inset: 8,
                cells: const [Text('Depot'), Text('42')],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(ui.TonalButtonGroup), findsOneWidget);
    expect(find.byType(ui.CommonChip), findsOneWidget);
    expect(find.byType(ui.SkeletonPill), findsOneWidget);
    expect(find.byType(ui.CommonCircleLoading), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('table columns distribute fixed and flexible widths', () {
    const columns = [
      ui.TableColumn('name', 'Name', flex: 2),
      ui.TableColumn('value', 'Value', width: 100),
      ui.TableColumn('state', 'State', flex: 1),
    ];
    expect(ui.tableColumnWidths(columns, 700), [400, 100, 200]);
  });

  test('caret popup chooses the roomier side', () {
    const layout = ui.CaretPopupLayout(
      caretRect: Rect.fromLTWH(20, 520, 2, 20),
      padding: EdgeInsets.all(8),
    );
    final position = layout.getPositionForChild(
      const Size(800, 600),
      const Size(200, 120),
    );
    expect(position.dy, lessThan(layout.caretRect.top));
  });
}
