import 'package:fl_steam_lua/app/task_panel.dart';
import 'package:fl_steam_lua/core/task_center.dart';
import 'package:fl_steam_lua/ui/localization.dart';
import 'package:fl_steam_lua/ui/ui.dart' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('LAN task opens its session from the task panel', (tester) async {
    final tasks = TaskCenter();
    tasks.begin('Transfer fixture', actionId: 'session-1');
    TaskProgress? opened;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: ui.buildAppTheme(seedColor: Colors.blue),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => ui.showModalSideSheet<void>(
                  context: context,
                  builder: (_) => TaskPanel(
                    tasks: tasks,
                    onTaskPressed: (task) => opened = task,
                  ),
                ),
                child: const Text('open tasks'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open tasks'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('Transfer fixture'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(opened?.actionId, 'session-1');
    tasks.dispose();
  });
}
