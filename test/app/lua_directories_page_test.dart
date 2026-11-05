import 'dart:io';

import 'package:fl_steam_lua/features/library/lua_directories.dart';
import 'package:fl_steam_lua/features/library/lua_directories_page.dart';
import 'package:fl_steam_lua/ui/localization.dart';
import 'package:fl_steam_lua/ui/ui.dart' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  testWidgets(
    'ordered directories save to core paths and label only index zero as default',
    (tester) async {
      late Directory root;
      late String a, b;
      var refreshes = 0;
      await tester.runAsync(() async {
        root = await Directory.systemTemp.createTemp('lua-directory-ui-');
        a = p.join(root.path, 'a');
        b = p.join(root.path, 'b');
        await LuaDirectories(root.path).save([a, b]);
      });
      await tester.binding.setSurfaceSize(const Size(1100, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      try {
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: LuaDirectoriesPage(
              steamPath: root.path,
              onSaved: () async {
                refreshes++;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Default write directory'), findsOneWidget);
        expect(
          tester
              .getTopLeft(find.byKey(const ValueKey('core-lua-directory')))
              .dy,
          lessThan(tester.getTopLeft(find.text(a)).dy),
        );
        expect(find.byType(ReorderableListView), findsNothing);
        await tester.runAsync(() async {
          tester
              .widget<IconButton>(
                find.byKey(const ValueKey('sort-lua-directories')),
              )
              .onPressed!();
        });
        await tester.pumpAndSettle();
        expect(find.byType(ui.SideSheetScaffold), findsOneWidget);
        expect(find.byType(ui.SortHandle), findsNWidgets(2));
        tester
            .widget<ReorderableListView>(find.byType(ReorderableListView))
            .onReorderItem!(1, 0);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('side-sheet-close')));
        await tester.pumpAndSettle();
        expect(LuaDirectories(root.path).read(), [a, b]);
        expect(refreshes, 0);
        await tester.runAsync(() async {
          tester
              .widget<IconButton>(
                find.byKey(const ValueKey('sort-lua-directories')),
              )
              .onPressed!();
        });
        await tester.pumpAndSettle();
        // Use the list's public reorder callback with its documented final index.
        tester
            .widget<ReorderableListView>(find.byType(ReorderableListView))
            .onReorderItem!(1, 0);
        await tester.pumpAndSettle();
        final save = tester.widget<ui.SideSheetHeaderButton>(
          find.byKey(const ValueKey('save-lua-directory-order')),
        );
        save.onPressed!();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        for (var attempt = 0; attempt < 10; attempt++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(refreshes, 1);
        await tester.pumpAndSettle();
        expect(LuaDirectories(root.path).read(), [b, a]);
        expect(refreshes, 1);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(() => root.delete(recursive: true));
      }
    },
  );
}
