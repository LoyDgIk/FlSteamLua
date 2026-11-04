import 'package:flutter/material.dart';

import '../../ui/localization.dart';
import '../../ui/ui.dart' as ui;
import '../library/library_service.dart';
import 'steam_avatar.dart';

class SteamAccountManagerPage extends StatefulWidget {
  const SteamAccountManagerPage({super.key, required this.library});

  final LibraryService library;

  @override
  State<SteamAccountManagerPage> createState() =>
      _SteamAccountManagerPageState();
}

class _SteamAccountManagerPageState extends State<SteamAccountManagerPage> {
  bool _busy = false;

  Future<void> _run(String title, Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) ui.showAppSuccess(context, title);
    } catch (error) {
      if (mounted) ui.showAppError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _switch(SteamLocalAccount account) async {
    final texts = context.l10n;
    final confirmed = await ui.AppDialogs.confirm(
      context,
      title: texts.switchSteamAccount,
      message: texts.steamWillRestartToSwitchAccount,
    );
    if (confirmed != true) return;
    await _run(
      texts.switchSteamAccount,
      () => widget.library.switchAccount(account.accountName),
    );
  }

  Future<void> _add() async {
    final texts = context.l10n;
    final confirmed = await ui.AppDialogs.confirm(
      context,
      title: texts.addSteamAccount,
      message: texts.steamWillOpenItsOwnLogin,
    );
    if (confirmed != true) return;
    await _run(texts.addSteamAccount, widget.library.openSteamLogin);
  }

  Future<void> _refresh() async {
    await _run(context.l10n.refresh, widget.library.refreshAccounts);
  }

  @override
  Widget build(BuildContext context) {
    final texts = context.l10n;
    return ListenableBuilder(
      listenable: widget.library,
      builder: (context, _) {
        final accounts = widget.library.accounts;
        return ui.CommonScaffold(
          title: texts.accountManagement,
          actions: [
            IconButton(
              tooltip: texts.refresh,
              onPressed: _busy ? null : _refresh,
              icon: const ui.GlyphIcon(ui.AppGlyphs.refresh),
            ),
            IconButton(
              tooltip: texts.addSteamAccount,
              onPressed: _busy ? null : _add,
              icon: const ui.GlyphIcon(ui.AppGlyphs.add),
            ),
          ],
          body: ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              ui.pageContentTopInset,
              16,
              28 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              if (accounts.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: ui.NullStatus(
                    label: texts.noSteamAccounts,
                    description: texts.noSteamAccountsDescription,
                    illustration: ui.NullStatusIllustration.steam,
                    action: ui.TonalButton(
                      glyph: ui.AppGlyphs.add,
                      label: texts.addSteamAccount,
                      onPressed: _busy ? null : _add,
                    ),
                  ),
                )
              else
                ui.generateSection(
                  title: texts.steamAccounts,
                  items: [
                    for (final account in accounts)
                      ui.DecorationListItem(
                        leading: SteamAvatar(
                          path: widget.library.avatarPath(account),
                          size: 38,
                        ),
                        title: Text(
                          account.personaName.isEmpty
                              ? account.accountName
                              : account.personaName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          account.accountName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onPressed: account.mostRecent || _busy
                            ? null
                            : () => _switch(account),
                        trailing: ui.MetaChip(
                          label: account.mostRecent
                              ? texts.currentSteamAccount
                              : texts.switchSteamAccount,
                        ),
                      ),
                  ],
                  footer: texts.accountManagerHint,
                ),
              ui.generateSection(
                items: [
                  ui.DecorationListItem(
                    leading: const ui.GlyphIcon(ui.AppGlyphs.add, size: 20),
                    title: Text(texts.addSteamAccount),
                    subtitle: Text(texts.addSteamAccountDescription),
                    onPressed: _busy ? null : _add,
                  ),
                ],
              ),
              if (_busy)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: const ui.CommonProgressBar(value: null),
                ),
            ],
          ),
        );
      },
    );
  }
}
