import 'dart:async';

import 'package:fl_steam_lua/core/app_paths.dart';
import 'package:fl_steam_lua/core/game_entry.dart';
import 'package:fl_steam_lua/core/settings_store.dart';
import 'package:fl_steam_lua/features/library/library_service.dart';
import 'package:fl_steam_lua/features/library/lua_editor_page.dart';
import 'package:fl_steam_lua/ui/localization.dart';
import 'package:fl_steam_lua/ui/ui.dart' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _EditorLibrary extends LibraryService {
  _EditorLibrary(AppPaths paths)
    : super(paths: paths, settings: SettingsStore(paths));
  final saved = Completer<void>();
  @override
  Future<String> readLua(int appId) async => 'addappid(10)';
  @override
  Future<void> saveLua(int appId, String content) => saved.future;
}

void main() {
  testWidgets(
    'saving Lua keeps the editor viewport fixed and shows the loading bar',
    (tester) async {
      final library = _EditorLibrary(AppPaths('fixture'));
      await tester.binding.setSurfaceSize(const Size(1100, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      addTearDown(() {
        library.settings.dispose();
        library.dispose();
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: ui.buildAppTheme(),
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: LuaEditorPage(
            library: library,
            game: const GameEntry(
              appId: 10,
              name: 'Fixture',
              luaPath: '10.lua',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final editor = find.byType(TextField);
      await tester.enterText(editor, 'addappid(10)\naddappid(11)');
      await tester.pump();
      final before = tester.getRect(editor);
      await tester.tap(find.byKey(const ValueKey('lua-editor-save')));
      for (final elapsed in [0, 16, 80, 250]) {
        await tester.pump(Duration(milliseconds: elapsed));
        expect(find.byType(ui.CommonProgressBar), findsOneWidget);
        expect(tester.getRect(editor), before);
      }
      library.saved.complete();
      await tester.pumpAndSettle();
      expect(find.byType(ui.CommonProgressBar), findsNothing);
      expect(tester.getRect(editor), before);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
