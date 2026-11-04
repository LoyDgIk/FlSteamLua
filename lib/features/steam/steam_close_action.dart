import 'package:flutter/widgets.dart';

import '../../core/steam_process_actions.dart';
import '../../ui/localization.dart';
import '../../ui/ui.dart' as ui;

Future<bool> confirmAndStopSteam(
  BuildContext context,
  SteamProcessActions steam,
) async {
  if (!await steam.isRunning()) return true;
  if (!context.mounted) return false;
  final localeText = context.l10n;
  final confirmed = await ui.AppDialogs.confirm(
    context,
    title: localeText.closeSteamToContinue,
    message: localeText.closeSteamToContinueDescription,
    confirmText: localeText.closeAndContinue,
    destructive: true,
  );
  if (confirmed != true) return false;
  await steam.stop();
  return true;
}
