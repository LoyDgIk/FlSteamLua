import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../ui/localization.dart';
import '../../ui/ui.dart' as ui;
import 'ticket_authorization.dart';

Future<bool?> showTicketApplySheet(
  BuildContext context, {
  required TicketApplyPlan plan,
  required String? currentAccount,
  required bool stopSteam,
}) => ui.showModalSideSheet<bool>(
  context: context,
  builder: (_) => _TicketApplySheet(
    plan: plan,
    currentAccount: currentAccount,
    stopSteam: stopSteam,
  ),
);

class _TicketApplySheet extends StatefulWidget {
  const _TicketApplySheet({
    required this.plan,
    required this.currentAccount,
    required this.stopSteam,
  });
  final TicketApplyPlan plan;
  final String? currentAccount;
  final bool stopSteam;
  @override
  State<_TicketApplySheet> createState() => _TicketApplySheetState();
}

class _TicketApplySheetState extends State<_TicketApplySheet> {
  bool _synchronize = false;
  @override
  Widget build(BuildContext context) {
    final texts = context.l10n;
    final plan = widget.plan;
    return ui.SideSheetScaffold(
      title: texts.confirmApplyTickets,
      actions: [
        ui.SideSheetHeaderButton(
          key: const ValueKey('confirm-ticket-apply'),
          tooltip: texts.applyTicket,
          icon: const ui.GlyphIcon(ui.AppGlyphs.checkCircle),
          onPressed: () => Navigator.pop(context, _synchronize),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          16,
          ui.SideSheetScaffold.headerHeight + 16,
          16,
          24,
        ),
        children: [
          ui.generateSection(
            items: [
              ui.DecorationListItem(
                title: Text(texts.currentSteamLoginAccount),
                subtitle: Text(
                  widget.currentAccount ?? texts.ticketAccountUnavailable,
                ),
              ),
              ui.DecorationListItem(
                title: Text(texts.ticketOwnerAccount),
                subtitle: Text(plan.ticket.steamId.toString()),
              ),
              ui.DecorationListItem(
                title: Text(texts.cachedAuthorizationIdentity),
                subtitle: Text(
                  plan.before.steamId ?? texts.ticketIdentityNotSet,
                ),
              ),
              if (plan.before.effectiveSteamId != plan.ticket.steamId)
                ui.ListItem.toggle(
                  key: const ValueKey('sync-ticket-identity'),
                  title: Text(
                    texts.syncAuthorizationIdentity(
                      plan.ticket.steamId.toString(),
                    ),
                  ),
                  subtitle: Text(texts.ticketIdentitySaveWarning),
                  value: _synchronize,
                  onChanged: (value) => setState(() => _synchronize = value),
                ),
            ],
            footer:
                '${_synchronize ? texts.syncAuthorizationIdentity(plan.ticket.steamId.toString()) : texts.applyTicketPreserveIdentity}\n${texts.ticketApplyBackupDescription}',
          ),
          if (plan.before.identityMismatch(plan.ticket.steamId) &&
              !_synchronize)
            ui.LogRecordCard(
              time: '',
              level: texts.ticketIdentityWarningLabel,
              message: texts.ticketCachedIdentityWarning,
              tone: ui.RecordTone.warning,
            ),
          if (plan.lua.isNotEmpty)
            ui.generateSection(
              title: texts.ticketLuaCleanup,
              items: [
                for (final edit in plan.lua)
                  ui.DecorationListItem(
                    title: Text(p.basename(edit.path)),
                    subtitle: SelectableText(
                      '${edit.path}\n${edit.statements.map((line) => '${line.line}: ${line.function}(${plan.ticket.appId}, …)').join('\n')}',
                    ),
                  ),
              ],
              footer: texts.ticketLuaCleanupDescription,
            ),
          if (widget.stopSteam)
            ui.ListFooter(text: texts.ticketStopSteamForLua),
        ],
      ),
    );
  }
}

Future<bool?> showTicketRestoreSheet(
  BuildContext context, {
  required TicketRestorePlan plan,
  required String gameName,
  required bool stopSteam,
}) => ui.showModalSideSheet<bool>(
  context: context,
  builder: (context) {
    final texts = context.l10n;
    return ui.SideSheetScaffold(
      title: texts.restorePreApplyCredentials,
      actions: [
        ui.SideSheetHeaderButton(
          tooltip: texts.restore,
          key: const ValueKey('confirm-ticket-restore'),
          icon: const ui.GlyphIcon(ui.AppGlyphs.checkCircle),
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          16,
          ui.SideSheetScaffold.headerHeight + 16,
          16,
          24,
        ),
        children: [
          ui.generateSection(
            items: [
              ui.DecorationListItem(
                title: Text(gameName),
                subtitle: Text(plan.backup.createdAt.toLocal().toString()),
              ),
              ui.DecorationListItem(
                title: Text(texts.cachedAuthorizationIdentity),
                subtitle: Text(
                  plan.target.steamId ?? texts.ticketIdentityNotSet,
                ),
              ),
              ui.DecorationListItem(
                title: Text(texts.ticketRestoreCompleteSet),
              ),
              for (final edit in plan.lua)
                ui.DecorationListItem(
                  title: Text(p.basename(edit.path)),
                  subtitle: Text(edit.path),
                ),
            ],
            footer: stopSteam ? texts.ticketStopSteamForLua : null,
          ),
        ],
      ),
    );
  },
);
