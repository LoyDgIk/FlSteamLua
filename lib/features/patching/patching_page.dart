import 'package:flutter/material.dart';

import '../../core/app_paths.dart';
import '../../core/game_entry.dart';
import '../../core/settings_store.dart';
import '../../core/task_center.dart';
import '../../ui/localization.dart';
import '../../ui/ui.dart' as ui;
import '../tools/tools_service.dart';
import 'game_patch_download_page.dart';
import 'game_file_verification_page.dart';
import 'goldberg_page.dart';

class PatchSettingsPage extends StatelessWidget {
  const PatchSettingsPage({
    super.key,
    required this.paths,
    required this.settings,
    required this.tasks,
    required this.tools,
    required this.game,
  });

  final AppPaths paths;
  final SettingsStore settings;
  final TaskCenter tasks;
  final ToolsService tools;
  final GameEntry game;

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(
      ui.buildAppPageRoute(
        builder: (_) => page,
        reduceMotion: MediaQuery.disableAnimationsOf(context),
      ),
    );
  }

  Future<void> _openGameFolder(BuildContext context) async {
    final path = game.installPath;
    if (path == null) return;
    try {
      await tools.openPath(path);
    } catch (error) {
      if (context.mounted) ui.showAppError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final texts = context.l10n;
    final installed = game.installPath != null;
    return ui.CommonScaffold(
      title: texts.patchSettings,
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          ui.pageContentTopInset,
          16,
          28 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          ui.generateSection(
            title: texts.game,
            items: [
              ui.DecorationListItem(
                leading: const ui.GlyphIcon(ui.AppGlyphs.profiles, size: 20),
                title: Text(
                  game.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  'AppID ${game.appId}'
                  '${installed ? ' · ${game.installPath}' : ''}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: ui.MetaChip(
                  label: installed ? texts.installed : texts.notInstalled,
                ),
              ),
            ],
          ),
          ui.generateSection(
            title: texts.patchTools,
            items: [
              ui.DecorationListItem(
                leading: const ui.GlyphIcon(ui.AppGlyphs.verified, size: 20),
                title: Text(texts.gameFileVerification),
                subtitle: Text(texts.gameFileVerificationDescription),
                onPressed: installed
                    ? () => _push(
                        context,
                        GameFileVerificationPage(
                          game: game,
                          tools: tools,
                          tasks: tasks,
                        ),
                      )
                    : null,
                trailing: const ui.GlyphIcon(
                  ui.AppGlyphs.chevronForward,
                  size: 18,
                ),
              ),
              ui.DecorationListItem(
                leading: const ui.GlyphIcon(
                  ui.AppGlyphs.cloudDownload,
                  size: 20,
                ),
                title: Text(texts.gamePatchDownload),
                subtitle: Text(texts.gamePatchDownloadDescription),
                onPressed: () => _push(
                  context,
                  GamePatchDownloadPage(paths: paths, tasks: tasks, game: game),
                ),
                trailing: const ui.GlyphIcon(
                  ui.AppGlyphs.chevronForward,
                  size: 18,
                ),
              ),
              if (installed)
                ui.DecorationListItem(
                  leading: const ui.GlyphIcon(
                    ui.AppGlyphs.openExternal,
                    size: 20,
                  ),
                  title: Text(texts.openGameFolder),
                  subtitle: Text(game.installPath!),
                  onPressed: () => _openGameFolder(context),
                ),
            ],
            footer: texts.patchToolsDescription,
          ),
          ui.generateSection(
            title: texts.goldbergEmulator,
            items: [
              ui.DecorationListItem(
                leading: const ui.GlyphIcon(ui.AppGlyphs.puzzle, size: 20),
                title: Text(texts.goldbergSettings),
                subtitle: Text(texts.goldbergDescription),
                onPressed: installed
                    ? () => _push(
                        context,
                        GoldbergPage(
                          paths: paths,
                          settings: settings,
                          tasks: tasks,
                          game: game,
                        ),
                      )
                    : null,
                trailing: const ui.GlyphIcon(
                  ui.AppGlyphs.chevronForward,
                  size: 18,
                ),
              ),
            ],
            footer: texts.goldbergSettingsFooter,
          ),
        ],
      ),
    );
  }
}
