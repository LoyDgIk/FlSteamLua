import 'package:flutter/material.dart';

import '../../core/game_entry.dart';
import '../../ui/localization.dart';
import '../../ui/ui.dart' as ui;

Future<GameEntry?> showGamePickerSheet(
  BuildContext context,
  List<GameEntry> games,
) => ui.showModalSideSheet<GameEntry>(
  context: context,
  builder: (_) => _GamePicker(games: games),
);

class _GamePicker extends StatefulWidget {
  const _GamePicker({required this.games});
  final List<GameEntry> games;
  @override
  State<_GamePicker> createState() => _GamePickerState();
}

class _GamePickerState extends State<_GamePicker> {
  String _query = '';
  late final _search = ui.AppBarSearchState(
    onSearch: (value) => setState(() => _query = value.trim().toLowerCase()),
  );
  @override
  Widget build(BuildContext context) {
    final games = widget.games
        .where(
          (game) => '${game.name} ${game.appId}'.toLowerCase().contains(_query),
        )
        .toList();
    return ui.SideSheetScaffold(
      title: context.l10n.chooseAGame,
      searchState: _search,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(
          16,
          ui.SideSheetScaffold.headerHeight + 16,
          16,
          24,
        ),
        child: ui.NullStatusSwitcher(
          isEmpty: games.isEmpty,
          isSearching: _query.isNotEmpty,
          nullStatus: ui.NullStatus(
            label: context.l10n.yourLibraryHasNoGamesYet,
            illustration: ui.NullStatusIllustration.steam,
          ),
          searchStatus: ui.NullStatus(
            label: context.l10n.noSearchResults,
            illustration: ui.NullStatusIllustration.search,
          ),
          child: ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: games.length,
            itemBuilder: (_, index) {
              final game = games[index];
              return ui.ItemPositionProvider(
                position: ui.ItemPosition.get(index, games.length),
                child: ui.DecorationListItem(
                  title: Text(game.name),
                  subtitle: Text('AppID ${game.appId}'),
                  trailing: const ui.GlyphIcon(ui.AppGlyphs.chevronForward),
                  onPressed: () => Navigator.pop(context, game),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
