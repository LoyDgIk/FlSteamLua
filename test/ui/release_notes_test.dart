import 'package:fl_steam_lua/ui/ui.dart' as ui;
import 'package:fl_steam_lua/ui/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'renders headings, emphasis, code and GFM tables without source markers',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: ui.buildAppTheme(),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: ui.ReleaseNotes(
                data: '''
### 中文

- **新增** `lua.paths` 配置

> 保留说明

```lua
addappid(10)
```

| 版本 | 状态 |
| --- | --- |
| 0.1.5 | 已更新 |

### English

[Release page](https://github.com/LoyDgIk/FlSteamLua/releases)
''',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final texts = tester
          .widgetList<SelectableText>(find.byType(SelectableText))
          .map((text) => text.data ?? text.textSpan!.toPlainText())
          .join('\n');
      expect(texts, contains('中文'));
      expect(texts, contains('新增 lua.paths 配置'));
      expect(texts, contains('addappid(10)'));
      expect(texts, contains('English'));
      expect(texts, isNot(contains('###')));
      expect(texts, isNot(contains('**')));
      expect(texts, isNot(contains('```')));
      expect(texts, isNot(contains('[Release page]')));
      expect(find.byType(Table), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'release links resolve against their source and ignore local commands',
    (tester) async {
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/url_launcher'),
        (call) async {
          calls.add(call);
          return true;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/url_launcher'),
          null,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: ui.ReleaseNotes(
              data: '[Details](/LoyDgIk/FlSteamLua/releases)',
              baseUrl: Uri.parse(
                'https://github.com/LoyDgIk/FlSteamLua/releases/tag/v0.1.5',
              ),
            ),
          ),
        ),
      );
      final markdown = tester.widget<MarkdownBody>(find.byType(MarkdownBody));
      markdown.onTapLink!('unsafe', 'file:///C:/private.txt', '');
      markdown.onTapLink!('unsafe', 'steam://install/10', '');
      await tester.pump();
      expect(calls, isEmpty);
      markdown.onTapLink!('Details', '/LoyDgIk/FlSteamLua/releases', '');
      await tester.pump();
      expect(
        calls.single.arguments['url'],
        'https://github.com/LoyDgIk/FlSteamLua/releases',
      );
    },
  );
}
