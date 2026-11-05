import 'package:fl_steam_lua/app/widgets.dart';
import 'package:fl_steam_lua/ui/localization.dart';
import 'package:fl_steam_lua/ui/ui.dart' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ui.buildAppTheme(),
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ui.StatusManager(child: child),
      ),
    );
  }

  testWidgets('FlClash feedback stacks, acts and dismisses', (tester) async {
    var acted = 0;
    await pumpApp(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => Column(
            children: [
              TextButton(
                onPressed: () => context.showFeedback(
                  '保存成功',
                  level: ui.MessageLevel.success,
                ),
                child: const Text('success'),
              ),
              TextButton(
                onPressed: () => context.showFeedback(
                  '操作失败',
                  level: ui.MessageLevel.error,
                  actionState: ui.MessageActionState(
                    actionText: '重试',
                    action: () => acted++,
                  ),
                ),
                child: const Text('error'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('success'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('保存成功'), findsOneWidget);
    await tester.tap(find.text('error'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('操作失败'), findsOneWidget);
    await tester.tap(find.text('重试'));
    await tester.pump();
    expect(acted, 1);
  });

  testWidgets('showAction reports through the FlClash feedback layer', (
    tester,
  ) async {
    await pumpApp(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                showAction(context, () async => throw StateError('boom')),
            child: const Text('run'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('run'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('boom'), findsNothing);
    expect(find.text('操作未完成，可查看详情了解原因。'), findsOneWidget);
    await tester.tap(find.text('详情'));
    await tester.pumpAndSettle();
    expect(find.textContaining('boom'), findsOneWidget);
  });

  testWidgets('AppDialogs confirm uses the shared FlClash dialog route', (
    tester,
  ) async {
    bool? result;
    await pumpApp(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await ui.AppDialogs.confirm(
                context,
                title: '确认',
                message: '继续操作？',
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    expect(find.byType(ui.CommonDialog), findsOneWidget);
    await tester.tap(find.text('确认').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    expect(result, isTrue);
  });
}
