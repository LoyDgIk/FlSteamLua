import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// The native name of this language, shown in the language picker.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageName;

  /// No description provided for @updateKeySubscriptions.
  ///
  /// In en, this message translates to:
  /// **'Update key subscriptions'**
  String get updateKeySubscriptions;

  /// No description provided for @launch.
  ///
  /// In en, this message translates to:
  /// **'Launch {value1}'**
  String launch(String value1);

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'Stop {value1}'**
  String stop(String value1);

  /// No description provided for @deleteLuaRecord.
  ///
  /// In en, this message translates to:
  /// **'Delete Lua record?'**
  String get deleteLuaRecord;

  /// No description provided for @onlyThisLuaFileIsRemovedTheGameStaysInstalledAndABackupIsSavedFirst.
  ///
  /// In en, this message translates to:
  /// **'Only this Lua file is removed. The game stays installed, and a backup is saved first.'**
  String
  get onlyThisLuaFileIsRemovedTheGameStaysInstalledAndABackupIsSavedFirst;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @deleteRecord.
  ///
  /// In en, this message translates to:
  /// **'Delete record'**
  String get deleteRecord;

  /// No description provided for @deleteLuaRecord2.
  ///
  /// In en, this message translates to:
  /// **'Delete Lua record'**
  String get deleteLuaRecord2;

  /// No description provided for @unfavorite.
  ///
  /// In en, this message translates to:
  /// **'Unfavorite'**
  String get unfavorite;

  /// No description provided for @favorite.
  ///
  /// In en, this message translates to:
  /// **'Favorite'**
  String get favorite;

  /// No description provided for @manage.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get manage;

  /// No description provided for @manageSaves.
  ///
  /// In en, this message translates to:
  /// **'Manage saves'**
  String get manageSaves;

  /// No description provided for @manageAchievements.
  ///
  /// In en, this message translates to:
  /// **'Manage achievements'**
  String get manageAchievements;

  /// No description provided for @trainers.
  ///
  /// In en, this message translates to:
  /// **'Trainers'**
  String get trainers;

  /// No description provided for @onlineFixes.
  ///
  /// In en, this message translates to:
  /// **'Online fixes'**
  String get onlineFixes;

  /// No description provided for @dlcAnalysis.
  ///
  /// In en, this message translates to:
  /// **'DLC management'**
  String get dlcAnalysis;

  /// No description provided for @keySubscriptionsOfflineLua.
  ///
  /// In en, this message translates to:
  /// **'Key subscriptions & offline Lua'**
  String get keySubscriptionsOfflineLua;

  /// No description provided for @gameToolsAndVersionManagement.
  ///
  /// In en, this message translates to:
  /// **'Game tools and version management'**
  String get gameToolsAndVersionManagement;

  /// No description provided for @installOrRestorePatches.
  ///
  /// In en, this message translates to:
  /// **'Install or restore patches'**
  String get installOrRestorePatches;

  /// No description provided for @extractAccountGameData.
  ///
  /// In en, this message translates to:
  /// **'Extract account game data'**
  String get extractAccountGameData;

  /// No description provided for @running.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get running;

  /// No description provided for @installed.
  ///
  /// In en, this message translates to:
  /// **'Installed'**
  String get installed;

  /// No description provided for @luaConfigured.
  ///
  /// In en, this message translates to:
  /// **'Lua configured'**
  String get luaConfigured;

  /// No description provided for @luaDisabled.
  ///
  /// In en, this message translates to:
  /// **'Lua disabled'**
  String get luaDisabled;

  /// No description provided for @accountOwnsThisGame.
  ///
  /// In en, this message translates to:
  /// **'Account owns this game'**
  String get accountOwnsThisGame;

  /// No description provided for @notOwnedByAccount.
  ///
  /// In en, this message translates to:
  /// **'Not owned by account'**
  String get notOwnedByAccount;

  /// No description provided for @ownershipUnknown.
  ///
  /// In en, this message translates to:
  /// **'Ownership unknown'**
  String get ownershipUnknown;

  /// No description provided for @stopGame.
  ///
  /// In en, this message translates to:
  /// **'Stop game'**
  String get stopGame;

  /// No description provided for @play.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// No description provided for @installWithSteam.
  ///
  /// In en, this message translates to:
  /// **'Install with Steam'**
  String get installWithSteam;

  /// No description provided for @getLuaManifests.
  ///
  /// In en, this message translates to:
  /// **'Get Lua / manifests'**
  String get getLuaManifests;

  /// No description provided for @addToLibrary.
  ///
  /// In en, this message translates to:
  /// **'Add to library'**
  String get addToLibrary;

  /// No description provided for @openGameFolder.
  ///
  /// In en, this message translates to:
  /// **'Open game folder'**
  String get openGameFolder;

  /// No description provided for @playtime.
  ///
  /// In en, this message translates to:
  /// **'Playtime'**
  String get playtime;

  /// No description provided for @minutes.
  ///
  /// In en, this message translates to:
  /// **'{playtimeMinutes} minutes'**
  String minutes(String playtimeMinutes);

  /// No description provided for @lastPlayed.
  ///
  /// In en, this message translates to:
  /// **'Last played'**
  String get lastPlayed;

  /// No description provided for @notRecorded.
  ///
  /// In en, this message translates to:
  /// **'Not recorded'**
  String get notRecorded;

  /// No description provided for @diskSpace.
  ///
  /// In en, this message translates to:
  /// **'Disk space'**
  String get diskSpace;

  /// No description provided for @storePrice.
  ///
  /// In en, this message translates to:
  /// **'Store price'**
  String get storePrice;

  /// No description provided for @achievements.
  ///
  /// In en, this message translates to:
  /// **'Achievements'**
  String get achievements;

  /// No description provided for @viewAndManageGameAchievements.
  ///
  /// In en, this message translates to:
  /// **'View and manage game achievements'**
  String get viewAndManageGameAchievements;

  /// No description provided for @cloudSaves.
  ///
  /// In en, this message translates to:
  /// **'Cloud saves'**
  String get cloudSaves;

  /// No description provided for @backUpSyncAndRestoreProgress.
  ///
  /// In en, this message translates to:
  /// **'Back up, sync and restore progress'**
  String get backUpSyncAndRestoreProgress;

  /// No description provided for @gameManagement.
  ///
  /// In en, this message translates to:
  /// **'Game management'**
  String get gameManagement;

  /// No description provided for @trainersMultiplayerAndMore.
  ///
  /// In en, this message translates to:
  /// **'Trainers, multiplayer and more'**
  String get trainersMultiplayerAndMore;

  /// No description provided for @luaRecord.
  ///
  /// In en, this message translates to:
  /// **'Lua record'**
  String get luaRecord;

  /// No description provided for @enabledTakesEffectAfterRestartingSteam.
  ///
  /// In en, this message translates to:
  /// **'Enabled; takes effect after restarting Steam'**
  String get enabledTakesEffectAfterRestartingSteam;

  /// No description provided for @disabledFileIsPreserved.
  ///
  /// In en, this message translates to:
  /// **'Disabled; file is preserved'**
  String get disabledFileIsPreserved;

  /// No description provided for @changeLuaState.
  ///
  /// In en, this message translates to:
  /// **'Change Lua state'**
  String get changeLuaState;

  /// No description provided for @aboutThisGame.
  ///
  /// In en, this message translates to:
  /// **'About this game'**
  String get aboutThisGame;

  /// No description provided for @steamStore.
  ///
  /// In en, this message translates to:
  /// **'Steam store'**
  String get steamStore;

  /// No description provided for @storeDetailsAreUnavailableLocalGameActionsRemainAvailable.
  ///
  /// In en, this message translates to:
  /// **'Store details are unavailable. Local game actions remain available.'**
  String get storeDetailsAreUnavailableLocalGameActionsRemainAvailable;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @developer.
  ///
  /// In en, this message translates to:
  /// **'Developer'**
  String get developer;

  /// No description provided for @released.
  ///
  /// In en, this message translates to:
  /// **'Released'**
  String get released;

  /// No description provided for @selectDlcManifestsToRetrieveThisDoesNotPurchaseOrInstallDlc.
  ///
  /// In en, this message translates to:
  /// **'Select DLC manifests to retrieve. This does not purchase or install DLC.'**
  String get selectDlcManifestsToRetrieveThisDoesNotPurchaseOrInstallDlc;

  /// No description provided for @loadDlcNames.
  ///
  /// In en, this message translates to:
  /// **'Load DLC names'**
  String get loadDlcNames;

  /// No description provided for @clearSelection.
  ///
  /// In en, this message translates to:
  /// **'Clear selection'**
  String get clearSelection;

  /// No description provided for @getSelected.
  ///
  /// In en, this message translates to:
  /// **'Get selected ({selectedDlcCount})'**
  String getSelected(String selectedDlcCount);

  /// No description provided for @importLuaAndManifests.
  ///
  /// In en, this message translates to:
  /// **'Import Lua and manifests'**
  String get importLuaAndManifests;

  /// No description provided for @importResults.
  ///
  /// In en, this message translates to:
  /// **'Import results'**
  String get importResults;

  /// No description provided for @completedSkippedFailed.
  ///
  /// In en, this message translates to:
  /// **'Completed {writtenCount} · Skipped {skippedCount} · Failed {errorsCount}'**
  String completedSkippedFailed(
    String writtenCount,
    String skippedCount,
    String errorsCount,
  );

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @existingFilesLeftUnchanged.
  ///
  /// In en, this message translates to:
  /// **'Existing files, left unchanged'**
  String get existingFilesLeftUnchanged;

  /// No description provided for @errors.
  ///
  /// In en, this message translates to:
  /// **'Errors'**
  String get errors;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @backUpAndReimportWithOverwrite.
  ///
  /// In en, this message translates to:
  /// **'Back up and reimport with overwrite'**
  String get backUpAndReimportWithOverwrite;

  /// No description provided for @fetchGameNamesAndCovers.
  ///
  /// In en, this message translates to:
  /// **'Fetch game names and covers'**
  String get fetchGameNamesAndCovers;

  /// No description provided for @chooseALuaAndManifestFolder.
  ///
  /// In en, this message translates to:
  /// **'Choose a Lua and manifest folder'**
  String get chooseALuaAndManifestFolder;

  /// No description provided for @exportLuaToFolder.
  ///
  /// In en, this message translates to:
  /// **'Export Lua to folder'**
  String get exportLuaToFolder;

  /// No description provided for @exportLua.
  ///
  /// In en, this message translates to:
  /// **'Export Lua'**
  String get exportLua;

  /// No description provided for @exportResults.
  ///
  /// In en, this message translates to:
  /// **'Export results'**
  String get exportResults;

  /// No description provided for @enableSelectedLua.
  ///
  /// In en, this message translates to:
  /// **'Enable selected Lua'**
  String get enableSelectedLua;

  /// No description provided for @disableSelectedLua.
  ///
  /// In en, this message translates to:
  /// **'Disable selected Lua'**
  String get disableSelectedLua;

  /// No description provided for @deleteLua.
  ///
  /// In en, this message translates to:
  /// **'Delete Lua'**
  String get deleteLua;

  /// No description provided for @deleteLuaFiles.
  ///
  /// In en, this message translates to:
  /// **'Delete {targetsCount} Lua files?'**
  String deleteLuaFiles(String targetsCount);

  /// No description provided for @luaFilesAreBackedUpBeforeDeletionSteamGamesAndSavesAreKept.
  ///
  /// In en, this message translates to:
  /// **'Lua files are backed up before deletion. Steam games and saves are kept.\n\n{value1}'**
  String luaFilesAreBackedUpBeforeDeletionSteamGamesAndSavesAreKept(
    String value1,
  );

  /// No description provided for @backUpAndDelete.
  ///
  /// In en, this message translates to:
  /// **'Back up and delete'**
  String get backUpAndDelete;

  /// No description provided for @gameDetails.
  ///
  /// In en, this message translates to:
  /// **'Game details'**
  String get gameDetails;

  /// No description provided for @editLua.
  ///
  /// In en, this message translates to:
  /// **'Edit Lua'**
  String get editLua;

  /// No description provided for @disableLua.
  ///
  /// In en, this message translates to:
  /// **'Disable Lua'**
  String get disableLua;

  /// No description provided for @enableLua.
  ///
  /// In en, this message translates to:
  /// **'Enable Lua'**
  String get enableLua;

  /// No description provided for @openLuaFolder.
  ///
  /// In en, this message translates to:
  /// **'Open Lua folder'**
  String get openLuaFolder;

  /// No description provided for @pinLatestPublicVersion.
  ///
  /// In en, this message translates to:
  /// **'Pin latest public version'**
  String get pinLatestPublicVersion;

  /// No description provided for @pinInstalledVersion.
  ///
  /// In en, this message translates to:
  /// **'Pin installed version'**
  String get pinInstalledVersion;

  /// No description provided for @unpinVersion.
  ///
  /// In en, this message translates to:
  /// **'Unpin version'**
  String get unpinVersion;

  /// No description provided for @dlcManagementAndAnalysis.
  ///
  /// In en, this message translates to:
  /// **'DLC management and analysis'**
  String get dlcManagementAndAnalysis;

  /// No description provided for @manageGameSaves.
  ///
  /// In en, this message translates to:
  /// **'Manage game saves'**
  String get manageGameSaves;

  /// No description provided for @editAchievements.
  ///
  /// In en, this message translates to:
  /// **'Edit achievements'**
  String get editAchievements;

  /// No description provided for @manageGamePatches.
  ///
  /// In en, this message translates to:
  /// **'Manage game patches'**
  String get manageGamePatches;

  /// No description provided for @copyAppid.
  ///
  /// In en, this message translates to:
  /// **'Copy AppID'**
  String get copyAppid;

  /// No description provided for @updateManifestPins.
  ///
  /// In en, this message translates to:
  /// **'Update manifest pins'**
  String get updateManifestPins;

  /// No description provided for @launchGame.
  ///
  /// In en, this message translates to:
  /// **'Launch game'**
  String get launchGame;

  /// No description provided for @manage2.
  ///
  /// In en, this message translates to:
  /// **'Manage {value1}'**
  String manage2(String value1);

  /// No description provided for @min.
  ///
  /// In en, this message translates to:
  /// **'{playtimeMinutes} min'**
  String min(String playtimeMinutes);

  /// No description provided for @luaEnabled.
  ///
  /// In en, this message translates to:
  /// **'Lua enabled'**
  String get luaEnabled;

  /// No description provided for @luaDisabled2.
  ///
  /// In en, this message translates to:
  /// **'Lua disabled'**
  String get luaDisabled2;

  /// No description provided for @game.
  ///
  /// In en, this message translates to:
  /// **'Game'**
  String get game;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @luaFile.
  ///
  /// In en, this message translates to:
  /// **'Lua file'**
  String get luaFile;

  /// No description provided for @selected.
  ///
  /// In en, this message translates to:
  /// **'Selected {selectedCount} / {gamesCount}'**
  String selected(String selectedCount, String gamesCount);

  /// No description provided for @selectAllFiltered.
  ///
  /// In en, this message translates to:
  /// **'Select all filtered'**
  String get selectAllFiltered;

  /// No description provided for @clearSelection2.
  ///
  /// In en, this message translates to:
  /// **'Clear selection'**
  String get clearSelection2;

  /// No description provided for @enableSelected.
  ///
  /// In en, this message translates to:
  /// **'Enable selected'**
  String get enableSelected;

  /// No description provided for @disableSelected.
  ///
  /// In en, this message translates to:
  /// **'Disable selected'**
  String get disableSelected;

  /// No description provided for @export.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get export;

  /// No description provided for @library.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get library;

  /// No description provided for @manageLuaConfigurationsAndInstalledGames.
  ///
  /// In en, this message translates to:
  /// **'Manage Lua configurations and installed games.'**
  String get manageLuaConfigurationsAndInstalledGames;

  /// No description provided for @import.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get import;

  /// No description provided for @importFilesOrArchives.
  ///
  /// In en, this message translates to:
  /// **'Import files or archives'**
  String get importFilesOrArchives;

  /// No description provided for @importFolder.
  ///
  /// In en, this message translates to:
  /// **'Import folder'**
  String get importFolder;

  /// No description provided for @luaLibrary.
  ///
  /// In en, this message translates to:
  /// **'Lua library'**
  String get luaLibrary;

  /// No description provided for @steamGames.
  ///
  /// In en, this message translates to:
  /// **'Steam games'**
  String get steamGames;

  /// No description provided for @searchGameNamesOrAppid.
  ///
  /// In en, this message translates to:
  /// **'Search game names or AppID'**
  String get searchGameNamesOrAppid;

  /// No description provided for @rescan.
  ///
  /// In en, this message translates to:
  /// **'Rescan'**
  String get rescan;

  /// No description provided for @view.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get view;

  /// No description provided for @gridView.
  ///
  /// In en, this message translates to:
  /// **'Grid view'**
  String get gridView;

  /// No description provided for @listView.
  ///
  /// In en, this message translates to:
  /// **'List view'**
  String get listView;

  /// No description provided for @tableView.
  ///
  /// In en, this message translates to:
  /// **'Table view'**
  String get tableView;

  /// No description provided for @sort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sort;

  /// No description provided for @filter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get filter;

  /// No description provided for @nameAscending.
  ///
  /// In en, this message translates to:
  /// **'Name ascending'**
  String get nameAscending;

  /// No description provided for @nameDescending.
  ///
  /// In en, this message translates to:
  /// **'Name descending'**
  String get nameDescending;

  /// No description provided for @recentlyPlayed.
  ///
  /// In en, this message translates to:
  /// **'Recently played'**
  String get recentlyPlayed;

  /// No description provided for @libraryActions.
  ///
  /// In en, this message translates to:
  /// **'Library actions'**
  String get libraryActions;

  /// No description provided for @refreshGameInformation.
  ///
  /// In en, this message translates to:
  /// **'Refresh game information'**
  String get refreshGameInformation;

  /// No description provided for @disableSteamOfflineMode.
  ///
  /// In en, this message translates to:
  /// **'Disable Steam offline mode'**
  String get disableSteamOfflineMode;

  /// No description provided for @enableSteamOfflineMode.
  ///
  /// In en, this message translates to:
  /// **'Enable Steam offline mode'**
  String get enableSteamOfflineMode;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @enabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get enabled;

  /// No description provided for @disabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get disabled;

  /// No description provided for @favorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favorites;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @select.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get select;

  /// No description provided for @informationCouldNotBeLoadedForGamesLocalRecordsAreKept.
  ///
  /// In en, this message translates to:
  /// **'Information could not be loaded for {metadataErrorsCount} games. Local records are kept.'**
  String informationCouldNotBeLoadedForGamesLocalRecordsAreKept(
    String metadataErrorsCount,
  );

  /// No description provided for @libraryDetails.
  ///
  /// In en, this message translates to:
  /// **'Library details'**
  String get libraryDetails;

  /// No description provided for @details.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get details;

  /// No description provided for @descriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get descriptionLabel;

  /// No description provided for @connectYourSteamLibrary.
  ///
  /// In en, this message translates to:
  /// **'Connect your Steam library'**
  String get connectYourSteamLibrary;

  /// No description provided for @chooseYourSteamInstallationToReadLuaConfigurationsAndInstalledGames.
  ///
  /// In en, this message translates to:
  /// **'Choose your Steam installation to read Lua configurations and installed games.'**
  String
  get chooseYourSteamInstallationToReadLuaConfigurationsAndInstalledGames;

  /// No description provided for @chooseSteamFolder.
  ///
  /// In en, this message translates to:
  /// **'Choose Steam folder'**
  String get chooseSteamFolder;

  /// No description provided for @noMatchingLuaConfigurations.
  ///
  /// In en, this message translates to:
  /// **'No matching Lua configurations'**
  String get noMatchingLuaConfigurations;

  /// No description provided for @noMatchingInstalledGames.
  ///
  /// In en, this message translates to:
  /// **'No matching installed games'**
  String get noMatchingInstalledGames;

  /// No description provided for @noSearchResults.
  ///
  /// In en, this message translates to:
  /// **'No matching results'**
  String get noSearchResults;

  /// No description provided for @dropLuaFilesManifestsOrArchivesHereOrChangeTheFilter.
  ///
  /// In en, this message translates to:
  /// **'Drop Lua files, manifests or archives here, or change the filter.'**
  String get dropLuaFilesManifestsOrArchivesHereOrChangeTheFilter;

  /// No description provided for @installedGamesAreReadFromSteamAppmanifestFilesLuaConfigurationsAreInTheFirstTab.
  ///
  /// In en, this message translates to:
  /// **'Installed games are read from Steam appmanifest files. Lua configurations are in the first tab.'**
  String
  get installedGamesAreReadFromSteamAppmanifestFilesLuaConfigurationsAreInTheFirstTab;

  /// No description provided for @importLua.
  ///
  /// In en, this message translates to:
  /// **'Import Lua'**
  String get importLua;

  /// No description provided for @chooseASteamFolderFirst.
  ///
  /// In en, this message translates to:
  /// **'Choose a Steam folder first'**
  String get chooseASteamFolderFirst;

  /// No description provided for @dropToImportLuaManifestsOrArchives.
  ///
  /// In en, this message translates to:
  /// **'Drop to import Lua, manifests or archives'**
  String get dropToImportLuaManifestsOrArchives;

  /// No description provided for @owned.
  ///
  /// In en, this message translates to:
  /// **'Owned'**
  String get owned;

  /// No description provided for @tasks.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get tasks;

  /// No description provided for @clearCompleted.
  ///
  /// In en, this message translates to:
  /// **'Clear completed'**
  String get clearCompleted;

  /// No description provided for @allClear.
  ///
  /// In en, this message translates to:
  /// **'All clear'**
  String get allClear;

  /// No description provided for @downloadsImportsAndBackupsWillAppearHere.
  ///
  /// In en, this message translates to:
  /// **'Downloads, imports and backups will appear here.'**
  String get downloadsImportsAndBackupsWillAppearHere;

  /// No description provided for @cancelling.
  ///
  /// In en, this message translates to:
  /// **'Cancelling…'**
  String get cancelling;

  /// No description provided for @showLogs.
  ///
  /// In en, this message translates to:
  /// **'Show logs'**
  String get showLogs;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// No description provided for @stop2.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop2;

  /// No description provided for @linkedTrainer.
  ///
  /// In en, this message translates to:
  /// **'{Stop} linked trainer · {appId}'**
  String linkedTrainer(String Stop, String appId);

  /// No description provided for @discardPendingChanges.
  ///
  /// In en, this message translates to:
  /// **'Discard pending changes?'**
  String get discardPendingChanges;

  /// No description provided for @reloadingOrSwitchingGamesDiscardsUnsavedAchievementAndStatisticChanges.
  ///
  /// In en, this message translates to:
  /// **'Reloading or switching games discards unsaved achievement and statistic changes.'**
  String
  get reloadingOrSwitchingGamesDiscardsUnsavedAchievementAndStatisticChanges;

  /// No description provided for @keepEditing.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get keepEditing;

  /// No description provided for @discardAndContinue.
  ///
  /// In en, this message translates to:
  /// **'Discard and continue'**
  String get discardAndContinue;

  /// No description provided for @chooseAGameToManageAchievementsAndStatisticsGames.
  ///
  /// In en, this message translates to:
  /// **'Choose a game to manage achievements and statistics. {allGamesCount} games'**
  String chooseAGameToManageAchievementsAndStatisticsGames(
    String allGamesCount,
  );

  /// No description provided for @searchGamesOrAppid.
  ///
  /// In en, this message translates to:
  /// **'Search games or AppID'**
  String get searchGamesOrAppid;

  /// No description provided for @appidAscending.
  ///
  /// In en, this message translates to:
  /// **'AppID ascending'**
  String get appidAscending;

  /// No description provided for @appidDescending.
  ///
  /// In en, this message translates to:
  /// **'AppID descending'**
  String get appidDescending;

  /// No description provided for @continueEditing.
  ///
  /// In en, this message translates to:
  /// **'Continue editing {value1}'**
  String continueEditing(String value1);

  /// No description provided for @pendingChanges.
  ///
  /// In en, this message translates to:
  /// **'pending changes'**
  String get pendingChanges;

  /// No description provided for @yourLibraryHasNoGamesYet.
  ///
  /// In en, this message translates to:
  /// **'Your library has no games yet'**
  String get yourLibraryHasNoGamesYet;

  /// No description provided for @noMatchingGames.
  ///
  /// In en, this message translates to:
  /// **'No matching games'**
  String get noMatchingGames;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save {count} changes'**
  String saveChanges(String count);

  /// No description provided for @unlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get unlock;

  /// No description provided for @lock.
  ///
  /// In en, this message translates to:
  /// **'Lock'**
  String get lock;

  /// No description provided for @saveToSteam.
  ///
  /// In en, this message translates to:
  /// **'Save to Steam'**
  String get saveToSteam;

  /// No description provided for @savedAndConfirmedByReadingBackFromSteam.
  ///
  /// In en, this message translates to:
  /// **'Saved and confirmed by reading back from Steam.'**
  String get savedAndConfirmedByReadingBackFromSteam;

  /// No description provided for @integerValue.
  ///
  /// In en, this message translates to:
  /// **'Integer value'**
  String get integerValue;

  /// No description provided for @value.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get value;

  /// No description provided for @enterAValidValueInRange.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid value in range'**
  String get enterAValidValueInRange;

  /// No description provided for @stageChange.
  ///
  /// In en, this message translates to:
  /// **'Stage change'**
  String get stageChange;

  /// No description provided for @chooseAGame.
  ///
  /// In en, this message translates to:
  /// **'Choose a game'**
  String get chooseAGame;

  /// No description provided for @reload.
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get reload;

  /// No description provided for @unlocked.
  ///
  /// In en, this message translates to:
  /// **'unlocked'**
  String get unlocked;

  /// No description provided for @couldNotLoadAchievements.
  ///
  /// In en, this message translates to:
  /// **'Could not load achievements'**
  String get couldNotLoadAchievements;

  /// No description provided for @startSteamSignInThenSelectReload.
  ///
  /// In en, this message translates to:
  /// **'Start Steam, sign in, then select Reload.'**
  String get startSteamSignInThenSelectReload;

  /// No description provided for @statistics.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get statistics;

  /// No description provided for @searchAchievements.
  ///
  /// In en, this message translates to:
  /// **'Search achievements'**
  String get searchAchievements;

  /// No description provided for @unlocked2.
  ///
  /// In en, this message translates to:
  /// **'Unlocked'**
  String get unlocked2;

  /// No description provided for @locked.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get locked;

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// No description provided for @unlockAll.
  ///
  /// In en, this message translates to:
  /// **'Unlock all'**
  String get unlockAll;

  /// No description provided for @lockAll.
  ///
  /// In en, this message translates to:
  /// **'Lock all'**
  String get lockAll;

  /// No description provided for @invert.
  ///
  /// In en, this message translates to:
  /// **'Invert'**
  String get invert;

  /// No description provided for @noMatchingAchievements.
  ///
  /// In en, this message translates to:
  /// **'No matching achievements'**
  String get noMatchingAchievements;

  /// No description provided for @thisAchievementIsManagedByTheGameServer.
  ///
  /// In en, this message translates to:
  /// **'This achievement is managed by the game server'**
  String get thisAchievementIsManagedByTheGameServer;

  /// No description provided for @hiddenAchievement.
  ///
  /// In en, this message translates to:
  /// **'Hidden achievement'**
  String get hiddenAchievement;

  /// No description provided for @searchStatisticNameOrId.
  ///
  /// In en, this message translates to:
  /// **'Search statistic name or ID'**
  String get searchStatisticNameOrId;

  /// No description provided for @noReadableLocalStatisticsForThisGame.
  ///
  /// In en, this message translates to:
  /// **'No readable local statistics for this game'**
  String get noReadableLocalStatisticsForThisGame;

  /// No description provided for @noMatchingStatistics.
  ///
  /// In en, this message translates to:
  /// **'No matching statistics'**
  String get noMatchingStatistics;

  /// No description provided for @editStatistic.
  ///
  /// In en, this message translates to:
  /// **'Edit statistic'**
  String get editStatistic;

  /// No description provided for @changesPending.
  ///
  /// In en, this message translates to:
  /// **'{value1} changes pending'**
  String changesPending(String value1);

  /// No description provided for @changesAreSubmittedToSteamWhenSaved.
  ///
  /// In en, this message translates to:
  /// **'Changes are submitted to Steam when saved'**
  String get changesAreSubmittedToSteamWhenSaved;

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// No description provided for @saveChanges2.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get saveChanges2;

  /// No description provided for @loadCloudSaves.
  ///
  /// In en, this message translates to:
  /// **'Load cloud saves'**
  String get loadCloudSaves;

  /// No description provided for @completed2.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed2;

  /// No description provided for @localFolder.
  ///
  /// In en, this message translates to:
  /// **'Local folder'**
  String get localFolder;

  /// No description provided for @configureLocalRedirectionAndRemoteStorageSeparately.
  ///
  /// In en, this message translates to:
  /// **'Configure local redirection and remote storage separately.'**
  String get configureLocalRedirectionAndRemoteStorageSeparately;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @refreshCloudSaves.
  ///
  /// In en, this message translates to:
  /// **'Refresh cloud saves'**
  String get refreshCloudSaves;

  /// No description provided for @localSaveRedirection.
  ///
  /// In en, this message translates to:
  /// **'Local save redirection'**
  String get localSaveRedirection;

  /// No description provided for @enabledRestartSteamAfterChanges.
  ///
  /// In en, this message translates to:
  /// **'Enabled; restart Steam after changes'**
  String get enabledRestartSteamAfterChanges;

  /// No description provided for @disabledEnablingDownloadsAndVerifiesTheCloudredirectDll.
  ///
  /// In en, this message translates to:
  /// **'Disabled; enabling downloads and verifies the CloudRedirect DLL'**
  String get disabledEnablingDownloadsAndVerifiesTheCloudredirectDll;

  /// No description provided for @enableSaveRedirection.
  ///
  /// In en, this message translates to:
  /// **'Enable save redirection'**
  String get enableSaveRedirection;

  /// No description provided for @downloadCloudredirectAndUpdateSteamFilesAndKernelConfigurationRestartSteamAfterwards.
  ///
  /// In en, this message translates to:
  /// **'Download CloudRedirect and update Steam files and kernel configuration. Restart Steam afterwards.'**
  String
  get downloadCloudredirectAndUpdateSteamFilesAndKernelConfigurationRestartSteamAfterwards;

  /// No description provided for @configureRedirection.
  ///
  /// In en, this message translates to:
  /// **'Configure redirection'**
  String get configureRedirection;

  /// No description provided for @localSaveFolder.
  ///
  /// In en, this message translates to:
  /// **'Local save folder'**
  String get localSaveFolder;

  /// No description provided for @remoteStorage.
  ///
  /// In en, this message translates to:
  /// **'Remote storage'**
  String get remoteStorage;

  /// No description provided for @configured.
  ///
  /// In en, this message translates to:
  /// **'Configured'**
  String get configured;

  /// No description provided for @remoteSyncIsNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Remote sync is not configured'**
  String get remoteSyncIsNotConfigured;

  /// No description provided for @configure.
  ///
  /// In en, this message translates to:
  /// **'Configure'**
  String get configure;

  /// No description provided for @testCloudConnection.
  ///
  /// In en, this message translates to:
  /// **'Test cloud connection'**
  String get testCloudConnection;

  /// No description provided for @testConnection.
  ///
  /// In en, this message translates to:
  /// **'Test connection'**
  String get testConnection;

  /// No description provided for @connectCloudAccount.
  ///
  /// In en, this message translates to:
  /// **'Connect cloud account'**
  String get connectCloudAccount;

  /// No description provided for @authorize.
  ///
  /// In en, this message translates to:
  /// **'Authorize'**
  String get authorize;

  /// No description provided for @disconnectAccount.
  ///
  /// In en, this message translates to:
  /// **'Disconnect account'**
  String get disconnectAccount;

  /// No description provided for @removeLocalCredentialsRemoteSavesRemain.
  ///
  /// In en, this message translates to:
  /// **'Remove local credentials. Remote saves remain.'**
  String get removeLocalCredentialsRemoteSavesRemain;

  /// No description provided for @disconnectAccount2.
  ///
  /// In en, this message translates to:
  /// **'Disconnect account'**
  String get disconnectAccount2;

  /// No description provided for @disconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnect;

  /// No description provided for @gameSaves.
  ///
  /// In en, this message translates to:
  /// **'Game saves'**
  String get gameSaves;

  /// No description provided for @backups.
  ///
  /// In en, this message translates to:
  /// **'Backups'**
  String get backups;

  /// No description provided for @dataManagement.
  ///
  /// In en, this message translates to:
  /// **'Data management'**
  String get dataManagement;

  /// No description provided for @storageUsage.
  ///
  /// In en, this message translates to:
  /// **'Storage usage'**
  String get storageUsage;

  /// No description provided for @storageLocations.
  ///
  /// In en, this message translates to:
  /// **'Storage locations'**
  String get storageLocations;

  /// No description provided for @storageLocationsDescription.
  ///
  /// In en, this message translates to:
  /// **'Cache, backups, downloads, and logs can use separate folders. Lua stays managed by Steam and game files.'**
  String get storageLocationsDescription;

  /// No description provided for @appCache.
  ///
  /// In en, this message translates to:
  /// **'Cache'**
  String get appCache;

  /// No description provided for @logs.
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get logs;

  /// No description provided for @appData.
  ///
  /// In en, this message translates to:
  /// **'App data'**
  String get appData;

  /// No description provided for @lanTransferCache.
  ///
  /// In en, this message translates to:
  /// **'LAN transfer cache'**
  String get lanTransferCache;

  /// No description provided for @cleanup.
  ///
  /// In en, this message translates to:
  /// **'Cleanup'**
  String get cleanup;

  /// No description provided for @clearCache.
  ///
  /// In en, this message translates to:
  /// **'Clear cache'**
  String get clearCache;

  /// No description provided for @clearCacheDescription.
  ///
  /// In en, this message translates to:
  /// **'Remove covers, cached metadata, key caches, and LAN transfer chunks.'**
  String get clearCacheDescription;

  /// No description provided for @clearCacheConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Clear all cached files? Backups, downloads, settings, and save data are not removed.'**
  String get clearCacheConfirmation;

  /// No description provided for @clearingCache.
  ///
  /// In en, this message translates to:
  /// **'Clearing cached files'**
  String get clearingCache;

  /// No description provided for @cacheCleared.
  ///
  /// In en, this message translates to:
  /// **'Cache cleared'**
  String get cacheCleared;

  /// No description provided for @scanningStorage.
  ///
  /// In en, this message translates to:
  /// **'Calculating storage usage'**
  String get scanningStorage;

  /// No description provided for @changeStorageFolder.
  ///
  /// In en, this message translates to:
  /// **'Change folder'**
  String get changeStorageFolder;

  /// No description provided for @chooseStorageFolder.
  ///
  /// In en, this message translates to:
  /// **'Choose storage folder'**
  String get chooseStorageFolder;

  /// No description provided for @storageChangeBlockedByTasks.
  ///
  /// In en, this message translates to:
  /// **'Wait for running tasks to finish before changing storage folders.'**
  String get storageChangeBlockedByTasks;

  /// No description provided for @chooseSeparateStorageFolder.
  ///
  /// In en, this message translates to:
  /// **'Choose a folder that is not inside the current storage folder.'**
  String get chooseSeparateStorageFolder;

  /// No description provided for @chooseEmptyStorageFolder.
  ///
  /// In en, this message translates to:
  /// **'Choose an empty destination folder.'**
  String get chooseEmptyStorageFolder;

  /// No description provided for @moveStorageData.
  ///
  /// In en, this message translates to:
  /// **'Move {name} data'**
  String moveStorageData(String name);

  /// No description provided for @moveStorageDataDescription.
  ///
  /// In en, this message translates to:
  /// **'Existing files will be copied to the new folder, then removed from the old folder.'**
  String get moveStorageDataDescription;

  /// No description provided for @preparingStorageFolder.
  ///
  /// In en, this message translates to:
  /// **'Preparing storage folder'**
  String get preparingStorageFolder;

  /// No description provided for @storageFolderUpdated.
  ///
  /// In en, this message translates to:
  /// **'Storage folder updated'**
  String get storageFolderUpdated;

  /// No description provided for @restoreDefault.
  ///
  /// In en, this message translates to:
  /// **'Use default folder'**
  String get restoreDefault;

  /// No description provided for @noRedirectedSavesFound.
  ///
  /// In en, this message translates to:
  /// **'No redirected saves found'**
  String get noRedirectedSavesFound;

  /// No description provided for @chooseAFolderOrConnectRemoteStoragePlayAGameWithRedirectionEnabledToCreateSaves.
  ///
  /// In en, this message translates to:
  /// **'Choose a folder or connect remote storage. Play a game with redirection enabled to create saves.'**
  String
  get chooseAFolderOrConnectRemoteStoragePlayAGameWithRedirectionEnabledToCreateSaves;

  /// No description provided for @remote.
  ///
  /// In en, this message translates to:
  /// **'Remote'**
  String get remote;

  /// No description provided for @local.
  ///
  /// In en, this message translates to:
  /// **'Local'**
  String get local;

  /// No description provided for @files.
  ///
  /// In en, this message translates to:
  /// **'files'**
  String get files;

  /// No description provided for @openFolder.
  ///
  /// In en, this message translates to:
  /// **'Open folder'**
  String get openFolder;

  /// No description provided for @backUpThisGame.
  ///
  /// In en, this message translates to:
  /// **'Back up this game'**
  String get backUpThisGame;

  /// No description provided for @downloadToFolder.
  ///
  /// In en, this message translates to:
  /// **'Download to folder'**
  String get downloadToFolder;

  /// No description provided for @uploadToRemote.
  ///
  /// In en, this message translates to:
  /// **'Upload to remote'**
  String get uploadToRemote;

  /// No description provided for @previewDeletion.
  ///
  /// In en, this message translates to:
  /// **'Preview deletion'**
  String get previewDeletion;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @chooseSaveFolder.
  ///
  /// In en, this message translates to:
  /// **'Choose save folder'**
  String get chooseSaveFolder;

  /// No description provided for @changeSaveFolder.
  ///
  /// In en, this message translates to:
  /// **'Change save folder'**
  String get changeSaveFolder;

  /// No description provided for @closeSteamAndAllGamesThenChooseAnEmptyFolderCurrentSavesWillBeCopiedToTheNewFolderAnd.
  ///
  /// In en, this message translates to:
  /// **'Close Steam and all games, then choose an empty folder. Current saves will be copied to the new folder and the originals retained. Existing destination files will not be overwritten. Restart Steam when finished.'**
  String
  get closeSteamAndAllGamesThenChooseAnEmptyFolderCurrentSavesWillBeCopiedToTheNewFolderAnd;

  /// No description provided for @setSaveFolder.
  ///
  /// In en, this message translates to:
  /// **'Set save folder'**
  String get setSaveFolder;

  /// No description provided for @backUpSaves.
  ///
  /// In en, this message translates to:
  /// **'Back up saves'**
  String get backUpSaves;

  /// No description provided for @downloadSaves.
  ///
  /// In en, this message translates to:
  /// **'Download saves'**
  String get downloadSaves;

  /// No description provided for @uploadSaves.
  ///
  /// In en, this message translates to:
  /// **'Upload saves'**
  String get uploadSaves;

  /// No description provided for @remoteFilesWithTheSameNamesWillBeReplacedCloseTheGameFirst.
  ///
  /// In en, this message translates to:
  /// **'Remote files with the same names will be replaced. Close the game first.'**
  String get remoteFilesWithTheSameNamesWillBeReplacedCloseTheGameFirst;

  /// No description provided for @prepareDeletionPreview.
  ///
  /// In en, this message translates to:
  /// **'Prepare deletion preview'**
  String get prepareDeletionPreview;

  /// No description provided for @deleteThisGameSSaves.
  ///
  /// In en, this message translates to:
  /// **'Delete this game’s saves'**
  String get deleteThisGameSSaves;

  /// No description provided for @aCompleteBackupIsCreatedBeforeDeleting.
  ///
  /// In en, this message translates to:
  /// **'A complete backup is created before deleting:'**
  String get aCompleteBackupIsCreatedBeforeDeleting;

  /// No description provided for @backupLocation.
  ///
  /// In en, this message translates to:
  /// **'Backup location'**
  String get backupLocation;

  /// No description provided for @saveBackups.
  ///
  /// In en, this message translates to:
  /// **'Save backups'**
  String get saveBackups;

  /// No description provided for @noBackupsYet.
  ///
  /// In en, this message translates to:
  /// **'No backups yet'**
  String get noBackupsYet;

  /// No description provided for @restoreBackup.
  ///
  /// In en, this message translates to:
  /// **'Restore backup'**
  String get restoreBackup;

  /// No description provided for @restoreToTheCurrentConfiguredLocationsExistingLocalSavesArePreservedInAPreRestoreBack.
  ///
  /// In en, this message translates to:
  /// **'Restore to the current configured locations. Existing local saves are preserved in a pre-restore backup; remote files with the same names are replaced. Close the game first.'**
  String
  get restoreToTheCurrentConfiguredLocationsExistingLocalSavesArePreservedInAPreRestoreBack;

  /// No description provided for @restoreSaves.
  ///
  /// In en, this message translates to:
  /// **'Restore saves'**
  String get restoreSaves;

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// No description provided for @configureStorage.
  ///
  /// In en, this message translates to:
  /// **'Configure storage'**
  String get configureStorage;

  /// No description provided for @provider.
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get provider;

  /// No description provided for @saveThenChooseAuthorizeToSignInUsingYourBrowser.
  ///
  /// In en, this message translates to:
  /// **'Save, then choose Authorize to sign in using your browser.'**
  String get saveThenChooseAuthorizeToSignInUsingYourBrowser;

  /// No description provided for @authentication.
  ///
  /// In en, this message translates to:
  /// **'Authentication'**
  String get authentication;

  /// No description provided for @usesTheWindowsCredentialsEnteredBelowDomainUsernameOrUsernameDomain.
  ///
  /// In en, this message translates to:
  /// **'Uses the Windows credentials entered below: DOMAIN\\username or username@domain.'**
  String
  get usesTheWindowsCredentialsEnteredBelowDomainUsernameOrUsernameDomain;

  /// No description provided for @allowHttpCredentialsAndSavesAreSentWithoutEncryption.
  ///
  /// In en, this message translates to:
  /// **'Allow HTTP (credentials and saves are sent without encryption)'**
  String get allowHttpCredentialsAndSavesAreSentWithoutEncryption;

  /// No description provided for @skipTlsCertificateValidationUnsafeTrustedSelfHostedServersOnly.
  ///
  /// In en, this message translates to:
  /// **'Skip TLS certificate validation (unsafe; trusted self-hosted servers only)'**
  String get skipTlsCertificateValidationUnsafeTrustedSelfHostedServersOnly;

  /// No description provided for @signRequestPayload.
  ///
  /// In en, this message translates to:
  /// **'Sign request payload'**
  String get signRequestPayload;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @saveCloudConfiguration.
  ///
  /// In en, this message translates to:
  /// **'Save cloud configuration'**
  String get saveCloudConfiguration;

  /// No description provided for @operationCompleted.
  ///
  /// In en, this message translates to:
  /// **'Operation completed'**
  String get operationCompleted;

  /// No description provided for @operationCancelled.
  ///
  /// In en, this message translates to:
  /// **'Operation cancelled'**
  String get operationCancelled;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @importKernelPackage.
  ///
  /// In en, this message translates to:
  /// **'Import kernel package'**
  String get importKernelPackage;

  /// No description provided for @switchKernel.
  ///
  /// In en, this message translates to:
  /// **'Switch kernel'**
  String get switchKernel;

  /// No description provided for @currentKernelFilesWillBeBackedUpBeforeInstallingCloseSteamFirst.
  ///
  /// In en, this message translates to:
  /// **'Current kernel files will be backed up before installing {displayName}. Close Steam first.'**
  String currentKernelFilesWillBeBackedUpBeforeInstallingCloseSteamFirst(
    String displayName,
  );

  /// No description provided for @noInstalledKernelFilesFound.
  ///
  /// In en, this message translates to:
  /// **'No installed kernel files found.'**
  String get noInstalledKernelFilesFound;

  /// No description provided for @uninstallKernel.
  ///
  /// In en, this message translates to:
  /// **'Uninstall kernel'**
  String get uninstallKernel;

  /// No description provided for @onlyTheseFilesWillBeRemovedAfterSavingABackupCloseSteamFirst.
  ///
  /// In en, this message translates to:
  /// **'Only these files will be removed, after saving a backup. Close Steam first.'**
  String get onlyTheseFilesWillBeRemovedAfterSavingABackupCloseSteamFirst;

  /// No description provided for @noOtherKernelFilesFound.
  ///
  /// In en, this message translates to:
  /// **'No other kernel files found.'**
  String get noOtherKernelFilesFound;

  /// No description provided for @cleanOtherKernels.
  ///
  /// In en, this message translates to:
  /// **'Clean other kernels'**
  String get cleanOtherKernels;

  /// No description provided for @selectFilesToRemoveTheyWillBeBackedUpLuaFoldersAndSteamCfgArePreserved.
  ///
  /// In en, this message translates to:
  /// **'Select files to remove. They will be backed up; Lua folders and steam.cfg are preserved.'**
  String
  get selectFilesToRemoveTheyWillBeBackedUpLuaFoldersAndSteamCfgArePreserved;

  /// No description provided for @backUpAndRemove.
  ///
  /// In en, this message translates to:
  /// **'Back up and remove'**
  String get backUpAndRemove;

  /// No description provided for @kernelManagement.
  ///
  /// In en, this message translates to:
  /// **'Kernel management'**
  String get kernelManagement;

  /// No description provided for @coreAndPlugins.
  ///
  /// In en, this message translates to:
  /// **'Core and plugins'**
  String get coreAndPlugins;

  /// No description provided for @downloadsAndNetwork.
  ///
  /// In en, this message translates to:
  /// **'Downloads and network'**
  String get downloadsAndNetwork;

  /// No description provided for @cloudRedirectPlugin.
  ///
  /// In en, this message translates to:
  /// **'CloudRedirect save plugin'**
  String get cloudRedirectPlugin;

  /// No description provided for @pluginManagement.
  ///
  /// In en, this message translates to:
  /// **'Plugin management'**
  String get pluginManagement;

  /// No description provided for @installOrUpdatePlugin.
  ///
  /// In en, this message translates to:
  /// **'Install or update plugin'**
  String get installOrUpdatePlugin;

  /// No description provided for @cloudRedirectPluginDescription.
  ///
  /// In en, this message translates to:
  /// **'Loaded by OpenSteamTool inside Steam to redirect cloud saves for added games.'**
  String get cloudRedirectPluginDescription;

  /// No description provided for @kernelIntegration.
  ///
  /// In en, this message translates to:
  /// **'Kernel integration'**
  String get kernelIntegration;

  /// No description provided for @openSteamtoolCore.
  ///
  /// In en, this message translates to:
  /// **'OpenSteamTool core'**
  String get openSteamtoolCore;

  /// No description provided for @actions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get actions;

  /// No description provided for @path.
  ///
  /// In en, this message translates to:
  /// **'Path'**
  String get path;

  /// No description provided for @removeCloudRedirectPlugin.
  ///
  /// In en, this message translates to:
  /// **'Remove CloudRedirect plugin'**
  String get removeCloudRedirectPlugin;

  /// No description provided for @removeCloudRedirectPluginDescription.
  ///
  /// In en, this message translates to:
  /// **'Disable kernel integration, back up and remove the CloudRedirect DLL from the Steam folder.'**
  String get removeCloudRedirectPluginDescription;

  /// No description provided for @officialAndLocalKernelPackagesAreCachedForOfflineSwitchingCloseSteamBeforeChangingIts.
  ///
  /// In en, this message translates to:
  /// **'Official and local kernel packages are cached for offline switching. Close Steam before changing its files.'**
  String
  get officialAndLocalKernelPackagesAreCachedForOfflineSwitchingCloseSteamBeforeChangingIts;

  /// No description provided for @currentKernel.
  ///
  /// In en, this message translates to:
  /// **'Current kernel'**
  String get currentKernel;

  /// No description provided for @unknownVersion.
  ///
  /// In en, this message translates to:
  /// **'Unknown version'**
  String get unknownVersion;

  /// No description provided for @noKernelInstalled.
  ///
  /// In en, this message translates to:
  /// **'No kernel installed'**
  String get noKernelInstalled;

  /// No description provided for @disabled2.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get disabled2;

  /// No description provided for @selectYourSteamFolderInSettingsFirst.
  ///
  /// In en, this message translates to:
  /// **'Select your Steam folder in settings first.'**
  String get selectYourSteamFolderInSettingsFirst;

  /// No description provided for @bothInjectionEntriesAreActiveSelectOneEntry.
  ///
  /// In en, this message translates to:
  /// **'Both injection entries are active. Select one entry.'**
  String get bothInjectionEntriesAreActiveSelectOneEntry;

  /// No description provided for @enableKernel.
  ///
  /// In en, this message translates to:
  /// **'Enable kernel'**
  String get enableKernel;

  /// No description provided for @disableKernel.
  ///
  /// In en, this message translates to:
  /// **'Disable kernel'**
  String get disableKernel;

  /// No description provided for @kernelFilesWillBeRenamedAfterSavingABackupCloseSteamFirst.
  ///
  /// In en, this message translates to:
  /// **'Kernel files will be renamed after saving a backup. Close Steam first.'**
  String get kernelFilesWillBeRenamedAfterSavingABackupCloseSteamFirst;

  /// No description provided for @disable.
  ///
  /// In en, this message translates to:
  /// **'Disable'**
  String get disable;

  /// No description provided for @enable.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get enable;

  /// No description provided for @entryDwmapi.
  ///
  /// In en, this message translates to:
  /// **'Entry: dwmapi'**
  String get entryDwmapi;

  /// No description provided for @entryVersion.
  ///
  /// In en, this message translates to:
  /// **'Entry: version'**
  String get entryVersion;

  /// No description provided for @changeInjectionEntry.
  ///
  /// In en, this message translates to:
  /// **'Change injection entry'**
  String get changeInjectionEntry;

  /// No description provided for @onlyTheSelectedEntryWillRemainActiveCloseSteamFirst.
  ///
  /// In en, this message translates to:
  /// **'Only the selected entry will remain active. Close Steam first.'**
  String get onlyTheSelectedEntryWillRemainActiveCloseSteamFirst;

  /// No description provided for @fetchSteamSignatures.
  ///
  /// In en, this message translates to:
  /// **'Fetch Steam signatures'**
  String get fetchSteamSignatures;

  /// No description provided for @uninstall.
  ///
  /// In en, this message translates to:
  /// **'Uninstall'**
  String get uninstall;

  /// No description provided for @availablePackages.
  ///
  /// In en, this message translates to:
  /// **'Available packages'**
  String get availablePackages;

  /// No description provided for @importZip.
  ///
  /// In en, this message translates to:
  /// **'Import ZIP'**
  String get importZip;

  /// No description provided for @refreshKernelReleases.
  ///
  /// In en, this message translates to:
  /// **'Refresh kernel releases'**
  String get refreshKernelReleases;

  /// No description provided for @refreshToLoadOfficialReleasesOrImportALocalKernelZip.
  ///
  /// In en, this message translates to:
  /// **'Refresh to load official releases, or import a local kernel ZIP.'**
  String get refreshToLoadOfficialReleasesOrImportALocalKernelZip;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @local2.
  ///
  /// In en, this message translates to:
  /// **'Local'**
  String get local2;

  /// No description provided for @official.
  ///
  /// In en, this message translates to:
  /// **'Official'**
  String get official;

  /// No description provided for @cached.
  ///
  /// In en, this message translates to:
  /// **'Cached'**
  String get cached;

  /// No description provided for @notDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Not downloaded'**
  String get notDownloaded;

  /// No description provided for @downloadOnly.
  ///
  /// In en, this message translates to:
  /// **'Download only'**
  String get downloadOnly;

  /// No description provided for @downloadKernel.
  ///
  /// In en, this message translates to:
  /// **'Download kernel'**
  String get downloadKernel;

  /// No description provided for @switchLabel.
  ///
  /// In en, this message translates to:
  /// **'Switch'**
  String get switchLabel;

  /// No description provided for @deleteCache.
  ///
  /// In en, this message translates to:
  /// **'Delete cache'**
  String get deleteCache;

  /// No description provided for @deleteTheCachedPackageBackupsArePreserved.
  ///
  /// In en, this message translates to:
  /// **'Delete the cached {displayName} package? Backups are preserved.'**
  String deleteTheCachedPackageBackupsArePreserved(String displayName);

  /// No description provided for @switchAndRecoveryBackups.
  ///
  /// In en, this message translates to:
  /// **'Switch and recovery backups'**
  String get switchAndRecoveryBackups;

  /// No description provided for @aRecoverableSnapshotIsSavedBeforeSwitchingOrUninstalling.
  ///
  /// In en, this message translates to:
  /// **'A recoverable snapshot is saved before switching or uninstalling.'**
  String get aRecoverableSnapshotIsSavedBeforeSwitchingOrUninstalling;

  /// No description provided for @restoreKernelBackup.
  ///
  /// In en, this message translates to:
  /// **'Restore kernel backup'**
  String get restoreKernelBackup;

  /// No description provided for @restoreTheseFilesAndRemoveKernelFilesAbsentFromThisSnapshotCloseSteamFirst.
  ///
  /// In en, this message translates to:
  /// **'Restore these files and remove kernel files absent from this snapshot. Close Steam first.'**
  String
  get restoreTheseFilesAndRemoveKernelFilesAbsentFromThisSnapshotCloseSteamFirst;

  /// No description provided for @repository.
  ///
  /// In en, this message translates to:
  /// **'Repository'**
  String get repository;

  /// No description provided for @luaSavedTheOriginalWasBackedUp.
  ///
  /// In en, this message translates to:
  /// **'Lua saved. The original was backed up.'**
  String get luaSavedTheOriginalWasBackedUp;

  /// No description provided for @discardUnsavedChanges.
  ///
  /// In en, this message translates to:
  /// **'Discard unsaved changes?'**
  String get discardUnsavedChanges;

  /// No description provided for @theseChangesHaveNotBeenSavedToTheLuaFile.
  ///
  /// In en, this message translates to:
  /// **'These changes have not been saved to the Lua file.'**
  String get theseChangesHaveNotBeenSavedToTheLuaFile;

  /// No description provided for @enabled2.
  ///
  /// In en, this message translates to:
  /// **'enabled'**
  String get enabled2;

  /// No description provided for @commented.
  ///
  /// In en, this message translates to:
  /// **'commented'**
  String get commented;

  /// No description provided for @manifestPinsSaveToApply.
  ///
  /// In en, this message translates to:
  /// **'{changed} manifest pins {commented}. Save to apply.'**
  String manifestPinsSaveToApply(String changed, String commented);

  /// No description provided for @enablePins.
  ///
  /// In en, this message translates to:
  /// **'Enable pins'**
  String get enablePins;

  /// No description provided for @disablePins.
  ///
  /// In en, this message translates to:
  /// **'Disable pins'**
  String get disablePins;

  /// No description provided for @ctrlSToSaveOriginalBackedUpBeforeSavingLines.
  ///
  /// In en, this message translates to:
  /// **'Ctrl+S to save · Original backed up before saving · {value1} lines'**
  String ctrlSToSaveOriginalBackedUpBeforeSavingLines(String value1);

  /// No description provided for @directGithub.
  ///
  /// In en, this message translates to:
  /// **'Direct GitHub'**
  String get directGithub;

  /// No description provided for @testCoverSources.
  ///
  /// In en, this message translates to:
  /// **'Test cover sources'**
  String get testCoverSources;

  /// No description provided for @testGithubDownloadSources.
  ///
  /// In en, this message translates to:
  /// **'Test GitHub download sources'**
  String get testGithubDownloadSources;

  /// No description provided for @testCancelled.
  ///
  /// In en, this message translates to:
  /// **'Test cancelled'**
  String get testCancelled;

  /// No description provided for @networkAndDownloadSources.
  ///
  /// In en, this message translates to:
  /// **'Network and download sources'**
  String get networkAndDownloadSources;

  /// No description provided for @chooseCoverAndPublicDownloadSourcesForYourConnectionTestsShowCurrentResultsWithoutCha.
  ///
  /// In en, this message translates to:
  /// **'Choose cover and public download sources for your connection. Tests show current results without changing your preferences.'**
  String
  get chooseCoverAndPublicDownloadSourcesForYourConnectionTestsShowCurrentResultsWithoutCha;

  /// No description provided for @gameCovers.
  ///
  /// In en, this message translates to:
  /// **'Game covers'**
  String get gameCovers;

  /// No description provided for @preferredSource.
  ///
  /// In en, this message translates to:
  /// **'Preferred source'**
  String get preferredSource;

  /// No description provided for @byDefaultUseTheOfficialImageUrlFromGameDetailsThisPreferenceAffectsArtworkOnlyNotStea.
  ///
  /// In en, this message translates to:
  /// **'By default, use the official image URL from game details. This preference affects artwork only, not Steam sign-in, Store APIs or content downloads.'**
  String
  get byDefaultUseTheOfficialImageUrlFromGameDetailsThisPreferenceAffectsArtworkOnlyNotStea;

  /// No description provided for @githubDownloads.
  ///
  /// In en, this message translates to:
  /// **'GitHub downloads'**
  String get githubDownloads;

  /// No description provided for @preferredPublicDownloadSource.
  ///
  /// In en, this message translates to:
  /// **'Preferred public download source'**
  String get preferredPublicDownloadSource;

  /// No description provided for @customGithubMirror.
  ///
  /// In en, this message translates to:
  /// **'Custom GitHub mirror'**
  String get customGithubMirror;

  /// No description provided for @githubMirrorHint.
  ///
  /// In en, this message translates to:
  /// **'https://mirror.example.com'**
  String get githubMirrorHint;

  /// No description provided for @directDefault.
  ///
  /// In en, this message translates to:
  /// **'Direct (default)'**
  String get directDefault;

  /// No description provided for @mirrorsApplyOnlyToAnonymousPublicGithubFileDownloadsSignInApiTokenAndCredentialBearin.
  ///
  /// In en, this message translates to:
  /// **'Mirrors apply only to anonymous public GitHub file downloads. Sign-in, API, token and credential-bearing requests always stay direct. The selected mirror processes those public download requests.'**
  String
  get mirrorsApplyOnlyToAnonymousPublicGithubFileDownloadsSignInApiTokenAndCredentialBearin;

  /// No description provided for @testPublicDownloadSources.
  ///
  /// In en, this message translates to:
  /// **'Test public download sources'**
  String get testPublicDownloadSources;

  /// No description provided for @testingSourcesViewOrCancelTheOperationInGlobalTasksNavigationKeepsItRunning.
  ///
  /// In en, this message translates to:
  /// **'Testing sources. View or cancel the operation in global tasks; navigation keeps it running.'**
  String
  get testingSourcesViewOrCancelTheOperationInGlobalTasksNavigationKeepsItRunning;

  /// No description provided for @failed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get failed;

  /// No description provided for @gameManagement2.
  ///
  /// In en, this message translates to:
  /// **'Game management'**
  String get gameManagement2;

  /// No description provided for @patchSettings.
  ///
  /// In en, this message translates to:
  /// **'Patch settings'**
  String get patchSettings;

  /// No description provided for @patchSettingsDescription.
  ///
  /// In en, this message translates to:
  /// **'Verify game files, manage Goldberg and download network patches.'**
  String get patchSettingsDescription;

  /// No description provided for @patchTools.
  ///
  /// In en, this message translates to:
  /// **'Patch tools'**
  String get patchTools;

  /// No description provided for @patchToolsDescription.
  ///
  /// In en, this message translates to:
  /// **'Patch archives are not installed generically. Inspect game files against Steam manifests or use the network patch downloader.'**
  String get patchToolsDescription;

  /// No description provided for @gameFileVerification.
  ///
  /// In en, this message translates to:
  /// **'Game file verification'**
  String get gameFileVerification;

  /// No description provided for @gameFileVerificationDescription.
  ///
  /// In en, this message translates to:
  /// **'Compare installed files with the manifests recorded by Steam.'**
  String get gameFileVerificationDescription;

  /// No description provided for @gamePatchDownload.
  ///
  /// In en, this message translates to:
  /// **'Game patch download'**
  String get gamePatchDownload;

  /// No description provided for @gamePatchDownloadDescription.
  ///
  /// In en, this message translates to:
  /// **'Download and extract a network patch package without installing it.'**
  String get gamePatchDownloadDescription;

  /// No description provided for @goldbergEmulator.
  ///
  /// In en, this message translates to:
  /// **'Goldberg emulator'**
  String get goldbergEmulator;

  /// No description provided for @goldbergSettings.
  ///
  /// In en, this message translates to:
  /// **'Goldberg settings'**
  String get goldbergSettings;

  /// No description provided for @goldbergDescription.
  ///
  /// In en, this message translates to:
  /// **'Download, deploy and configure the Goldberg emulator for this game.'**
  String get goldbergDescription;

  /// No description provided for @goldbergSettingsFooter.
  ///
  /// In en, this message translates to:
  /// **'Only the standardized Goldberg deployment is automated. Generic patch archives remain manual.'**
  String get goldbergSettingsFooter;

  /// No description provided for @authorizationTicketDescription.
  ///
  /// In en, this message translates to:
  /// **'Import tickets.txt, validate its AppID and payload lengths, then apply the ticket only when explicitly requested.'**
  String get authorizationTicketDescription;

  /// No description provided for @matchingLua.
  ///
  /// In en, this message translates to:
  /// **'Matching Lua'**
  String get matchingLua;

  /// No description provided for @matchingLuaFound.
  ///
  /// In en, this message translates to:
  /// **'A matching Lua file was found for this game.'**
  String get matchingLuaFound;

  /// No description provided for @matchingLuaMissing.
  ///
  /// In en, this message translates to:
  /// **'No matching Lua file was found. The ticket can still be applied.'**
  String get matchingLuaMissing;

  /// No description provided for @ticketActions.
  ///
  /// In en, this message translates to:
  /// **'Ticket actions'**
  String get ticketActions;

  /// No description provided for @networkSource.
  ///
  /// In en, this message translates to:
  /// **'Network source'**
  String get networkSource;

  /// No description provided for @selectedPatch.
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get selectedPatch;

  /// No description provided for @loadPatches.
  ///
  /// In en, this message translates to:
  /// **'Load patches'**
  String get loadPatches;

  /// No description provided for @patchSourceLoaded.
  ///
  /// In en, this message translates to:
  /// **'Loaded {count} patch options.'**
  String patchSourceLoaded(String count);

  /// No description provided for @choosePatchType.
  ///
  /// In en, this message translates to:
  /// **'Choose a patch type first.'**
  String get choosePatchType;

  /// No description provided for @patchType.
  ///
  /// In en, this message translates to:
  /// **'Patch type'**
  String get patchType;

  /// No description provided for @noPatchesAvailable.
  ///
  /// In en, this message translates to:
  /// **'No patches available'**
  String get noPatchesAvailable;

  /// No description provided for @noPatchesAvailableDescription.
  ///
  /// In en, this message translates to:
  /// **'This game has no entry in the configured network patch table.'**
  String get noPatchesAvailableDescription;

  /// No description provided for @gamePatchDownloadFooter.
  ///
  /// In en, this message translates to:
  /// **'The downloaded archive is extracted to the application downloads folder. Nothing is copied into the game.'**
  String get gamePatchDownloadFooter;

  /// No description provided for @downloadingPatch.
  ///
  /// In en, this message translates to:
  /// **'Downloading {label}'**
  String downloadingPatch(String label);

  /// No description provided for @downloadPatch.
  ///
  /// In en, this message translates to:
  /// **'Download patch'**
  String get downloadPatch;

  /// No description provided for @patchDownloadComplete.
  ///
  /// In en, this message translates to:
  /// **'Downloaded {files} files ({size}) to {path}.'**
  String patchDownloadComplete(String files, String size, String path);

  /// No description provided for @patchDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Patch download failed: {error}'**
  String patchDownloadFailed(String error);

  /// No description provided for @patchExtracted.
  ///
  /// In en, this message translates to:
  /// **'Patch extracted'**
  String get patchExtracted;

  /// No description provided for @virtualMachinePatch.
  ///
  /// In en, this message translates to:
  /// **'Virtual machine (BuildID: {buildId})'**
  String virtualMachinePatch(String buildId);

  /// No description provided for @v38Patch.
  ///
  /// In en, this message translates to:
  /// **'V38 patch'**
  String get v38Patch;

  /// No description provided for @onlinePatch.
  ///
  /// In en, this message translates to:
  /// **'Online patch (fix)'**
  String get onlinePatch;

  /// No description provided for @offlinePatch.
  ///
  /// In en, this message translates to:
  /// **'Offline patch (crack)'**
  String get offlinePatch;

  /// No description provided for @vbsPatch.
  ///
  /// In en, this message translates to:
  /// **'VBS patch'**
  String get vbsPatch;

  /// No description provided for @searchFiles.
  ///
  /// In en, this message translates to:
  /// **'Search files'**
  String get searchFiles;

  /// No description provided for @verifyGameFiles.
  ///
  /// In en, this message translates to:
  /// **'Verify game files'**
  String get verifyGameFiles;

  /// No description provided for @verificationTarget.
  ///
  /// In en, this message translates to:
  /// **'Verification target'**
  String get verificationTarget;

  /// No description provided for @gameDirectoryUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The game directory is unavailable.'**
  String get gameDirectoryUnavailable;

  /// No description provided for @verificationEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'The verification uses appmanifest and local depotcache manifests. Unexpected files are suggestions and are never deleted automatically.'**
  String get verificationEmptyDescription;

  /// No description provided for @startVerification.
  ///
  /// In en, this message translates to:
  /// **'Start verification'**
  String get startVerification;

  /// No description provided for @filesMatchManifests.
  ///
  /// In en, this message translates to:
  /// **'Files match the installed manifests'**
  String get filesMatchManifests;

  /// No description provided for @filesNeedAttention.
  ///
  /// In en, this message translates to:
  /// **'{count} files need attention'**
  String filesNeedAttention(String count);

  /// No description provided for @verifiedCount.
  ///
  /// In en, this message translates to:
  /// **'Verified {count}'**
  String verifiedCount(String count);

  /// No description provided for @missingCount.
  ///
  /// In en, this message translates to:
  /// **'Missing {count}'**
  String missingCount(String count);

  /// No description provided for @changedCount.
  ///
  /// In en, this message translates to:
  /// **'Changed {count}'**
  String changedCount(String count);

  /// No description provided for @unexpectedCount.
  ///
  /// In en, this message translates to:
  /// **'Unexpected {count}'**
  String unexpectedCount(String count);

  /// No description provided for @unverifiedCount.
  ///
  /// In en, this message translates to:
  /// **'Unverified {count}'**
  String unverifiedCount(String count);

  /// No description provided for @manifestSummary.
  ///
  /// In en, this message translates to:
  /// **'{depots} depots · {manifests} manifests parsed'**
  String manifestSummary(String depots, String manifests);

  /// No description provided for @manifestNotes.
  ///
  /// In en, this message translates to:
  /// **'Manifest notes'**
  String get manifestNotes;

  /// No description provided for @manifestVerificationWarning.
  ///
  /// In en, this message translates to:
  /// **'Encrypted manifests need the depot key from the game Lua file. Files that cannot be compared are reported here.'**
  String get manifestVerificationWarning;

  /// No description provided for @manifestInventoryOnly.
  ///
  /// In en, this message translates to:
  /// **'Manifest data is unavailable; showing a file inventory only'**
  String get manifestInventoryOnly;

  /// No description provided for @manifestPartialSummary.
  ///
  /// In en, this message translates to:
  /// **'Some depots were checked; unmatched files require manual review'**
  String get manifestPartialSummary;

  /// No description provided for @allFiles.
  ///
  /// In en, this message translates to:
  /// **'All files'**
  String get allFiles;

  /// No description provided for @issuesOnly.
  ///
  /// In en, this message translates to:
  /// **'Issues'**
  String get issuesOnly;

  /// No description provided for @unexpectedFiles.
  ///
  /// In en, this message translates to:
  /// **'Unexpected files'**
  String get unexpectedFiles;

  /// No description provided for @noMatchingFiles.
  ///
  /// In en, this message translates to:
  /// **'No matching files'**
  String get noMatchingFiles;

  /// No description provided for @verificationResults.
  ///
  /// In en, this message translates to:
  /// **'Verification results'**
  String get verificationResults;

  /// No description provided for @unexpectedFilesHint.
  ///
  /// In en, this message translates to:
  /// **'Unexpected files are suggestions only. Review them before changing anything.'**
  String get unexpectedFilesHint;

  /// No description provided for @unverifiedFilesHint.
  ///
  /// In en, this message translates to:
  /// **'Files from depots without readable manifests cannot be classified as unexpected.'**
  String get unverifiedFilesHint;

  /// No description provided for @verified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get verified;

  /// No description provided for @changed.
  ///
  /// In en, this message translates to:
  /// **'Changed'**
  String get changed;

  /// No description provided for @unexpected.
  ///
  /// In en, this message translates to:
  /// **'Unexpected'**
  String get unexpected;

  /// No description provided for @unverified.
  ///
  /// In en, this message translates to:
  /// **'Unverified'**
  String get unverified;

  /// No description provided for @expectedSize.
  ///
  /// In en, this message translates to:
  /// **'Expected {size} bytes'**
  String expectedSize(String size);

  /// No description provided for @actualSize.
  ///
  /// In en, this message translates to:
  /// **'Actual {size} bytes'**
  String actualSize(String size);

  /// No description provided for @emulatorNotDownloaded.
  ///
  /// In en, this message translates to:
  /// **'No Goldberg release is cached.'**
  String get emulatorNotDownloaded;

  /// No description provided for @currentEmulatorVersion.
  ///
  /// In en, this message translates to:
  /// **'Cached version: {version}'**
  String currentEmulatorVersion(String version);

  /// No description provided for @goldbergDeployDescription.
  ///
  /// In en, this message translates to:
  /// **'Replace the Steam API DLLs found in this game with the cached Goldberg build.'**
  String get goldbergDeployDescription;

  /// No description provided for @connectionAndIdentity.
  ///
  /// In en, this message translates to:
  /// **'Connection and identity'**
  String get connectionAndIdentity;

  /// No description provided for @steamId.
  ///
  /// In en, this message translates to:
  /// **'SteamID'**
  String get steamId;

  /// No description provided for @dlcIds.
  ///
  /// In en, this message translates to:
  /// **'DLC IDs'**
  String get dlcIds;

  /// No description provided for @depotIds.
  ///
  /// In en, this message translates to:
  /// **'Depot IDs'**
  String get depotIds;

  /// No description provided for @steamInterfaces.
  ///
  /// In en, this message translates to:
  /// **'Steam interfaces'**
  String get steamInterfaces;

  /// No description provided for @steamInput.
  ///
  /// In en, this message translates to:
  /// **'Steam Input'**
  String get steamInput;

  /// No description provided for @contentConfiguration.
  ///
  /// In en, this message translates to:
  /// **'Content configuration'**
  String get contentConfiguration;

  /// No description provided for @behavior.
  ///
  /// In en, this message translates to:
  /// **'Behavior'**
  String get behavior;

  /// No description provided for @configurationActions.
  ///
  /// In en, this message translates to:
  /// **'Configuration actions'**
  String get configurationActions;

  /// No description provided for @jsonDefinitions.
  ///
  /// In en, this message translates to:
  /// **'JSON definitions'**
  String get jsonDefinitions;

  /// No description provided for @luaExtraction.
  ///
  /// In en, this message translates to:
  /// **'Lua extraction'**
  String get luaExtraction;

  /// No description provided for @luaExtractionDescription.
  ///
  /// In en, this message translates to:
  /// **'Query the selected Steam app, fetch its authorized depot keys and write a Lua file plus optional manifests. The account must own the game.'**
  String get luaExtractionDescription;

  /// No description provided for @denuvoTicketExtraction.
  ///
  /// In en, this message translates to:
  /// **'Denuvo ticket extraction'**
  String get denuvoTicketExtraction;

  /// No description provided for @denuvoTicketExtractionDescription.
  ///
  /// In en, this message translates to:
  /// **'Extract AppTicket and ETicket from the signed-in local Steam user. The account must own the game.'**
  String get denuvoTicketExtractionDescription;

  /// No description provided for @steamLoginRequired.
  ///
  /// In en, this message translates to:
  /// **'Sign in to Steam before extracting Lua content.'**
  String get steamLoginRequired;

  /// No description provided for @useLocalSteamLogin.
  ///
  /// In en, this message translates to:
  /// **'Use local Steam login'**
  String get useLocalSteamLogin;

  /// No description provided for @useLocalSteamLoginDescription.
  ///
  /// In en, this message translates to:
  /// **'Read the signed-in Steam account from local.vdf without entering a password.'**
  String get useLocalSteamLoginDescription;

  /// No description provided for @localSteamLoginUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No usable local Steam login was found. Start Steam and sign in, or use the manual login below.'**
  String get localSteamLoginUnavailable;

  /// No description provided for @realOwnershipRequiredNotice.
  ///
  /// In en, this message translates to:
  /// **'Real ownership is required: only use extraction for games you personally own. This app does not verify purchases.'**
  String get realOwnershipRequiredNotice;

  /// No description provided for @notSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Not signed in'**
  String get notSignedIn;

  /// No description provided for @luaLoginDescription.
  ///
  /// In en, this message translates to:
  /// **'Open the Steam account page to sign in or change account.'**
  String get luaLoginDescription;

  /// No description provided for @appIdForExtraction.
  ///
  /// In en, this message translates to:
  /// **'Game AppID'**
  String get appIdForExtraction;

  /// No description provided for @outputDirectory.
  ///
  /// In en, this message translates to:
  /// **'Output directory'**
  String get outputDirectory;

  /// No description provided for @useDefaultOutputDirectory.
  ///
  /// In en, this message translates to:
  /// **'Use the application downloads directory'**
  String get useDefaultOutputDirectory;

  /// No description provided for @extractionTarget.
  ///
  /// In en, this message translates to:
  /// **'Extraction target'**
  String get extractionTarget;

  /// No description provided for @extractionOptions.
  ///
  /// In en, this message translates to:
  /// **'Extraction options'**
  String get extractionOptions;

  /// No description provided for @copyAchievements.
  ///
  /// In en, this message translates to:
  /// **'Copy achievements data'**
  String get copyAchievements;

  /// No description provided for @extractionResult.
  ///
  /// In en, this message translates to:
  /// **'Extraction result'**
  String get extractionResult;

  /// No description provided for @extractingLua.
  ///
  /// In en, this message translates to:
  /// **'Extracting Lua for AppID {appId}'**
  String extractingLua(String appId);

  /// No description provided for @extractLua.
  ///
  /// In en, this message translates to:
  /// **'Extract Lua'**
  String get extractLua;

  /// No description provided for @luaExtractionComplete.
  ///
  /// In en, this message translates to:
  /// **'Lua extraction complete · {keys} depot keys · {manifests} manifests'**
  String luaExtractionComplete(String keys, String manifests);

  /// No description provided for @ownershipRequired.
  ///
  /// In en, this message translates to:
  /// **'This Steam account does not truly own this game.'**
  String get ownershipRequired;

  /// No description provided for @steamMustBeRunningAndSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Start Steam and sign in to the account that owns this game first.'**
  String get steamMustBeRunningAndSignedIn;

  /// No description provided for @outputDirectoryDoesNotExist.
  ///
  /// In en, this message translates to:
  /// **'The output directory does not exist.'**
  String get outputDirectoryDoesNotExist;

  /// No description provided for @ticketExtractionFileHeader.
  ///
  /// In en, this message translates to:
  /// **'Extracted by FlSteamLua. Use the ticket before it expires.'**
  String get ticketExtractionFileHeader;

  /// No description provided for @ticketExtractionComplete.
  ///
  /// In en, this message translates to:
  /// **'Ticket written to {path}'**
  String ticketExtractionComplete(String path);

  /// No description provided for @ticketExtractionOptions.
  ///
  /// In en, this message translates to:
  /// **'Ticket options'**
  String get ticketExtractionOptions;

  /// No description provided for @extractDenuvoTicket.
  ///
  /// In en, this message translates to:
  /// **'Extract ticket'**
  String get extractDenuvoTicket;

  /// No description provided for @openAuthorizationPage.
  ///
  /// In en, this message translates to:
  /// **'Open authorization page'**
  String get openAuthorizationPage;

  /// No description provided for @patchesRestore.
  ///
  /// In en, this message translates to:
  /// **'Patches & restore'**
  String get patchesRestore;

  /// No description provided for @tickets.
  ///
  /// In en, this message translates to:
  /// **'Tickets'**
  String get tickets;

  /// No description provided for @gameDirectory.
  ///
  /// In en, this message translates to:
  /// **'Game directory'**
  String get gameDirectory;

  /// No description provided for @selectGameDirectory.
  ///
  /// In en, this message translates to:
  /// **'Select game directory'**
  String get selectGameDirectory;

  /// No description provided for @choose.
  ///
  /// In en, this message translates to:
  /// **'Choose'**
  String get choose;

  /// No description provided for @patchInstallation.
  ///
  /// In en, this message translates to:
  /// **'Patch installation'**
  String get patchInstallation;

  /// No description provided for @previewFilesBeforeInstallationOriginalsAreBackedUpAndLaterChangesAreCheckedBeforeRest.
  ///
  /// In en, this message translates to:
  /// **'Preview files before installation. Originals are backed up, and later changes are checked before restoration.'**
  String
  get previewFilesBeforeInstallationOriginalsAreBackedUpAndLaterChangesAreCheckedBeforeRest;

  /// No description provided for @choosePatchArchive.
  ///
  /// In en, this message translates to:
  /// **'Choose patch archive'**
  String get choosePatchArchive;

  /// No description provided for @inspectExecutable.
  ///
  /// In en, this message translates to:
  /// **'Inspect executable'**
  String get inspectExecutable;

  /// No description provided for @downloadTheUpstreamWindowsReleaseOnDemandDeploymentReplacesExistingSteamApiDllsAndCre.
  ///
  /// In en, this message translates to:
  /// **'Download the upstream Windows release on demand. Deployment replaces existing Steam API DLLs and creates a restorable backup; edit configuration in the next tab.'**
  String
  get downloadTheUpstreamWindowsReleaseOnDemandDeploymentReplacesExistingSteamApiDllsAndCre;

  /// No description provided for @downloadUpdateEmulator.
  ///
  /// In en, this message translates to:
  /// **'Download/update emulator'**
  String get downloadUpdateEmulator;

  /// No description provided for @deployGoldberg.
  ///
  /// In en, this message translates to:
  /// **'Deploy Goldberg'**
  String get deployGoldberg;

  /// No description provided for @replaceSteamApiDllsInThisGameDirectoryOriginalFilesWillBeSavedInApplicationBackups.
  ///
  /// In en, this message translates to:
  /// **'Replace Steam API DLLs in this game directory? Original files will be saved in application backups.'**
  String
  get replaceSteamApiDllsInThisGameDirectoryOriginalFilesWillBeSavedInApplicationBackups;

  /// No description provided for @deployToThisGame.
  ///
  /// In en, this message translates to:
  /// **'Deploy to this game'**
  String get deployToThisGame;

  /// No description provided for @patchBackups.
  ///
  /// In en, this message translates to:
  /// **'Patch backups'**
  String get patchBackups;

  /// No description provided for @noPatchBackupsForThisGame.
  ///
  /// In en, this message translates to:
  /// **'No patch backups for this game.'**
  String get noPatchBackupsForThisGame;

  /// No description provided for @restored.
  ///
  /// In en, this message translates to:
  /// **'Restored'**
  String get restored;

  /// No description provided for @available.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get available;

  /// No description provided for @restore2.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore2;

  /// No description provided for @inspectPatchArchive.
  ///
  /// In en, this message translates to:
  /// **'Inspect patch archive'**
  String get inspectPatchArchive;

  /// No description provided for @thisArchiveContainsManifestsOnlyImportItFromTheLibrary.
  ///
  /// In en, this message translates to:
  /// **'This archive contains manifests only. Import it from the library.'**
  String get thisArchiveContainsManifestsOnlyImportItFromTheLibrary;

  /// No description provided for @installPatch.
  ///
  /// In en, this message translates to:
  /// **'Install patch'**
  String get installPatch;

  /// No description provided for @restorePatchBackup.
  ///
  /// In en, this message translates to:
  /// **'Restore patch backup'**
  String get restorePatchBackup;

  /// No description provided for @restorePatch.
  ///
  /// In en, this message translates to:
  /// **'Restore patch'**
  String get restorePatch;

  /// No description provided for @fileHasChanged.
  ///
  /// In en, this message translates to:
  /// **'File has changed'**
  String get fileHasChanged;

  /// No description provided for @theseFilesWereModifiedAfterPatchInstallationReplaceThemWithTheOriginalBackupsAnyway.
  ///
  /// In en, this message translates to:
  /// **'These files were modified after patch installation. Replace them with the original backups anyway?'**
  String
  get theseFilesWereModifiedAfterPatchInstallationReplaceThemWithTheOriginalBackupsAnyway;

  /// No description provided for @inspectPeExecutable.
  ///
  /// In en, this message translates to:
  /// **'Inspect PE executable'**
  String get inspectPeExecutable;

  /// No description provided for @aBindSectionWasFoundAutomaticUnpackingIsNotIncludedTheOriginalSteamlessCodeDeclaresCc.
  ///
  /// In en, this message translates to:
  /// **'A .bind section was found. Automatic unpacking is not included: the original Steamless code declares CC BY-NC-ND 4.0 and cannot be ported into this GPL distribution. This file was not modified.'**
  String
  get aBindSectionWasFoundAutomaticUnpackingIsNotIncludedTheOriginalSteamlessCodeDeclaresCc;

  /// No description provided for @noBindSectionFoundThisDoesNotIdentifyOtherProtectionTypes.
  ///
  /// In en, this message translates to:
  /// **'No .bind section found; this does not identify other protection types.'**
  String get noBindSectionFoundThisDoesNotIdentifyOtherProtectionTypes;

  /// No description provided for @downloadGoldberg.
  ///
  /// In en, this message translates to:
  /// **'Download Goldberg'**
  String get downloadGoldberg;

  /// No description provided for @downloadEmulator.
  ///
  /// In en, this message translates to:
  /// **'Download emulator'**
  String get downloadEmulator;

  /// No description provided for @emulatorConfiguration.
  ///
  /// In en, this message translates to:
  /// **'Emulator configuration'**
  String get emulatorConfiguration;

  /// No description provided for @unknownIniKeysArePreservedInputIsValidatedAndConfigurationFilesAreBackedUpBeforeSavin.
  ///
  /// In en, this message translates to:
  /// **'Unknown INI keys are preserved. Input is validated and configuration files are backed up before saving.'**
  String
  get unknownIniKeysArePreservedInputIsValidatedAndConfigurationFilesAreBackedUpBeforeSavin;

  /// No description provided for @accountName.
  ///
  /// In en, this message translates to:
  /// **'Account name'**
  String get accountName;

  /// No description provided for @applicationTicketBase64.
  ///
  /// In en, this message translates to:
  /// **'Application ticket (Base64)'**
  String get applicationTicketBase64;

  /// No description provided for @languageCode.
  ///
  /// In en, this message translates to:
  /// **'Language code'**
  String get languageCode;

  /// No description provided for @listenPort.
  ///
  /// In en, this message translates to:
  /// **'Listen port'**
  String get listenPort;

  /// No description provided for @localSavePath.
  ///
  /// In en, this message translates to:
  /// **'Local save path'**
  String get localSavePath;

  /// No description provided for @supportedLanguages.
  ///
  /// In en, this message translates to:
  /// **'Supported languages'**
  String get supportedLanguages;

  /// No description provided for @customBroadcasts.
  ///
  /// In en, this message translates to:
  /// **'Custom broadcasts'**
  String get customBroadcasts;

  /// No description provided for @disableNetworking.
  ///
  /// In en, this message translates to:
  /// **'Disable networking'**
  String get disableNetworking;

  /// No description provided for @offlineMode.
  ///
  /// In en, this message translates to:
  /// **'Offline mode'**
  String get offlineMode;

  /// No description provided for @allDlc.
  ///
  /// In en, this message translates to:
  /// **'All DLC'**
  String get allDlc;

  /// No description provided for @emulatedCloudSaves.
  ///
  /// In en, this message translates to:
  /// **'Emulated cloud saves'**
  String get emulatedCloudSaves;

  /// No description provided for @createCloudDirectory.
  ///
  /// In en, this message translates to:
  /// **'Create cloud directory'**
  String get createCloudDirectory;

  /// No description provided for @experimentalOverlay.
  ///
  /// In en, this message translates to:
  /// **'Experimental overlay'**
  String get experimentalOverlay;

  /// No description provided for @saveGoldbergConfiguration.
  ///
  /// In en, this message translates to:
  /// **'Save Goldberg configuration'**
  String get saveGoldbergConfiguration;

  /// No description provided for @saveConfiguration.
  ///
  /// In en, this message translates to:
  /// **'Save configuration'**
  String get saveConfiguration;

  /// No description provided for @achievementsStatsItemsJson.
  ///
  /// In en, this message translates to:
  /// **'Achievements/stats/items JSON'**
  String get achievementsStatsItemsJson;

  /// No description provided for @exportZip.
  ///
  /// In en, this message translates to:
  /// **'Export ZIP'**
  String get exportZip;

  /// No description provided for @importConfigurationZip.
  ///
  /// In en, this message translates to:
  /// **'Import configuration ZIP'**
  String get importConfigurationZip;

  /// No description provided for @reload2.
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get reload2;

  /// No description provided for @editJsonDefinitions.
  ///
  /// In en, this message translates to:
  /// **'Edit JSON definitions'**
  String get editJsonDefinitions;

  /// No description provided for @applyToDraft.
  ///
  /// In en, this message translates to:
  /// **'Apply to draft'**
  String get applyToDraft;

  /// No description provided for @exportConfiguration.
  ///
  /// In en, this message translates to:
  /// **'Export configuration'**
  String get exportConfiguration;

  /// No description provided for @exportGoldbergConfiguration.
  ///
  /// In en, this message translates to:
  /// **'Export Goldberg configuration'**
  String get exportGoldbergConfiguration;

  /// No description provided for @importConfiguration.
  ///
  /// In en, this message translates to:
  /// **'Import configuration'**
  String get importConfiguration;

  /// No description provided for @existingConfigurationWillBeBackedUpBeforeReplacementContinue.
  ///
  /// In en, this message translates to:
  /// **'Existing configuration will be backed up before replacement. Continue?'**
  String get existingConfigurationWillBeBackedUpBeforeReplacementContinue;

  /// No description provided for @importGoldbergConfiguration.
  ///
  /// In en, this message translates to:
  /// **'Import Goldberg configuration'**
  String get importGoldbergConfiguration;

  /// No description provided for @authorizationTickets.
  ///
  /// In en, this message translates to:
  /// **'Authorization tickets'**
  String get authorizationTickets;

  /// No description provided for @authorization.
  ///
  /// In en, this message translates to:
  /// **'Authorization'**
  String get authorization;

  /// No description provided for @denuvoAuthorization.
  ///
  /// In en, this message translates to:
  /// **'Denuvo authorization'**
  String get denuvoAuthorization;

  /// No description provided for @denuvoAuthorizationDescription.
  ///
  /// In en, this message translates to:
  /// **'Extract, validate, back up and apply AppTicket and ETicket data for your locally signed-in Steam account.'**
  String get denuvoAuthorizationDescription;

  /// No description provided for @importedTicketsTxtFilesAreCheckedForAppidAndPayloadLengthsLocalBackupsUseCurrentUserW.
  ///
  /// In en, this message translates to:
  /// **'Imported tickets.txt files are checked for AppID and payload lengths. Local backups use current-user Windows DPAPI; the Steam registry changes only when you apply a ticket.'**
  String
  get importedTicketsTxtFilesAreCheckedForAppidAndPayloadLengthsLocalBackupsUseCurrentUserW;

  /// No description provided for @importTicketsTxt.
  ///
  /// In en, this message translates to:
  /// **'Import tickets.txt'**
  String get importTicketsTxt;

  /// No description provided for @importOneTicketFileAtATime.
  ///
  /// In en, this message translates to:
  /// **'Import one tickets.txt file at a time.'**
  String get importOneTicketFileAtATime;

  /// No description provided for @applyToSteam.
  ///
  /// In en, this message translates to:
  /// **'Apply to Steam'**
  String get applyToSteam;

  /// No description provided for @saveTicketBackup.
  ///
  /// In en, this message translates to:
  /// **'Save ticket backup'**
  String get saveTicketBackup;

  /// No description provided for @encryptedBackup.
  ///
  /// In en, this message translates to:
  /// **'Encrypted backup'**
  String get encryptedBackup;

  /// No description provided for @exportPlaintextFile.
  ///
  /// In en, this message translates to:
  /// **'Export plaintext file'**
  String get exportPlaintextFile;

  /// No description provided for @encryptedBackups.
  ///
  /// In en, this message translates to:
  /// **'Encrypted backups'**
  String get encryptedBackups;

  /// No description provided for @noSavedTickets.
  ///
  /// In en, this message translates to:
  /// **'No saved tickets.'**
  String get noSavedTickets;

  /// No description provided for @loadTicket.
  ///
  /// In en, this message translates to:
  /// **'Load ticket'**
  String get loadTicket;

  /// No description provided for @load.
  ///
  /// In en, this message translates to:
  /// **'Load'**
  String get load;

  /// No description provided for @deleteEncryptedBackup.
  ///
  /// In en, this message translates to:
  /// **'Delete encrypted backup'**
  String get deleteEncryptedBackup;

  /// No description provided for @deleteTicketBackup.
  ///
  /// In en, this message translates to:
  /// **'Delete ticket backup'**
  String get deleteTicketBackup;

  /// No description provided for @validateTicketFile.
  ///
  /// In en, this message translates to:
  /// **'Validate ticket file'**
  String get validateTicketFile;

  /// No description provided for @applySteamTicket.
  ///
  /// In en, this message translates to:
  /// **'Apply Steam ticket'**
  String get applySteamTicket;

  /// No description provided for @thisReplacesExistingAppticketAndEticketValuesForThisGame.
  ///
  /// In en, this message translates to:
  /// **'This replaces existing AppTicket and ETicket values for this game.'**
  String get thisReplacesExistingAppticketAndEticketValuesForThisGame;

  /// No description provided for @applyTicket.
  ///
  /// In en, this message translates to:
  /// **'Apply ticket'**
  String get applyTicket;

  /// No description provided for @exportPlaintextTicket.
  ///
  /// In en, this message translates to:
  /// **'Export plaintext ticket'**
  String get exportPlaintextTicket;

  /// No description provided for @exportTicket.
  ///
  /// In en, this message translates to:
  /// **'Export ticket'**
  String get exportTicket;

  /// No description provided for @configureTheReleaseRepositoryForThisFlutterApplicationFirst.
  ///
  /// In en, this message translates to:
  /// **'Configure the release repository for this Flutter application first.'**
  String get configureTheReleaseRepositoryForThisFlutterApplicationFirst;

  /// No description provided for @checkApplicationUpdates.
  ///
  /// In en, this message translates to:
  /// **'Check application updates'**
  String get checkApplicationUpdates;

  /// No description provided for @setStartupRegistration.
  ///
  /// In en, this message translates to:
  /// **'Set startup registration'**
  String get setStartupRegistration;

  /// No description provided for @setSteamOfflineMode.
  ///
  /// In en, this message translates to:
  /// **'Set Steam offline mode'**
  String get setSteamOfflineMode;

  /// No description provided for @selectTheSteamFolderFirst.
  ///
  /// In en, this message translates to:
  /// **'Select the Steam folder first.'**
  String get selectTheSteamFolderFirst;

  /// No description provided for @setFriendPresence.
  ///
  /// In en, this message translates to:
  /// **'Set friend presence'**
  String get setFriendPresence;

  /// No description provided for @backgroundAndSteamPreferences.
  ///
  /// In en, this message translates to:
  /// **'Background and Steam preferences'**
  String get backgroundAndSteamPreferences;

  /// No description provided for @readSteamAndStartupState.
  ///
  /// In en, this message translates to:
  /// **'Read Steam and startup state'**
  String get readSteamAndStartupState;

  /// No description provided for @automaticTasks.
  ///
  /// In en, this message translates to:
  /// **'Automatic tasks'**
  String get automaticTasks;

  /// No description provided for @refreshTheLibraryAutomatically.
  ///
  /// In en, this message translates to:
  /// **'Refresh the library automatically'**
  String get refreshTheLibraryAutomatically;

  /// No description provided for @watchManifestsAndLuaFilesAndScanAtTheSelectedIntervalRefreshManuallyFromTheLibraryWhe.
  ///
  /// In en, this message translates to:
  /// **'Watch manifests and Lua files and scan at the selected interval. Refresh manually from the library when disabled.'**
  String
  get watchManifestsAndLuaFilesAndScanAtTheSelectedIntervalRefreshManuallyFromTheLibraryWhe;

  /// No description provided for @refreshInterval.
  ///
  /// In en, this message translates to:
  /// **'Refresh interval'**
  String get refreshInterval;

  /// No description provided for @seconds.
  ///
  /// In en, this message translates to:
  /// **'{seconds} seconds'**
  String seconds(String seconds);

  /// No description provided for @checkForApplicationUpdatesAutomatically.
  ///
  /// In en, this message translates to:
  /// **'Check for application updates automatically'**
  String get checkForApplicationUpdatesAutomatically;

  /// No description provided for @checkAtStartupAndEvery24HoursUsingTheConfiguredFlutterApplicationReleaseRepository.
  ///
  /// In en, this message translates to:
  /// **'Check at startup and every 24 hours using the configured Flutter application release repository.'**
  String
  get checkAtStartupAndEvery24HoursUsingTheConfiguredFlutterApplicationReleaseRepository;

  /// No description provided for @updateKeySubscriptionsAutomatically.
  ///
  /// In en, this message translates to:
  /// **'Update key subscriptions automatically'**
  String get updateKeySubscriptionsAutomatically;

  /// No description provided for @whenEnabledCheckEnabledSubscriptionsHourlyAndDownloadUpdatesWhenTheirSourceIntervalIs.
  ///
  /// In en, this message translates to:
  /// **'When enabled, check enabled subscriptions hourly and download updates when their source interval is due.'**
  String
  get whenEnabledCheckEnabledSubscriptionsHourlyAndDownloadUpdatesWhenTheirSourceIntervalIs;

  /// No description provided for @newVersion.
  ///
  /// In en, this message translates to:
  /// **'New version {version}'**
  String newVersion(String version);

  /// No description provided for @viewReleaseNotesAndDownloadsInSettings.
  ///
  /// In en, this message translates to:
  /// **'View release notes and downloads in Settings.'**
  String get viewReleaseNotesAndDownloadsInSettings;

  /// No description provided for @startupAndSteam.
  ///
  /// In en, this message translates to:
  /// **'Startup and Steam'**
  String get startupAndSteam;

  /// No description provided for @launchFlsteamluaAtSignIn.
  ///
  /// In en, this message translates to:
  /// **'Launch FlSteamLua at sign-in'**
  String get launchFlsteamluaAtSignIn;

  /// No description provided for @readTheCurrentStateWithTheRefreshButton.
  ///
  /// In en, this message translates to:
  /// **'Read the current state with the refresh button.'**
  String get readTheCurrentStateWithTheRefreshButton;

  /// No description provided for @startWhenTheCurrentUserSignsInToWindows.
  ///
  /// In en, this message translates to:
  /// **'Start when the current user signs in to Windows.'**
  String get startWhenTheCurrentUserSignsInToWindows;

  /// No description provided for @broadcastPlayStatusToFriends.
  ///
  /// In en, this message translates to:
  /// **'Broadcast play status to friends'**
  String get broadcastPlayStatusToFriends;

  /// No description provided for @allowTheKernelToShowPlayStatusToSteamFriendsThroughSpacewarDisableToHideTheseBroadcas.
  ///
  /// In en, this message translates to:
  /// **'Allow the kernel to show play status to Steam friends through Spacewar. Disable to hide these broadcasts.'**
  String
  get allowTheKernelToShowPlayStatusToSteamFriendsThroughSpacewarDisableToHideTheseBroadcas;

  /// No description provided for @broadcastStateHasNotBeenReadYet.
  ///
  /// In en, this message translates to:
  /// **'Broadcast state has not been read yet.'**
  String get broadcastStateHasNotBeenReadYet;

  /// No description provided for @steamOfflineMode.
  ///
  /// In en, this message translates to:
  /// **'Steam offline mode'**
  String get steamOfflineMode;

  /// No description provided for @setOfflineOptionsForTheMostRecentAccountAppliesOnTheNextSteamLaunchWithoutRestartingS.
  ///
  /// In en, this message translates to:
  /// **'Set offline options for the most recent account. Applies on the next Steam launch without restarting Steam automatically.'**
  String
  get setOfflineOptionsForTheMostRecentAccountAppliesOnTheNextSteamLaunchWithoutRestartingS;

  /// No description provided for @noRecentSteamAccountWasReadSignInToSteamThenRefreshTheState.
  ///
  /// In en, this message translates to:
  /// **'No recent Steam account was read. Sign in to Steam, then refresh the state.'**
  String get noRecentSteamAccountWasReadSignInToSteamThenRefreshTheState;

  /// No description provided for @lastBackgroundTaskFailure.
  ///
  /// In en, this message translates to:
  /// **'Last background task failure: {backgroundError}'**
  String lastBackgroundTaskFailure(String backgroundError);

  /// No description provided for @steamGuardVerification.
  ///
  /// In en, this message translates to:
  /// **'Steam Guard verification'**
  String get steamGuardVerification;

  /// No description provided for @enterTheCodeFromYourEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter the code from your email.'**
  String get enterTheCodeFromYourEmail;

  /// No description provided for @enterYourSteamMobileAuthenticatorCode.
  ///
  /// In en, this message translates to:
  /// **'Enter your Steam mobile authenticator code.'**
  String get enterYourSteamMobileAuthenticatorCode;

  /// No description provided for @approveThisSignInInTheSteamMobileAppThenContinue.
  ///
  /// In en, this message translates to:
  /// **'Approve this sign-in in the Steam mobile app, then continue.'**
  String get approveThisSignInInTheSteamMobileAppThenContinue;

  /// No description provided for @code.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get code;

  /// No description provided for @signInToSteam.
  ///
  /// In en, this message translates to:
  /// **'Sign in to Steam'**
  String get signInToSteam;

  /// No description provided for @enterAValidAppid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid AppID'**
  String get enterAValidAppid;

  /// No description provided for @selectTheExportFolder.
  ///
  /// In en, this message translates to:
  /// **'Select the export folder'**
  String get selectTheExportFolder;

  /// No description provided for @extractGame.
  ///
  /// In en, this message translates to:
  /// **'Extract game {id}'**
  String extractGame(String id);

  /// No description provided for @depotKeys.
  ///
  /// In en, this message translates to:
  /// **'Depot keys'**
  String get depotKeys;

  /// No description provided for @savedManifests.
  ///
  /// In en, this message translates to:
  /// **'Saved manifests'**
  String get savedManifests;

  /// No description provided for @itemsNotCompleted.
  ///
  /// In en, this message translates to:
  /// **'Items not completed'**
  String get itemsNotCompleted;

  /// No description provided for @filesSaved.
  ///
  /// In en, this message translates to:
  /// **'Files saved'**
  String get filesSaved;

  /// No description provided for @steamAccountExtraction.
  ///
  /// In en, this message translates to:
  /// **'Steam account & extraction'**
  String get steamAccountExtraction;

  /// No description provided for @connectToSteamToExportManifestsAccessibleToThisAccountYourPasswordIsUsedOnlyForSignIn.
  ///
  /// In en, this message translates to:
  /// **'Connect to Steam to export manifests accessible to this account. Your password is used only for sign-in.'**
  String
  get connectToSteamToExportManifestsAccessibleToThisAccountYourPasswordIsUsedOnlyForSignIn;

  /// No description provided for @connectedToSteam.
  ///
  /// In en, this message translates to:
  /// **'Connected to Steam'**
  String get connectedToSteam;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @signOutAndForgetSession.
  ///
  /// In en, this message translates to:
  /// **'Sign out and forget session'**
  String get signOutAndForgetSession;

  /// No description provided for @accountName2.
  ///
  /// In en, this message translates to:
  /// **'Account name'**
  String get accountName2;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @restoreSteamSession.
  ///
  /// In en, this message translates to:
  /// **'Restore Steam session'**
  String get restoreSteamSession;

  /// No description provided for @useSavedSession.
  ///
  /// In en, this message translates to:
  /// **'Use saved session'**
  String get useSavedSession;

  /// No description provided for @exportLuaManifests.
  ///
  /// In en, this message translates to:
  /// **'Export Lua & manifests'**
  String get exportLuaManifests;

  /// No description provided for @includeAccessibleDlc.
  ///
  /// In en, this message translates to:
  /// **'Include accessible DLC'**
  String get includeAccessibleDlc;

  /// No description provided for @downloadManifestFiles.
  ///
  /// In en, this message translates to:
  /// **'Download manifest files'**
  String get downloadManifestFiles;

  /// No description provided for @pinCurrentPublicManifestVersions.
  ///
  /// In en, this message translates to:
  /// **'Pin current public manifest versions'**
  String get pinCurrentPublicManifestVersions;

  /// No description provided for @chooseFolderExport.
  ///
  /// In en, this message translates to:
  /// **'Choose folder & export'**
  String get chooseFolderExport;

  /// No description provided for @store.
  ///
  /// In en, this message translates to:
  /// **'Store'**
  String get store;

  /// No description provided for @discoverGamesPurchaseAndInstallThroughSteam.
  ///
  /// In en, this message translates to:
  /// **'Discover games. Purchase and install through Steam.'**
  String get discoverGamesPurchaseAndInstallThroughSteam;

  /// No description provided for @searchGameTitles.
  ///
  /// In en, this message translates to:
  /// **'Search game titles'**
  String get searchGameTitles;

  /// No description provided for @showAdultContent.
  ///
  /// In en, this message translates to:
  /// **'Show adult content'**
  String get showAdultContent;

  /// No description provided for @hideAdultContent.
  ///
  /// In en, this message translates to:
  /// **'Hide adult content'**
  String get hideAdultContent;

  /// No description provided for @storeRegion.
  ///
  /// In en, this message translates to:
  /// **'Store region'**
  String get storeRegion;

  /// No description provided for @regionChinaMainland.
  ///
  /// In en, this message translates to:
  /// **'Mainland China'**
  String get regionChinaMainland;

  /// No description provided for @regionHongKong.
  ///
  /// In en, this message translates to:
  /// **'Hong Kong, China'**
  String get regionHongKong;

  /// No description provided for @regionTaiwan.
  ///
  /// In en, this message translates to:
  /// **'Taiwan, China'**
  String get regionTaiwan;

  /// No description provided for @regionUnitedStates.
  ///
  /// In en, this message translates to:
  /// **'United States'**
  String get regionUnitedStates;

  /// No description provided for @regionJapan.
  ///
  /// In en, this message translates to:
  /// **'Japan'**
  String get regionJapan;

  /// No description provided for @regionSouthKorea.
  ///
  /// In en, this message translates to:
  /// **'South Korea'**
  String get regionSouthKorea;

  /// No description provided for @regionSingapore.
  ///
  /// In en, this message translates to:
  /// **'Singapore'**
  String get regionSingapore;

  /// No description provided for @regionUnitedKingdom.
  ///
  /// In en, this message translates to:
  /// **'United Kingdom'**
  String get regionUnitedKingdom;

  /// No description provided for @regionGermany.
  ///
  /// In en, this message translates to:
  /// **'Germany'**
  String get regionGermany;

  /// No description provided for @regionFrance.
  ///
  /// In en, this message translates to:
  /// **'France'**
  String get regionFrance;

  /// No description provided for @regionCanada.
  ///
  /// In en, this message translates to:
  /// **'Canada'**
  String get regionCanada;

  /// No description provided for @regionAustralia.
  ///
  /// In en, this message translates to:
  /// **'Australia'**
  String get regionAustralia;

  /// No description provided for @regionBrazil.
  ///
  /// In en, this message translates to:
  /// **'Brazil'**
  String get regionBrazil;

  /// No description provided for @regionRussia.
  ///
  /// In en, this message translates to:
  /// **'Russia'**
  String get regionRussia;

  /// No description provided for @regionArgentina.
  ///
  /// In en, this message translates to:
  /// **'Argentina'**
  String get regionArgentina;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @popular.
  ///
  /// In en, this message translates to:
  /// **'Popular'**
  String get popular;

  /// No description provided for @newReleases.
  ///
  /// In en, this message translates to:
  /// **'New releases'**
  String get newReleases;

  /// No description provided for @specials.
  ///
  /// In en, this message translates to:
  /// **'Specials'**
  String get specials;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get comingSoon;

  /// No description provided for @noMatchingGames2.
  ///
  /// In en, this message translates to:
  /// **'No matching games'**
  String get noMatchingGames2;

  /// No description provided for @storeUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Store unavailable'**
  String get storeUnavailable;

  /// No description provided for @reload3.
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get reload3;

  /// No description provided for @ofGames.
  ///
  /// In en, this message translates to:
  /// **'{itemsCount} of {total} games'**
  String ofGames(String itemsCount, String total);

  /// No description provided for @loadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get loadMore;

  /// No description provided for @allResultsLoaded.
  ///
  /// In en, this message translates to:
  /// **'All results loaded'**
  String get allResultsLoaded;

  /// No description provided for @viewStorePrice.
  ///
  /// In en, this message translates to:
  /// **'View store price'**
  String get viewStorePrice;

  /// No description provided for @viewFixFiles.
  ///
  /// In en, this message translates to:
  /// **'View fix files'**
  String get viewFixFiles;

  /// No description provided for @fixFiles.
  ///
  /// In en, this message translates to:
  /// **'Fix files'**
  String get fixFiles;

  /// No description provided for @downloadOnlineFix.
  ///
  /// In en, this message translates to:
  /// **'Download online fix'**
  String get downloadOnlineFix;

  /// No description provided for @downloaded.
  ///
  /// In en, this message translates to:
  /// **'Downloaded'**
  String get downloaded;

  /// No description provided for @archivePasswordOnlineFixMe.
  ///
  /// In en, this message translates to:
  /// **'Archive password: online-fix.me'**
  String get archivePasswordOnlineFixMe;

  /// No description provided for @copyPassword.
  ///
  /// In en, this message translates to:
  /// **'Copy password'**
  String get copyPassword;

  /// No description provided for @instructionsOriginalText.
  ///
  /// In en, this message translates to:
  /// **'Instructions (original text)'**
  String get instructionsOriginalText;

  /// No description provided for @showMore.
  ///
  /// In en, this message translates to:
  /// **'Show more'**
  String get showMore;

  /// No description provided for @showLess.
  ///
  /// In en, this message translates to:
  /// **'Show less'**
  String get showLess;

  /// No description provided for @filesAndInstructionsAreSavedInASeparateFolderForEachGame.
  ///
  /// In en, this message translates to:
  /// **'Files and instructions are saved in a separate folder for each game.'**
  String get filesAndInstructionsAreSavedInASeparateFolderForEachGame;

  /// No description provided for @sourcePage.
  ///
  /// In en, this message translates to:
  /// **'Source page'**
  String get sourcePage;

  /// No description provided for @parentFolder.
  ///
  /// In en, this message translates to:
  /// **'Parent folder'**
  String get parentFolder;

  /// No description provided for @cancelDownload.
  ///
  /// In en, this message translates to:
  /// **'Cancel download'**
  String get cancelDownload;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @noFixFilesAreAvailableInThisDirectory.
  ///
  /// In en, this message translates to:
  /// **'No fix files are available in this directory.'**
  String get noFixFilesAreAvailableInThisDirectory;

  /// No description provided for @noMatchingOnlineFixes.
  ///
  /// In en, this message translates to:
  /// **'No matching online fixes'**
  String get noMatchingOnlineFixes;

  /// No description provided for @noOnlineFixesAvailable.
  ///
  /// In en, this message translates to:
  /// **'No online fixes are available right now'**
  String get noOnlineFixesAvailable;

  /// No description provided for @searchAGameForFixFilesAndInstructions.
  ///
  /// In en, this message translates to:
  /// **'Search a game for fix files and instructions'**
  String get searchAGameForFixFilesAndInstructions;

  /// No description provided for @sourceOnlineFixMe.
  ///
  /// In en, this message translates to:
  /// **'Source: online-fix.me'**
  String get sourceOnlineFixMe;

  /// No description provided for @fixActions.
  ///
  /// In en, this message translates to:
  /// **'Fix actions'**
  String get fixActions;

  /// No description provided for @backToResults.
  ///
  /// In en, this message translates to:
  /// **'Back to results'**
  String get backToResults;

  /// No description provided for @searchOnlineFixes.
  ///
  /// In en, this message translates to:
  /// **'Search online fixes'**
  String get searchOnlineFixes;

  /// No description provided for @spacewar480Multiplayer.
  ///
  /// In en, this message translates to:
  /// **'Spacewar (480) multiplayer'**
  String get spacewar480Multiplayer;

  /// No description provided for @withAKernelThatSupportsOst480MultiplayerLaunchOptionsMapTheGameToSpacewarBothPlayersM.
  ///
  /// In en, this message translates to:
  /// **'With a kernel that supports OST 480 multiplayer, launch options map the game to Spacewar. Both players must use the same multiplayer method.'**
  String
  get withAKernelThatSupportsOst480MultiplayerLaunchOptionsMapTheGameToSpacewarBothPlayersM;

  /// No description provided for @setup.
  ///
  /// In en, this message translates to:
  /// **'Setup'**
  String get setup;

  /// No description provided for @message1RightClickTheGameInSteamAndOpenProperties2AddTheOptionBelowToLaunchOptions3St.
  ///
  /// In en, this message translates to:
  /// **'1. Right-click the game in Steam and open Properties.\n2. Add the option below to Launch Options.\n3. Start the game. Remove the option to restore the default.'**
  String
  get message1RightClickTheGameInSteamAndOpenProperties2AddTheOptionBelowToLaunchOptions3St;

  /// No description provided for @copyLaunchOption.
  ///
  /// In en, this message translates to:
  /// **'Copy launch option'**
  String get copyLaunchOption;

  /// No description provided for @requiresACompatibleKernelAndLobbyBasedGameOnlyOneSuchGameCanRunAtATime.
  ///
  /// In en, this message translates to:
  /// **'Requires a compatible kernel and lobby-based game; only one such game can run at a time.'**
  String
  get requiresACompatibleKernelAndLobbyBasedGameOnlyOneSuchGameCanRunAtATime;

  /// No description provided for @downloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get downloads;

  /// No description provided for @spacewar480.
  ///
  /// In en, this message translates to:
  /// **'Spacewar (480)'**
  String get spacewar480;

  /// No description provided for @previousPage.
  ///
  /// In en, this message translates to:
  /// **'Previous page'**
  String get previousPage;

  /// No description provided for @nextPage.
  ///
  /// In en, this message translates to:
  /// **'Next page'**
  String get nextPage;

  /// No description provided for @goToPage.
  ///
  /// In en, this message translates to:
  /// **'Go to page'**
  String get goToPage;

  /// No description provided for @pageNumber.
  ///
  /// In en, this message translates to:
  /// **'Page'**
  String get pageNumber;

  /// No description provided for @pageOutOfRange.
  ///
  /// In en, this message translates to:
  /// **'Enter a page between 1 and {totalPages}'**
  String pageOutOfRange(int totalPages);

  /// No description provided for @downloadTrainer.
  ///
  /// In en, this message translates to:
  /// **'Download trainer'**
  String get downloadTrainer;

  /// No description provided for @thisArchiveIsAvailableForDirectDownload.
  ///
  /// In en, this message translates to:
  /// **'This archive is available for direct download.'**
  String get thisArchiveIsAvailableForDirectDownload;

  /// No description provided for @addGameBinding.
  ///
  /// In en, this message translates to:
  /// **'Add game binding'**
  String get addGameBinding;

  /// No description provided for @editGameBinding.
  ///
  /// In en, this message translates to:
  /// **'Edit game binding'**
  String get editGameBinding;

  /// No description provided for @chooseFromLibrary.
  ///
  /// In en, this message translates to:
  /// **'Choose from library'**
  String get chooseFromLibrary;

  /// No description provided for @enterAValidAppid2.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid AppID'**
  String get enterAValidAppid2;

  /// No description provided for @gameName.
  ///
  /// In en, this message translates to:
  /// **'Game name'**
  String get gameName;

  /// No description provided for @enterTheGameName.
  ///
  /// In en, this message translates to:
  /// **'Enter the game name'**
  String get enterTheGameName;

  /// No description provided for @gameExecutable.
  ///
  /// In en, this message translates to:
  /// **'Game executable'**
  String get gameExecutable;

  /// No description provided for @chooseGameExecutable.
  ///
  /// In en, this message translates to:
  /// **'Choose game executable'**
  String get chooseGameExecutable;

  /// No description provided for @trainerExecutable.
  ///
  /// In en, this message translates to:
  /// **'Trainer executable'**
  String get trainerExecutable;

  /// No description provided for @chooseTrainerExecutable.
  ///
  /// In en, this message translates to:
  /// **'Choose trainer executable'**
  String get chooseTrainerExecutable;

  /// No description provided for @useADownloadedTrainer.
  ///
  /// In en, this message translates to:
  /// **'Use a downloaded trainer'**
  String get useADownloadedTrainer;

  /// No description provided for @startAndStopWithTheGame.
  ///
  /// In en, this message translates to:
  /// **'Start and stop with the game'**
  String get startAndStopWithTheGame;

  /// No description provided for @deleteTrainer.
  ///
  /// In en, this message translates to:
  /// **'Delete trainer'**
  String get deleteTrainer;

  /// No description provided for @associatedGameBindingsWillAlsoBeRemoved.
  ///
  /// In en, this message translates to:
  /// **'Associated game bindings will also be removed.'**
  String get associatedGameBindingsWillAlsoBeRemoved;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @searchGameNames.
  ///
  /// In en, this message translates to:
  /// **'Search game names'**
  String get searchGameNames;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @recentUpdates.
  ///
  /// In en, this message translates to:
  /// **'Recent updates'**
  String get recentUpdates;

  /// No description provided for @allTrainers.
  ///
  /// In en, this message translates to:
  /// **'All trainers'**
  String get allTrainers;

  /// No description provided for @archive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get archive;

  /// No description provided for @trainers2.
  ///
  /// In en, this message translates to:
  /// **'trainers'**
  String get trainers2;

  /// No description provided for @loadingFling.
  ///
  /// In en, this message translates to:
  /// **'Loading FLiNG…'**
  String get loadingFling;

  /// No description provided for @noMatchingTrainers.
  ///
  /// In en, this message translates to:
  /// **'No matching trainers'**
  String get noMatchingTrainers;

  /// No description provided for @downloadAgain.
  ///
  /// In en, this message translates to:
  /// **'Download again'**
  String get downloadAgain;

  /// No description provided for @myTrainers.
  ///
  /// In en, this message translates to:
  /// **'My trainers'**
  String get myTrainers;

  /// No description provided for @downloadFolder.
  ///
  /// In en, this message translates to:
  /// **'Download folder'**
  String get downloadFolder;

  /// No description provided for @noDownloadedTrainers.
  ///
  /// In en, this message translates to:
  /// **'No downloaded trainers'**
  String get noDownloadedTrainers;

  /// No description provided for @downloadFromBrowseThenOpenArchivesToExtractAndBindAnExecutable.
  ///
  /// In en, this message translates to:
  /// **'Download from Browse, then open archives to extract and bind an executable.'**
  String get downloadFromBrowseThenOpenArchivesToExtractAndBindAnExecutable;

  /// No description provided for @stop3.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop3;

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// No description provided for @manageTrainer.
  ///
  /// In en, this message translates to:
  /// **'Manage trainer'**
  String get manageTrainer;

  /// No description provided for @bindToGame.
  ///
  /// In en, this message translates to:
  /// **'Bind to game'**
  String get bindToGame;

  /// No description provided for @openContainingFolder.
  ///
  /// In en, this message translates to:
  /// **'Open containing folder'**
  String get openContainingFolder;

  /// No description provided for @createDesktopShortcut.
  ///
  /// In en, this message translates to:
  /// **'Create desktop shortcut'**
  String get createDesktopShortcut;

  /// No description provided for @gameAndTrainerBindings.
  ///
  /// In en, this message translates to:
  /// **'Game and trainer bindings'**
  String get gameAndTrainerBindings;

  /// No description provided for @addBinding.
  ///
  /// In en, this message translates to:
  /// **'Add binding'**
  String get addBinding;

  /// No description provided for @bindALocalTrainerToAGame.
  ///
  /// In en, this message translates to:
  /// **'Bind a local trainer to a game'**
  String get bindALocalTrainerToAGame;

  /// No description provided for @enabledTrainersStartAndStopWithTheDetectedGameProcess.
  ///
  /// In en, this message translates to:
  /// **'Enabled trainers start and stop with the detected game process.'**
  String get enabledTrainersStartAndStopWithTheDetectedGameProcess;

  /// No description provided for @launch2.
  ///
  /// In en, this message translates to:
  /// **'Launch'**
  String get launch2;

  /// No description provided for @editBinding.
  ///
  /// In en, this message translates to:
  /// **'Edit binding'**
  String get editBinding;

  /// No description provided for @removeBinding.
  ///
  /// In en, this message translates to:
  /// **'Remove binding'**
  String get removeBinding;

  /// No description provided for @browse.
  ///
  /// In en, this message translates to:
  /// **'Browse'**
  String get browse;

  /// No description provided for @gameBindings.
  ///
  /// In en, this message translates to:
  /// **'Game bindings'**
  String get gameBindings;

  /// No description provided for @operationFailed.
  ///
  /// In en, this message translates to:
  /// **'Operation failed'**
  String get operationFailed;

  /// No description provided for @chooseOutputFolder.
  ///
  /// In en, this message translates to:
  /// **'Choose output folder'**
  String get chooseOutputFolder;

  /// No description provided for @luaVdfConversion.
  ///
  /// In en, this message translates to:
  /// **'Lua / VDF conversion'**
  String get luaVdfConversion;

  /// No description provided for @writesNewFilesWithoutOverwritingLuaToVdfRequiresAnAppid.
  ///
  /// In en, this message translates to:
  /// **'Writes new files without overwriting. Lua to VDF requires an AppID.'**
  String get writesNewFilesWithoutOverwritingLuaToVdfRequiresAnAppid;

  /// No description provided for @appidOptional.
  ///
  /// In en, this message translates to:
  /// **'AppID (optional)'**
  String get appidOptional;

  /// No description provided for @includeManifestPinsWhenConvertingVdf.
  ///
  /// In en, this message translates to:
  /// **'Include manifest pins when converting VDF'**
  String get includeManifestPinsWhenConvertingVdf;

  /// No description provided for @convert.
  ///
  /// In en, this message translates to:
  /// **'Convert'**
  String get convert;

  /// No description provided for @convertFiles.
  ///
  /// In en, this message translates to:
  /// **'Convert files'**
  String get convertFiles;

  /// No description provided for @chooseSourceFolder.
  ///
  /// In en, this message translates to:
  /// **'Choose source folder'**
  String get chooseSourceFolder;

  /// No description provided for @batchConversion.
  ///
  /// In en, this message translates to:
  /// **'Batch conversion'**
  String get batchConversion;

  /// No description provided for @pinGameVersion.
  ///
  /// In en, this message translates to:
  /// **'Pin game version'**
  String get pinGameVersion;

  /// No description provided for @pinCurrentlyInstalledManifests.
  ///
  /// In en, this message translates to:
  /// **'Pin currently installed manifests'**
  String get pinCurrentlyInstalledManifests;

  /// No description provided for @pinLatestPublicManifests.
  ///
  /// In en, this message translates to:
  /// **'Pin latest public manifests'**
  String get pinLatestPublicManifests;

  /// No description provided for @unpinKeepCommentedRecords.
  ///
  /// In en, this message translates to:
  /// **'Unpin (keep commented records)'**
  String get unpinKeepCommentedRecords;

  /// No description provided for @updateManifestPins2.
  ///
  /// In en, this message translates to:
  /// **'Update manifest pins'**
  String get updateManifestPins2;

  /// No description provided for @addDlcAppids.
  ///
  /// In en, this message translates to:
  /// **'Add DLC AppIDs'**
  String get addDlcAppids;

  /// No description provided for @dlcAppidsSeparatedBySpacesCommasOrNewlines.
  ///
  /// In en, this message translates to:
  /// **'DLC AppIDs separated by spaces, commas or newlines'**
  String get dlcAppidsSeparatedBySpacesCommasOrNewlines;

  /// No description provided for @addToLua.
  ///
  /// In en, this message translates to:
  /// **'Add to Lua'**
  String get addToLua;

  /// No description provided for @addDlc.
  ///
  /// In en, this message translates to:
  /// **'Add DLC'**
  String get addDlc;

  /// No description provided for @environmentDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Environment diagnostics'**
  String get environmentDiagnostics;

  /// No description provided for @manifestMonitorAndDownloadRepair.
  ///
  /// In en, this message translates to:
  /// **'Manifest monitor and download repair'**
  String get manifestMonitorAndDownloadRepair;

  /// No description provided for @watchNewSteamContentLogRequestsAndDownloadManifestsFromCodeProvidersAndSteamCdnIntoDe.
  ///
  /// In en, this message translates to:
  /// **'Watch new Steam content_log requests and download manifests from code providers and Steam CDN into depotcache. Tasks continue across pages.'**
  String
  get watchNewSteamContentLogRequestsAndDownloadManifestsFromCodeProvidersAndSteamCdnIntoDe;

  /// No description provided for @noLogEntriesYet.
  ///
  /// In en, this message translates to:
  /// **'No log entries yet'**
  String get noLogEntriesYet;

  /// No description provided for @stopMonitoring.
  ///
  /// In en, this message translates to:
  /// **'Stop monitoring'**
  String get stopMonitoring;

  /// No description provided for @startMonitoring.
  ///
  /// In en, this message translates to:
  /// **'Start monitoring'**
  String get startMonitoring;

  /// No description provided for @tools.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get tools;

  /// No description provided for @openToolsAsNeededOrStartFromAGameSDetailPage.
  ///
  /// In en, this message translates to:
  /// **'Open tools as needed, or start from a game’s detail page.'**
  String get openToolsAsNeededOrStartFromAGameSDetailPage;

  /// No description provided for @filesAndManifests.
  ///
  /// In en, this message translates to:
  /// **'Files and manifests'**
  String get filesAndManifests;

  /// No description provided for @convertLuaVdfAndAcfFilesToASeparateOutputFolder.
  ///
  /// In en, this message translates to:
  /// **'Convert Lua, VDF and ACF files to a separate output folder'**
  String get convertLuaVdfAndAcfFilesToASeparateOutputFolder;

  /// No description provided for @convertAFolder.
  ///
  /// In en, this message translates to:
  /// **'Convert a folder'**
  String get convertAFolder;

  /// No description provided for @processAllSupportedFilesInAFolder.
  ///
  /// In en, this message translates to:
  /// **'Process all supported files in a folder'**
  String get processAllSupportedFilesInAFolder;

  /// No description provided for @manifestMonitoring.
  ///
  /// In en, this message translates to:
  /// **'Manifest monitoring'**
  String get manifestMonitoring;

  /// No description provided for @fetchMissingManifestsRequestedBySteam.
  ///
  /// In en, this message translates to:
  /// **'Fetch missing manifests requested by Steam'**
  String get fetchMissingManifestsRequestedBySteam;

  /// No description provided for @manifestVersionPins.
  ///
  /// In en, this message translates to:
  /// **'Manifest version pins'**
  String get manifestVersionPins;

  /// No description provided for @installedManifestsLatestPublicManifestsOrUnpin.
  ///
  /// In en, this message translates to:
  /// **'Installed manifests, latest public manifests or unpin'**
  String get installedManifestsLatestPublicManifestsOrUnpin;

  /// No description provided for @appendDlcEntriesWithoutDuplicatingExistingRecords.
  ///
  /// In en, this message translates to:
  /// **'Append DLC entries without duplicating existing records'**
  String get appendDlcEntriesWithoutDuplicatingExistingRecords;

  /// No description provided for @downloadCover.
  ///
  /// In en, this message translates to:
  /// **'Download cover'**
  String get downloadCover;

  /// No description provided for @saveToTheApplicationCoverCache.
  ///
  /// In en, this message translates to:
  /// **'Save to the application cover cache'**
  String get saveToTheApplicationCoverCache;

  /// No description provided for @gameTools.
  ///
  /// In en, this message translates to:
  /// **'Game tools'**
  String get gameTools;

  /// No description provided for @searchDownloadAndBindTrainers.
  ///
  /// In en, this message translates to:
  /// **'Search, download and bind trainers'**
  String get searchDownloadAndBindTrainers;

  /// No description provided for @findOnlineFixesAndDownloadFiles.
  ///
  /// In en, this message translates to:
  /// **'Find online fixes and download files'**
  String get findOnlineFixesAndDownloadFiles;

  /// No description provided for @openTool.
  ///
  /// In en, this message translates to:
  /// **'Open tool'**
  String get openTool;

  /// No description provided for @maintenance.
  ///
  /// In en, this message translates to:
  /// **'Maintenance'**
  String get maintenance;

  /// No description provided for @diagnostics.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get diagnostics;

  /// No description provided for @steamPathClientAndDataDirectories.
  ///
  /// In en, this message translates to:
  /// **'Steam path, client and data directories'**
  String get steamPathClientAndDataDirectories;

  /// No description provided for @openLogFolder.
  ///
  /// In en, this message translates to:
  /// **'Open log folder'**
  String get openLogFolder;

  /// No description provided for @logFolder.
  ///
  /// In en, this message translates to:
  /// **'Log folder'**
  String get logFolder;

  /// No description provided for @openBackupFolder.
  ///
  /// In en, this message translates to:
  /// **'Open backup folder'**
  String get openBackupFolder;

  /// No description provided for @backupFolder.
  ///
  /// In en, this message translates to:
  /// **'Backup folder'**
  String get backupFolder;

  /// No description provided for @openFlsteamlua.
  ///
  /// In en, this message translates to:
  /// **'Open FlSteamLua'**
  String get openFlsteamlua;

  /// No description provided for @quit.
  ///
  /// In en, this message translates to:
  /// **'Quit'**
  String get quit;

  /// No description provided for @collapseSidebar.
  ///
  /// In en, this message translates to:
  /// **'Collapse sidebar'**
  String get collapseSidebar;

  /// No description provided for @expandSidebar.
  ///
  /// In en, this message translates to:
  /// **'Expand sidebar'**
  String get expandSidebar;

  /// No description provided for @contentSources.
  ///
  /// In en, this message translates to:
  /// **'Content sources'**
  String get contentSources;

  /// No description provided for @allSources.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get allSources;

  /// No description provided for @luaSources.
  ///
  /// In en, this message translates to:
  /// **'Lua'**
  String get luaSources;

  /// No description provided for @manifestSources.
  ///
  /// In en, this message translates to:
  /// **'Manifests'**
  String get manifestSources;

  /// No description provided for @enabledSources.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get enabledSources;

  /// No description provided for @failedSources.
  ///
  /// In en, this message translates to:
  /// **'Needs attention'**
  String get failedSources;

  /// No description provided for @subscriptionSource.
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get subscriptionSource;

  /// No description provided for @scriptSource.
  ///
  /// In en, this message translates to:
  /// **'JS script'**
  String get scriptSource;

  /// No description provided for @localSource.
  ///
  /// In en, this message translates to:
  /// **'Local'**
  String get localSource;

  /// No description provided for @manifestIds.
  ///
  /// In en, this message translates to:
  /// **'Manifest IDs'**
  String get manifestIds;

  /// No description provided for @manifestFiles.
  ///
  /// In en, this message translates to:
  /// **'Manifest files'**
  String get manifestFiles;

  /// No description provided for @addContentSource.
  ///
  /// In en, this message translates to:
  /// **'Add content source'**
  String get addContentSource;

  /// No description provided for @addSubscriptionSource.
  ///
  /// In en, this message translates to:
  /// **'Add subscription source'**
  String get addSubscriptionSource;

  /// No description provided for @importScriptSource.
  ///
  /// In en, this message translates to:
  /// **'Import JS content source'**
  String get importScriptSource;

  /// No description provided for @importLocalContent.
  ///
  /// In en, this message translates to:
  /// **'Import local content'**
  String get importLocalContent;

  /// No description provided for @editSource.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get editSource;

  /// No description provided for @editScript.
  ///
  /// In en, this message translates to:
  /// **'Edit script'**
  String get editScript;

  /// No description provided for @configureSource.
  ///
  /// In en, this message translates to:
  /// **'Configure source'**
  String get configureSource;

  /// No description provided for @validateScript.
  ///
  /// In en, this message translates to:
  /// **'Validate script'**
  String get validateScript;

  /// No description provided for @restoreBuiltInScript.
  ///
  /// In en, this message translates to:
  /// **'Restore built-in script'**
  String get restoreBuiltInScript;

  /// No description provided for @openScriptFolder.
  ///
  /// In en, this message translates to:
  /// **'Open script folder'**
  String get openScriptFolder;

  /// No description provided for @scriptSaved.
  ///
  /// In en, this message translates to:
  /// **'Script saved'**
  String get scriptSaved;

  /// No description provided for @scriptIsValid.
  ///
  /// In en, this message translates to:
  /// **'Script syntax and metadata are valid'**
  String get scriptIsValid;

  /// No description provided for @theseScriptChangesHaveNotBeenSaved.
  ///
  /// In en, this message translates to:
  /// **'These script changes have not been saved.'**
  String get theseScriptChangesHaveNotBeenSaved;

  /// No description provided for @testSource.
  ///
  /// In en, this message translates to:
  /// **'Test'**
  String get testSource;

  /// No description provided for @updateSource.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get updateSource;

  /// No description provided for @enableSource.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get enableSource;

  /// No description provided for @disableSource.
  ///
  /// In en, this message translates to:
  /// **'Disable'**
  String get disableSource;

  /// No description provided for @deleteSource.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteSource;

  /// No description provided for @deleteSourceConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this content source and its local configuration?'**
  String get deleteSourceConfirm;

  /// No description provided for @sourceConfigurationRequired.
  ///
  /// In en, this message translates to:
  /// **'Setup required'**
  String get sourceConfigurationRequired;

  /// No description provided for @sourceConfigured.
  ///
  /// In en, this message translates to:
  /// **'Configured'**
  String get sourceConfigured;

  /// No description provided for @sourceNotTested.
  ///
  /// In en, this message translates to:
  /// **'Not tested'**
  String get sourceNotTested;

  /// No description provided for @sourceNeverUpdated.
  ///
  /// In en, this message translates to:
  /// **'Not updated'**
  String get sourceNeverUpdated;

  /// No description provided for @noContentSources.
  ///
  /// In en, this message translates to:
  /// **'No matching content sources'**
  String get noContentSources;

  /// No description provided for @contentImport.
  ///
  /// In en, this message translates to:
  /// **'Add to Lua library'**
  String get contentImport;

  /// No description provided for @luaContentSource.
  ///
  /// In en, this message translates to:
  /// **'Lua content source'**
  String get luaContentSource;

  /// No description provided for @manifestContentSource.
  ///
  /// In en, this message translates to:
  /// **'Manifest source (optional)'**
  String get manifestContentSource;

  /// No description provided for @noManifestSource.
  ///
  /// In en, this message translates to:
  /// **'None; let Steam or the kernel retrieve manifests'**
  String get noManifestSource;

  /// No description provided for @previewContent.
  ///
  /// In en, this message translates to:
  /// **'Preview content'**
  String get previewContent;

  /// No description provided for @importContent.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get importContent;

  /// No description provided for @contentImportComplete.
  ///
  /// In en, this message translates to:
  /// **'Import complete'**
  String get contentImportComplete;

  /// No description provided for @contentImportReplace.
  ///
  /// In en, this message translates to:
  /// **'Replace existing files and back up'**
  String get contentImportReplace;

  /// No description provided for @configureContentSources.
  ///
  /// In en, this message translates to:
  /// **'Manage content sources'**
  String get configureContentSources;

  /// No description provided for @sourceName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get sourceName;

  /// No description provided for @depotKeysUrl.
  ///
  /// In en, this message translates to:
  /// **'Depot keys JSON URL'**
  String get depotKeysUrl;

  /// No description provided for @appTokensUrl.
  ///
  /// In en, this message translates to:
  /// **'App tokens JSON URL'**
  String get appTokensUrl;

  /// No description provided for @sourceUpdateInterval.
  ///
  /// In en, this message translates to:
  /// **'Update interval (hours)'**
  String get sourceUpdateInterval;

  /// No description provided for @sourceEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enable this content source'**
  String get sourceEnabled;

  /// No description provided for @requiredField.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get requiredField;

  /// No description provided for @invalidUrl.
  ///
  /// In en, this message translates to:
  /// **'Enter an HTTP or HTTPS URL'**
  String get invalidUrl;

  /// No description provided for @invalidUpdateInterval.
  ///
  /// In en, this message translates to:
  /// **'Enter a non-negative integer'**
  String get invalidUpdateInterval;

  /// No description provided for @sourceTestSucceeded.
  ///
  /// In en, this message translates to:
  /// **'Test succeeded'**
  String get sourceTestSucceeded;

  /// No description provided for @sourceUpdateComplete.
  ///
  /// In en, this message translates to:
  /// **'Update complete'**
  String get sourceUpdateComplete;

  /// No description provided for @includeDlc.
  ///
  /// In en, this message translates to:
  /// **'Include DLC'**
  String get includeDlc;

  /// No description provided for @pinManifestVersions.
  ///
  /// In en, this message translates to:
  /// **'Pin manifest versions'**
  String get pinManifestVersions;

  /// No description provided for @refreshContentMetadata.
  ///
  /// In en, this message translates to:
  /// **'Refresh depot metadata online'**
  String get refreshContentMetadata;

  /// No description provided for @contentImportNoLuaSource.
  ///
  /// In en, this message translates to:
  /// **'Add or enable a content source that provides Lua first'**
  String get contentImportNoLuaSource;

  /// No description provided for @originalCoverUrl.
  ///
  /// In en, this message translates to:
  /// **'Original cover URL'**
  String get originalCoverUrl;

  /// No description provided for @steamStoreApi.
  ///
  /// In en, this message translates to:
  /// **'Steam Store API'**
  String get steamStoreApi;

  /// No description provided for @heyboxApi.
  ///
  /// In en, this message translates to:
  /// **'Heybox API'**
  String get heyboxApi;

  /// No description provided for @akamaiMain.
  ///
  /// In en, this message translates to:
  /// **'Akamai main'**
  String get akamaiMain;

  /// No description provided for @akamaiBackup.
  ///
  /// In en, this message translates to:
  /// **'Akamai backup'**
  String get akamaiBackup;

  /// No description provided for @cloudflareCdn.
  ///
  /// In en, this message translates to:
  /// **'Cloudflare CDN'**
  String get cloudflareCdn;

  /// No description provided for @akamaiPortrait.
  ///
  /// In en, this message translates to:
  /// **'Akamai portrait'**
  String get akamaiPortrait;

  /// No description provided for @contentImportNoLocalLua.
  ///
  /// In en, this message translates to:
  /// **'No Lua configuration with a valid addappid was found. Manifest files alone cannot add a game.'**
  String get contentImportNoLocalLua;

  /// No description provided for @contentImportPerGame.
  ///
  /// In en, this message translates to:
  /// **'Each game is imported independently. Failed games are listed without undoing successfully imported games.'**
  String get contentImportPerGame;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @tools2.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get tools2;

  /// No description provided for @downloadManageTrainers.
  ///
  /// In en, this message translates to:
  /// **'Download & manage trainers'**
  String get downloadManageTrainers;

  /// No description provided for @addLuaFromAContentSource.
  ///
  /// In en, this message translates to:
  /// **'Add Lua from a content source'**
  String get addLuaFromAContentSource;

  /// No description provided for @accountExtraction.
  ///
  /// In en, this message translates to:
  /// **'Account & extraction'**
  String get accountExtraction;

  /// No description provided for @patchesLicenses.
  ///
  /// In en, this message translates to:
  /// **'Patches & licenses'**
  String get patchesLicenses;

  /// No description provided for @manageAchievements2.
  ///
  /// In en, this message translates to:
  /// **'Manage achievements'**
  String get manageAchievements2;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @showPanel.
  ///
  /// In en, this message translates to:
  /// **'Show panel'**
  String get showPanel;

  /// No description provided for @hidePanel.
  ///
  /// In en, this message translates to:
  /// **'Hide panel'**
  String get hidePanel;

  /// No description provided for @accountExtraction2.
  ///
  /// In en, this message translates to:
  /// **'Account & extraction'**
  String get accountExtraction2;

  /// No description provided for @steamAccount.
  ///
  /// In en, this message translates to:
  /// **'Steam account'**
  String get steamAccount;

  /// No description provided for @accountManagement.
  ///
  /// In en, this message translates to:
  /// **'Account management'**
  String get accountManagement;

  /// No description provided for @steamAccounts.
  ///
  /// In en, this message translates to:
  /// **'Steam accounts'**
  String get steamAccounts;

  /// No description provided for @addSteamAccount.
  ///
  /// In en, this message translates to:
  /// **'Add Steam account'**
  String get addSteamAccount;

  /// No description provided for @addSteamAccountDescription.
  ///
  /// In en, this message translates to:
  /// **'Open Steam\'s own sign-in flow. FlSteamLua never asks for your Steam password.'**
  String get addSteamAccountDescription;

  /// No description provided for @currentSteamAccount.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get currentSteamAccount;

  /// No description provided for @switchSteamAccount.
  ///
  /// In en, this message translates to:
  /// **'Switch account'**
  String get switchSteamAccount;

  /// No description provided for @steamWillRestartToSwitchAccount.
  ///
  /// In en, this message translates to:
  /// **'Steam will restart and switch to this account.'**
  String get steamWillRestartToSwitchAccount;

  /// No description provided for @steamWillOpenItsOwnLogin.
  ///
  /// In en, this message translates to:
  /// **'Steam will open its own sign-in flow. Sign in there, then return and refresh the account list.'**
  String get steamWillOpenItsOwnLogin;

  /// No description provided for @noSteamAccounts.
  ///
  /// In en, this message translates to:
  /// **'No Steam accounts found'**
  String get noSteamAccounts;

  /// No description provided for @noSteamAccountsDescription.
  ///
  /// In en, this message translates to:
  /// **'Start Steam and sign in, then refresh this page.'**
  String get noSteamAccountsDescription;

  /// No description provided for @accountManagerHint.
  ///
  /// In en, this message translates to:
  /// **'Switching accounts restarts Steam. Account credentials stay inside Steam.'**
  String get accountManagerHint;

  /// No description provided for @chooseAFolder.
  ///
  /// In en, this message translates to:
  /// **'Choose a folder'**
  String get chooseAFolder;

  /// No description provided for @chooseTheSteamInstallationFolderContainingSteamExe.
  ///
  /// In en, this message translates to:
  /// **'Choose the Steam installation folder containing steam.exe.'**
  String get chooseTheSteamInstallationFolderContainingSteamExe;

  /// No description provided for @theLuaFolderDoesNotExistChooseAnExistingFolder.
  ///
  /// In en, this message translates to:
  /// **'The Lua folder does not exist. Choose an existing folder.'**
  String get theLuaFolderDoesNotExistChooseAnExistingFolder;

  /// No description provided for @refreshGameLibrary.
  ///
  /// In en, this message translates to:
  /// **'Refresh game library'**
  String get refreshGameLibrary;

  /// No description provided for @pathsSavedAndGameLibraryRefreshed.
  ///
  /// In en, this message translates to:
  /// **'Paths saved and game library refreshed.'**
  String get pathsSavedAndGameLibraryRefreshed;

  /// No description provided for @useOwnerRepositoryForExampleYournameFlsteamlua.
  ///
  /// In en, this message translates to:
  /// **'Use owner/repository, for example yourname/FlSteamLua.'**
  String get useOwnerRepositoryForExampleYournameFlsteamlua;

  /// No description provided for @theFlsteamluaReleaseRepositoryIsNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'The FlSteamLua release repository is not configured.'**
  String get theFlsteamluaReleaseRepositoryIsNotConfigured;

  /// No description provided for @youAreUsingTheLatestPublishedVersion.
  ///
  /// In en, this message translates to:
  /// **'You are using the latest published version.'**
  String get youAreUsingTheLatestPublishedVersion;

  /// No description provided for @noReleaseNotesWereProvided.
  ///
  /// In en, this message translates to:
  /// **'No release notes were provided.'**
  String get noReleaseNotesWereProvided;

  /// No description provided for @later.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get later;

  /// No description provided for @releasePage.
  ///
  /// In en, this message translates to:
  /// **'Release page'**
  String get releasePage;

  /// No description provided for @downloadUpdate.
  ///
  /// In en, this message translates to:
  /// **'Download update'**
  String get downloadUpdate;

  /// No description provided for @downloadApplicationUpdate.
  ///
  /// In en, this message translates to:
  /// **'Download application update'**
  String get downloadApplicationUpdate;

  /// No description provided for @updateDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Update downloaded: {path}'**
  String updateDownloaded(String path);

  /// No description provided for @updateReadyTitle.
  ///
  /// In en, this message translates to:
  /// **'Update ready'**
  String get updateReadyTitle;

  /// No description provided for @updateReadyDescription.
  ///
  /// In en, this message translates to:
  /// **'The download was verified. Close FlSteamLua on the next step and run the installer now?'**
  String get updateReadyDescription;

  /// No description provided for @installUpdateNow.
  ///
  /// In en, this message translates to:
  /// **'Install now'**
  String get installUpdateNow;

  /// No description provided for @openFolder2.
  ///
  /// In en, this message translates to:
  /// **'Open folder'**
  String get openFolder2;

  /// No description provided for @makeYourGameCompanionFeelAtHome.
  ///
  /// In en, this message translates to:
  /// **'Make your game companion feel at home.'**
  String get makeYourGameCompanionFeelAtHome;

  /// No description provided for @steamAndGameFiles.
  ///
  /// In en, this message translates to:
  /// **'Steam and game files'**
  String get steamAndGameFiles;

  /// No description provided for @steamInstallationFolder.
  ///
  /// In en, this message translates to:
  /// **'Steam installation folder'**
  String get steamInstallationFolder;

  /// No description provided for @theFolderContainingSteamExe.
  ///
  /// In en, this message translates to:
  /// **'The folder containing steam.exe'**
  String get theFolderContainingSteamExe;

  /// No description provided for @luaFolder.
  ///
  /// In en, this message translates to:
  /// **'Lua folder'**
  String get luaFolder;

  /// No description provided for @leaveEmptyToUseTheKernelConfigurationOrConfigLua.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to use the kernel configuration or config/stplug-in'**
  String get leaveEmptyToUseTheKernelConfigurationOrConfigLua;

  /// No description provided for @saveAndRefreshLibrary.
  ///
  /// In en, this message translates to:
  /// **'Save and refresh library'**
  String get saveAndRefreshLibrary;

  /// No description provided for @appearanceAndInteraction.
  ///
  /// In en, this message translates to:
  /// **'Appearance and interaction'**
  String get appearanceAndInteraction;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @followTheSystemOrChooseALightOrDarkAppearance.
  ///
  /// In en, this message translates to:
  /// **'Follow the system or choose a light or dark appearance.'**
  String get followTheSystemOrChooseALightOrDarkAppearance;

  /// No description provided for @system.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get system;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// No description provided for @displayLanguage.
  ///
  /// In en, this message translates to:
  /// **'Display language'**
  String get displayLanguage;

  /// No description provided for @appliesImmediatelyWithoutRestarting.
  ///
  /// In en, this message translates to:
  /// **'Applies immediately without restarting.'**
  String get appliesImmediatelyWithoutRestarting;

  /// No description provided for @expandedSidebar.
  ///
  /// In en, this message translates to:
  /// **'Expanded sidebar'**
  String get expandedSidebar;

  /// No description provided for @showDestinationLabelsAlongsideIcons.
  ///
  /// In en, this message translates to:
  /// **'Show destination labels alongside icons.'**
  String get showDestinationLabelsAlongsideIcons;

  /// No description provided for @keepRunningInTheTray.
  ///
  /// In en, this message translates to:
  /// **'Keep running in the tray'**
  String get keepRunningInTheTray;

  /// No description provided for @keepBackgroundTasksRunningQuitFromTheTrayMenu.
  ///
  /// In en, this message translates to:
  /// **'Keep background tasks running; quit from the tray menu.'**
  String get keepBackgroundTasksRunningQuitFromTheTrayMenu;

  /// No description provided for @closeSteamToContinue.
  ///
  /// In en, this message translates to:
  /// **'Close Steam to continue'**
  String get closeSteamToContinue;

  /// No description provided for @closeSteamToContinueDescription.
  ///
  /// In en, this message translates to:
  /// **'This change updates Steam files. Steam and its game processes must be closed before the change can continue.'**
  String get closeSteamToContinueDescription;

  /// No description provided for @closeAndContinue.
  ///
  /// In en, this message translates to:
  /// **'Close and continue'**
  String get closeAndContinue;

  /// No description provided for @steamClient.
  ///
  /// In en, this message translates to:
  /// **'Steam client'**
  String get steamClient;

  /// No description provided for @steamClientRunning.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get steamClientRunning;

  /// No description provided for @steamClientNotRunning.
  ///
  /// In en, this message translates to:
  /// **'Not running'**
  String get steamClientNotRunning;

  /// No description provided for @steamClientChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking...'**
  String get steamClientChecking;

  /// No description provided for @steamUpdateControl.
  ///
  /// In en, this message translates to:
  /// **'Steam update control'**
  String get steamUpdateControl;

  /// No description provided for @steamUpdateControlDescription.
  ///
  /// In en, this message translates to:
  /// **'Manage Steam client update behavior globally.'**
  String get steamUpdateControlDescription;

  /// No description provided for @disableSteamUpdateCheck.
  ///
  /// In en, this message translates to:
  /// **'Disable Steam update checks'**
  String get disableSteamUpdateCheck;

  /// No description provided for @disableSteamForcedUpdate.
  ///
  /// In en, this message translates to:
  /// **'Disable forced Steam updates'**
  String get disableSteamForcedUpdate;

  /// No description provided for @notEnabled.
  ///
  /// In en, this message translates to:
  /// **'Not enabled'**
  String get notEnabled;

  /// No description provided for @startSteam.
  ///
  /// In en, this message translates to:
  /// **'Start Steam'**
  String get startSteam;

  /// No description provided for @stopSteam.
  ///
  /// In en, this message translates to:
  /// **'Close Steam'**
  String get stopSteam;

  /// No description provided for @restartSteam.
  ///
  /// In en, this message translates to:
  /// **'Restart Steam'**
  String get restartSteam;

  /// No description provided for @automaticRefreshUpdateChecksFriendPresenceStartupAndOfflineMode.
  ///
  /// In en, this message translates to:
  /// **'Automatic refresh, update checks, friend presence, startup and offline mode.'**
  String get automaticRefreshUpdateChecksFriendPresenceStartupAndOfflineMode;

  /// No description provided for @downloadsKernelAndAccount.
  ///
  /// In en, this message translates to:
  /// **'Downloads, kernel and account'**
  String get downloadsKernelAndAccount;

  /// No description provided for @manageSubscriptionsScriptsAndTheirLuaManifestIdAndManifestFileCapabilities.
  ///
  /// In en, this message translates to:
  /// **'Manage subscriptions, scripts and their Lua, manifest ID and manifest file capabilities.'**
  String
  get manageSubscriptionsScriptsAndTheirLuaManifestIdAndManifestFileCapabilities;

  /// No description provided for @kernelManager.
  ///
  /// In en, this message translates to:
  /// **'Kernel manager'**
  String get kernelManager;

  /// No description provided for @downloadImportOrSwitchKernelsAndRestoreBackups.
  ///
  /// In en, this message translates to:
  /// **'Download, import or switch kernels and restore backups.'**
  String get downloadImportOrSwitchKernelsAndRestoreBackups;

  /// No description provided for @steamAccountAndExtraction.
  ///
  /// In en, this message translates to:
  /// **'Steam account and extraction'**
  String get steamAccountAndExtraction;

  /// No description provided for @signInVerifySteamGuardAndExtractLicensedContent.
  ///
  /// In en, this message translates to:
  /// **'Sign in, verify Steam Guard and extract licensed content.'**
  String get signInVerifySteamGuardAndExtractLicensedContent;

  /// No description provided for @chooseCoverAndGithubDownloadSourcesAndTestTheirLatency.
  ///
  /// In en, this message translates to:
  /// **'Choose cover and GitHub download sources and test their latency.'**
  String get chooseCoverAndGithubDownloadSourcesAndTestTheirLatency;

  /// No description provided for @applicationUpdates.
  ///
  /// In en, this message translates to:
  /// **'Application updates'**
  String get applicationUpdates;

  /// No description provided for @flsteamluaReleaseRepository.
  ///
  /// In en, this message translates to:
  /// **'FlSteamLua release repository'**
  String get flsteamluaReleaseRepository;

  /// No description provided for @useTheReleaseRepositoryForThisFlutterApplication.
  ///
  /// In en, this message translates to:
  /// **'Use the release repository for this Flutter application.'**
  String get useTheReleaseRepositoryForThisFlutterApplication;

  /// No description provided for @saveRepository.
  ///
  /// In en, this message translates to:
  /// **'Save repository'**
  String get saveRepository;

  /// No description provided for @checkForUpdates.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get checkForUpdates;

  /// No description provided for @viewNewVersion.
  ///
  /// In en, this message translates to:
  /// **'View new version {value1}'**
  String viewNewVersion(String value1);

  /// No description provided for @aboutFlsteamlua.
  ///
  /// In en, this message translates to:
  /// **'About FlSteamLua'**
  String get aboutFlsteamlua;

  /// No description provided for @anOpenSourceDesktopCompanionForYourLibraryAchievementsAndSaves.
  ///
  /// In en, this message translates to:
  /// **'An open-source desktop companion for your library, achievements and saves.'**
  String get anOpenSourceDesktopCompanionForYourLibraryAchievementsAndSaves;

  /// No description provided for @uiComponentsAndMotionAreAdaptedFromFlclashFeaturesAreBasedOnFluentSteamLuaAndReimplem.
  ///
  /// In en, this message translates to:
  /// **'UI components and motion are adapted from FlClash. Features are based on Fluent-Steam-Lua and reimplemented in Flutter and Dart.'**
  String
  get uiComponentsAndMotionAreAdaptedFromFlclashFeaturesAreBasedOnFluentSteamLuaAndReimplem;

  /// No description provided for @openSourceLicenses.
  ///
  /// In en, this message translates to:
  /// **'Open-source licenses'**
  String get openSourceLicenses;

  /// No description provided for @browseFolders.
  ///
  /// In en, this message translates to:
  /// **'Browse folders'**
  String get browseFolders;

  /// No description provided for @stopGame2.
  ///
  /// In en, this message translates to:
  /// **'Stop game'**
  String get stopGame2;

  /// No description provided for @updateSubscriptionCaches.
  ///
  /// In en, this message translates to:
  /// **'Update subscription caches'**
  String get updateSubscriptionCaches;

  /// No description provided for @refreshLibrary.
  ///
  /// In en, this message translates to:
  /// **'Refresh library'**
  String get refreshLibrary;

  /// No description provided for @enabled3.
  ///
  /// In en, this message translates to:
  /// **'{enabledLua} enabled'**
  String enabled3(String enabledLua);

  /// No description provided for @manageLua.
  ///
  /// In en, this message translates to:
  /// **'Manage Lua'**
  String get manageLua;

  /// No description provided for @steamLibrary.
  ///
  /// In en, this message translates to:
  /// **'Steam library'**
  String get steamLibrary;

  /// No description provided for @running2.
  ///
  /// In en, this message translates to:
  /// **'{runningCount} running'**
  String running2(String runningCount);

  /// No description provided for @steamIsNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Steam is not connected'**
  String get steamIsNotConnected;

  /// No description provided for @openLibrary.
  ///
  /// In en, this message translates to:
  /// **'Open library'**
  String get openLibrary;

  /// No description provided for @kernel.
  ///
  /// In en, this message translates to:
  /// **'Kernel'**
  String get kernel;

  /// No description provided for @couldNotReadKernel.
  ///
  /// In en, this message translates to:
  /// **'Could not read kernel'**
  String get couldNotReadKernel;

  /// No description provided for @detectingKernel.
  ///
  /// In en, this message translates to:
  /// **'Detecting kernel'**
  String get detectingKernel;

  /// No description provided for @notInstalled.
  ///
  /// In en, this message translates to:
  /// **'Not installed'**
  String get notInstalled;

  /// No description provided for @manageKernel.
  ///
  /// In en, this message translates to:
  /// **'Manage kernel'**
  String get manageKernel;

  /// No description provided for @enabled4.
  ///
  /// In en, this message translates to:
  /// **'{enabledSources} enabled'**
  String enabled4(String enabledSources);

  /// No description provided for @someSourcesNeedConfigurationOrTesting.
  ///
  /// In en, this message translates to:
  /// **'Some sources need configuration or testing'**
  String get someSourcesNeedConfigurationOrTesting;

  /// No description provided for @manageSources.
  ///
  /// In en, this message translates to:
  /// **'Manage sources'**
  String get manageSources;

  /// No description provided for @updateCaches.
  ///
  /// In en, this message translates to:
  /// **'Update caches'**
  String get updateCaches;

  /// No description provided for @running3.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get running3;

  /// No description provided for @viewTasks.
  ///
  /// In en, this message translates to:
  /// **'View tasks'**
  String get viewTasks;

  /// No description provided for @activeTasks.
  ///
  /// In en, this message translates to:
  /// **'Active tasks'**
  String get activeTasks;

  /// No description provided for @continuePlaying.
  ///
  /// In en, this message translates to:
  /// **'Continue playing'**
  String get continuePlaying;

  /// No description provided for @allGames.
  ///
  /// In en, this message translates to:
  /// **'All games'**
  String get allGames;

  /// No description provided for @cancelling2.
  ///
  /// In en, this message translates to:
  /// **'Cancelling'**
  String get cancelling2;

  /// No description provided for @cancelTask.
  ///
  /// In en, this message translates to:
  /// **'Cancel task'**
  String get cancelTask;

  /// No description provided for @enterAValidAppid3.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid AppID.'**
  String get enterAValidAppid3;

  /// No description provided for @dlcAnalysis2.
  ///
  /// In en, this message translates to:
  /// **'DLC management: {appId}'**
  String dlcAnalysis2(String appId);

  /// No description provided for @dlcDepotStructure.
  ///
  /// In en, this message translates to:
  /// **'DLC depot structure'**
  String get dlcDepotStructure;

  /// No description provided for @allDlcStructures.
  ///
  /// In en, this message translates to:
  /// **'All structures'**
  String get allDlcStructures;

  /// No description provided for @confirmDlcAdditions.
  ///
  /// In en, this message translates to:
  /// **'Confirm DLC additions'**
  String get confirmDlcAdditions;

  /// No description provided for @theExistingLuaWillBeBackedUpOnlyTheSelectedLinesBelowAreAppendedExistingScriptsKeysAn.
  ///
  /// In en, this message translates to:
  /// **'The existing Lua will be backed up. Only the selected lines below are appended; existing scripts, keys and manifest pins are preserved. This does not establish Steam account ownership.'**
  String
  get theExistingLuaWillBeBackedUpOnlyTheSelectedLinesBelowAreAppendedExistingScriptsKeysAn;

  /// No description provided for @backUpAndAppend.
  ///
  /// In en, this message translates to:
  /// **'Back up and append'**
  String get backUpAndAppend;

  /// No description provided for @saveDlcSuggestions.
  ///
  /// In en, this message translates to:
  /// **'Save DLC suggestions: {appId}'**
  String saveDlcSuggestions(String appId);

  /// No description provided for @appendedLinesAnalyzeAgainToVerifyTheCurrentConfiguration.
  ///
  /// In en, this message translates to:
  /// **'Appended {count} lines. Analyze again to verify the current configuration.'**
  String appendedLinesAnalyzeAgainToVerifyTheCurrentConfiguration(String count);

  /// No description provided for @queryFailedUnknown.
  ///
  /// In en, this message translates to:
  /// **'Query failed / unknown'**
  String get queryFailedUnknown;

  /// No description provided for @noIndependentDepot.
  ///
  /// In en, this message translates to:
  /// **'No independent depot'**
  String get noIndependentDepot;

  /// No description provided for @singleDepot.
  ///
  /// In en, this message translates to:
  /// **'Single depot'**
  String get singleDepot;

  /// No description provided for @multipleDepots.
  ///
  /// In en, this message translates to:
  /// **'Multiple depots'**
  String get multipleDepots;

  /// No description provided for @inTheMainGame.
  ///
  /// In en, this message translates to:
  /// **'In the main game'**
  String get inTheMainGame;

  /// No description provided for @compareSteamDepotMetadataWithTheCurrentLuaAndTheContentSourceSelectedForThisAnalysisP.
  ///
  /// In en, this message translates to:
  /// **'Compare Steam depot metadata with the current Lua and the content source selected for this analysis. Preview the DLC configuration before appending.'**
  String
  get compareSteamDepotMetadataWithTheCurrentLuaAndTheContentSourceSelectedForThisAnalysisP;

  /// No description provided for @contentSourceOptional.
  ///
  /// In en, this message translates to:
  /// **'Content source (optional)'**
  String get contentSourceOptional;

  /// No description provided for @doNotUseAContentSourceCache.
  ///
  /// In en, this message translates to:
  /// **'Do not use a content source cache'**
  String get doNotUseAContentSourceCache;

  /// No description provided for @contentSourceSubscriptionOptional.
  ///
  /// In en, this message translates to:
  /// **'Content-source subscription (optional)'**
  String get contentSourceSubscriptionOptional;

  /// No description provided for @doNotUseASubscriptionCache.
  ///
  /// In en, this message translates to:
  /// **'Do not use a subscription cache'**
  String get doNotUseASubscriptionCache;

  /// No description provided for @existingLuaFile.
  ///
  /// In en, this message translates to:
  /// **'Existing Lua file'**
  String get existingLuaFile;

  /// No description provided for @leaveEmptyToSearchTheConfiguredLuaFolderOrSelectADisabledLuaFile.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to search the configured Lua folder, or select a disabled Lua file.'**
  String get leaveEmptyToSearchTheConfiguredLuaFolderOrSelectADisabledLuaFile;

  /// No description provided for @chooseLua.
  ///
  /// In en, this message translates to:
  /// **'Choose Lua'**
  String get chooseLua;

  /// No description provided for @analyzeDlc.
  ///
  /// In en, this message translates to:
  /// **'Refresh DLC'**
  String get analyzeDlc;

  /// No description provided for @previewDlcChanges.
  ///
  /// In en, this message translates to:
  /// **'Preview Lua changes'**
  String get previewDlcChanges;

  /// No description provided for @mainDepotsDlcReferencedByLuaLuaConfigurationIsNotAccountOwnership.
  ///
  /// In en, this message translates to:
  /// **'{mainDepotCount} main depots · {value2} DLC referenced by Lua. Lua configuration is not account ownership.'**
  String mainDepotsDlcReferencedByLuaLuaConfigurationIsNotAccountOwnership(
    String mainDepotCount,
    String value2,
  );

  /// No description provided for @allLayouts.
  ///
  /// In en, this message translates to:
  /// **'All layouts'**
  String get allLayouts;

  /// No description provided for @steamReturnedNoDlcForThisGame.
  ///
  /// In en, this message translates to:
  /// **'Steam returned no DLC for this game.'**
  String get steamReturnedNoDlcForThisGame;

  /// No description provided for @referenced.
  ///
  /// In en, this message translates to:
  /// **'referenced'**
  String get referenced;

  /// No description provided for @notConfigured.
  ///
  /// In en, this message translates to:
  /// **'not configured'**
  String get notConfigured;

  /// No description provided for @luaSuggestedLines.
  ///
  /// In en, this message translates to:
  /// **'Lua {value1} · {suggestionsCount} suggested lines'**
  String luaSuggestedLines(String value1, String suggestionsCount);

  /// No description provided for @missingKeysSkipped.
  ///
  /// In en, this message translates to:
  /// **'Missing keys, skipped: {join}'**
  String missingKeysSkipped(String join);

  /// No description provided for @selectedAdditions.
  ///
  /// In en, this message translates to:
  /// **'Selected additions'**
  String get selectedAdditions;

  /// No description provided for @noLinesSelected.
  ///
  /// In en, this message translates to:
  /// **'No lines selected.'**
  String get noLinesSelected;

  /// No description provided for @copySuggestions.
  ///
  /// In en, this message translates to:
  /// **'Copy suggestions'**
  String get copySuggestions;

  /// No description provided for @previewAndAppendToLua.
  ///
  /// In en, this message translates to:
  /// **'Preview and append to Lua'**
  String get previewAndAppendToLua;

  /// No description provided for @free.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get free;

  /// No description provided for @pinWindow.
  ///
  /// In en, this message translates to:
  /// **'Pin window'**
  String get pinWindow;

  /// No description provided for @unpinWindow.
  ///
  /// In en, this message translates to:
  /// **'Unpin window'**
  String get unpinWindow;

  /// No description provided for @minimizeWindow.
  ///
  /// In en, this message translates to:
  /// **'Minimize'**
  String get minimizeWindow;

  /// No description provided for @maximizeWindow.
  ///
  /// In en, this message translates to:
  /// **'Maximize'**
  String get maximizeWindow;

  /// No description provided for @restoreWindow.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restoreWindow;

  /// No description provided for @closeWindow.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get closeWindow;

  /// No description provided for @layout.
  ///
  /// In en, this message translates to:
  /// **'Layout'**
  String get layout;

  /// No description provided for @comfortable.
  ///
  /// In en, this message translates to:
  /// **'Comfortable'**
  String get comfortable;

  /// No description provided for @standard.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get standard;

  /// No description provided for @compact.
  ///
  /// In en, this message translates to:
  /// **'Compact'**
  String get compact;

  /// No description provided for @themeMode.
  ///
  /// In en, this message translates to:
  /// **'Theme mode'**
  String get themeMode;

  /// No description provided for @themeColor.
  ///
  /// In en, this message translates to:
  /// **'Theme color'**
  String get themeColor;

  /// No description provided for @pureBlackMode.
  ///
  /// In en, this message translates to:
  /// **'Pure black mode'**
  String get pureBlackMode;

  /// No description provided for @pureBlack.
  ///
  /// In en, this message translates to:
  /// **'Pure black'**
  String get pureBlack;

  /// No description provided for @colorStyle.
  ///
  /// In en, this message translates to:
  /// **'Palette style'**
  String get colorStyle;

  /// No description provided for @vivid.
  ///
  /// In en, this message translates to:
  /// **'Vivid'**
  String get vivid;

  /// No description provided for @tinted.
  ///
  /// In en, this message translates to:
  /// **'Tinted'**
  String get tinted;

  /// No description provided for @soft.
  ///
  /// In en, this message translates to:
  /// **'Soft'**
  String get soft;

  /// No description provided for @monochrome.
  ///
  /// In en, this message translates to:
  /// **'Monochrome'**
  String get monochrome;

  /// No description provided for @navigationBarStyle.
  ///
  /// In en, this message translates to:
  /// **'Sidebar style'**
  String get navigationBarStyle;

  /// No description provided for @floating.
  ///
  /// In en, this message translates to:
  /// **'Floating'**
  String get floating;

  /// No description provided for @docked.
  ///
  /// In en, this message translates to:
  /// **'Docked'**
  String get docked;

  /// No description provided for @tabAnimation.
  ///
  /// In en, this message translates to:
  /// **'Page transition'**
  String get tabAnimation;

  /// No description provided for @slide.
  ///
  /// In en, this message translates to:
  /// **'Slide'**
  String get slide;

  /// No description provided for @fade.
  ///
  /// In en, this message translates to:
  /// **'Fade'**
  String get fade;

  /// No description provided for @liquidGlass.
  ///
  /// In en, this message translates to:
  /// **'Liquid glass'**
  String get liquidGlass;

  /// No description provided for @none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get none;

  /// No description provided for @ultra.
  ///
  /// In en, this message translates to:
  /// **'Ultra'**
  String get ultra;

  /// No description provided for @sidebar.
  ///
  /// In en, this message translates to:
  /// **'Sidebar'**
  String get sidebar;

  /// No description provided for @backgroundBlur.
  ///
  /// In en, this message translates to:
  /// **'Background blur'**
  String get backgroundBlur;

  /// No description provided for @sidebarBlurDesc.
  ///
  /// In en, this message translates to:
  /// **'Blur the desktop behind a floating sidebar.'**
  String get sidebarBlurDesc;

  /// No description provided for @fontFamily.
  ///
  /// In en, this message translates to:
  /// **'Font'**
  String get fontFamily;

  /// No description provided for @defaultText.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get defaultText;

  /// No description provided for @textScale.
  ///
  /// In en, this message translates to:
  /// **'Text scale'**
  String get textScale;

  /// No description provided for @followSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get followSystem;

  /// No description provided for @custom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get custom;

  /// No description provided for @textScalePreview.
  ///
  /// In en, this message translates to:
  /// **'Text in the app will use this size.'**
  String get textScalePreview;

  /// No description provided for @customColor.
  ///
  /// In en, this message translates to:
  /// **'Custom color'**
  String get customColor;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @resetTip.
  ///
  /// In en, this message translates to:
  /// **'Restore the default FlClash-style appearance?'**
  String get resetTip;

  /// No description provided for @backgroundStyle.
  ///
  /// In en, this message translates to:
  /// **'Background style'**
  String get backgroundStyle;

  /// No description provided for @grid.
  ///
  /// In en, this message translates to:
  /// **'Grid'**
  String get grid;

  /// No description provided for @spectrum.
  ///
  /// In en, this message translates to:
  /// **'Spectrum'**
  String get spectrum;

  /// No description provided for @sliders.
  ///
  /// In en, this message translates to:
  /// **'Sliders'**
  String get sliders;

  /// No description provided for @hue.
  ///
  /// In en, this message translates to:
  /// **'Hue'**
  String get hue;

  /// No description provided for @saturation.
  ///
  /// In en, this message translates to:
  /// **'Saturation'**
  String get saturation;

  /// No description provided for @brightness.
  ///
  /// In en, this message translates to:
  /// **'Brightness'**
  String get brightness;

  /// No description provided for @hex.
  ///
  /// In en, this message translates to:
  /// **'Hex'**
  String get hex;

  /// No description provided for @color.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get color;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @installedFonts.
  ///
  /// In en, this message translates to:
  /// **'Installed fonts'**
  String get installedFonts;

  /// No description provided for @deleteColorTip.
  ///
  /// In en, this message translates to:
  /// **'Delete this custom color?'**
  String get deleteColorTip;

  /// No description provided for @general.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get general;

  /// No description provided for @other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get other;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @auto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get auto;

  /// No description provided for @tip.
  ///
  /// In en, this message translates to:
  /// **'Tip'**
  String get tip;

  /// No description provided for @basicInfo.
  ///
  /// In en, this message translates to:
  /// **'Basic information'**
  String get basicInfo;

  /// No description provided for @cloudConnection.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get cloudConnection;

  /// No description provided for @credentials.
  ///
  /// In en, this message translates to:
  /// **'Credentials'**
  String get credentials;

  /// No description provided for @advanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get advanced;

  /// No description provided for @url.
  ///
  /// In en, this message translates to:
  /// **'URL'**
  String get url;

  /// No description provided for @endpoint.
  ///
  /// In en, this message translates to:
  /// **'Endpoint'**
  String get endpoint;

  /// No description provided for @region.
  ///
  /// In en, this message translates to:
  /// **'Region'**
  String get region;

  /// No description provided for @bucket.
  ///
  /// In en, this message translates to:
  /// **'Bucket'**
  String get bucket;

  /// No description provided for @accountId.
  ///
  /// In en, this message translates to:
  /// **'Account ID'**
  String get accountId;

  /// No description provided for @accessKeyId.
  ///
  /// In en, this message translates to:
  /// **'Access key ID'**
  String get accessKeyId;

  /// No description provided for @secretAccessKey.
  ///
  /// In en, this message translates to:
  /// **'Secret access key'**
  String get secretAccessKey;

  /// No description provided for @keyPrefix.
  ///
  /// In en, this message translates to:
  /// **'Key prefix'**
  String get keyPrefix;

  /// No description provided for @extraHeaders.
  ///
  /// In en, this message translates to:
  /// **'Extra headers'**
  String get extraHeaders;

  /// No description provided for @timeoutSeconds.
  ///
  /// In en, this message translates to:
  /// **'Timeout (seconds)'**
  String get timeoutSeconds;

  /// No description provided for @optional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get optional;

  /// No description provided for @showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// No description provided for @sourceDefinitionNotFound.
  ///
  /// In en, this message translates to:
  /// **'Source definition not found: {sourceId}'**
  String sourceDefinitionNotFound(Object sourceId);

  /// No description provided for @kernelOverview.
  ///
  /// In en, this message translates to:
  /// **'Kernel overview'**
  String get kernelOverview;

  /// No description provided for @kernelStateHealthy.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get kernelStateHealthy;

  /// No description provided for @kernelStateDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get kernelStateDisabled;

  /// No description provided for @kernelStateMissingEntry.
  ///
  /// In en, this message translates to:
  /// **'Injection entry missing'**
  String get kernelStateMissingEntry;

  /// No description provided for @kernelStateConflict.
  ///
  /// In en, this message translates to:
  /// **'Injection entry conflict'**
  String get kernelStateConflict;

  /// No description provided for @kernelStateNotInstalled.
  ///
  /// In en, this message translates to:
  /// **'Not installed'**
  String get kernelStateNotInstalled;

  /// No description provided for @kernelVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get kernelVersion;

  /// No description provided for @kernelUpdateAvailable.
  ///
  /// In en, this message translates to:
  /// **'Version {version} is available'**
  String kernelUpdateAvailable(Object version);

  /// No description provided for @kernelUpToDate.
  ///
  /// In en, this message translates to:
  /// **'Up to date'**
  String get kernelUpToDate;

  /// No description provided for @checkKernelUpdate.
  ///
  /// In en, this message translates to:
  /// **'Check for kernel updates'**
  String get checkKernelUpdate;

  /// No description provided for @installOrUpdateKernel.
  ///
  /// In en, this message translates to:
  /// **'Install or update kernel'**
  String get installOrUpdateKernel;

  /// No description provided for @installAndRuntime.
  ///
  /// In en, this message translates to:
  /// **'Install and runtime'**
  String get installAndRuntime;

  /// No description provided for @repositorySubscription.
  ///
  /// In en, this message translates to:
  /// **'Repository subscription'**
  String get repositorySubscription;

  /// No description provided for @localKernelPackage.
  ///
  /// In en, this message translates to:
  /// **'Local kernel package'**
  String get localKernelPackage;

  /// No description provided for @kernelRepository.
  ///
  /// In en, this message translates to:
  /// **'Kernel repository'**
  String get kernelRepository;

  /// No description provided for @kernelRepositoryHint.
  ///
  /// In en, this message translates to:
  /// **'owner/repository or a GitHub repository URL'**
  String get kernelRepositoryHint;

  /// No description provided for @repositoryMainline.
  ///
  /// In en, this message translates to:
  /// **'Mainline repository'**
  String get repositoryMainline;

  /// No description provided for @repositoryFork.
  ///
  /// In en, this message translates to:
  /// **'Fork'**
  String get repositoryFork;

  /// No description provided for @defaultBranch.
  ///
  /// In en, this message translates to:
  /// **'Default branch'**
  String get defaultBranch;

  /// No description provided for @lastPush.
  ///
  /// In en, this message translates to:
  /// **'Last push'**
  String get lastPush;

  /// No description provided for @kernelLocalNoUpdates.
  ///
  /// In en, this message translates to:
  /// **'Local kernel packages do not check for updates'**
  String get kernelLocalNoUpdates;

  /// No description provided for @releaseAnnouncement.
  ///
  /// In en, this message translates to:
  /// **'Release notes'**
  String get releaseAnnouncement;

  /// No description provided for @manifestSettings.
  ///
  /// In en, this message translates to:
  /// **'Manifest settings'**
  String get manifestSettings;

  /// No description provided for @manifestProvider.
  ///
  /// In en, this message translates to:
  /// **'Manifest provider'**
  String get manifestProvider;

  /// No description provided for @manifestModeBuiltIn.
  ///
  /// In en, this message translates to:
  /// **'Built-in provider'**
  String get manifestModeBuiltIn;

  /// No description provided for @manifestModeCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom server'**
  String get manifestModeCustom;

  /// No description provided for @manifestModeLocalProxy.
  ///
  /// In en, this message translates to:
  /// **'Local proxy'**
  String get manifestModeLocalProxy;

  /// No description provided for @manifestUrlTemplate.
  ///
  /// In en, this message translates to:
  /// **'Manifest URL template'**
  String get manifestUrlTemplate;

  /// No description provided for @manifestHeader.
  ///
  /// In en, this message translates to:
  /// **'Request header'**
  String get manifestHeader;

  /// No description provided for @manifestFormat.
  ///
  /// In en, this message translates to:
  /// **'Response format'**
  String get manifestFormat;

  /// No description provided for @manifestFailover.
  ///
  /// In en, this message translates to:
  /// **'Fail over between providers'**
  String get manifestFailover;

  /// No description provided for @manifestRequestCodes.
  ///
  /// In en, this message translates to:
  /// **'Manifest request codes'**
  String get manifestRequestCodes;

  /// No description provided for @noManifestCodeSources.
  ///
  /// In en, this message translates to:
  /// **'No enabled content source can provide manifest request codes'**
  String get noManifestCodeSources;

  /// No description provided for @selectAtLeastOneManifestCodeSource.
  ///
  /// In en, this message translates to:
  /// **'Select at least one manifest request-code source'**
  String get selectAtLeastOneManifestCodeSource;

  /// No description provided for @manifestLocalProxyDescription.
  ///
  /// In en, this message translates to:
  /// **'Run a loopback server that resolves the selected content sources and returns a plain manifest request code to the kernel.'**
  String get manifestLocalProxyDescription;

  /// No description provided for @manifestCustomHint.
  ///
  /// In en, this message translates to:
  /// **'Use depotId and gid placeholders in the URL'**
  String get manifestCustomHint;

  /// No description provided for @steamClientDataChannel.
  ///
  /// In en, this message translates to:
  /// **'Steam client data channel'**
  String get steamClientDataChannel;

  /// No description provided for @channelRepository.
  ///
  /// In en, this message translates to:
  /// **'Data repository'**
  String get channelRepository;

  /// No description provided for @channelName.
  ///
  /// In en, this message translates to:
  /// **'Channel'**
  String get channelName;

  /// No description provided for @channelFormat.
  ///
  /// In en, this message translates to:
  /// **'Repository format'**
  String get channelFormat;

  /// No description provided for @channelFormatBranch.
  ///
  /// In en, this message translates to:
  /// **'Branch format'**
  String get channelFormatBranch;

  /// No description provided for @channelFormatDirectory.
  ///
  /// In en, this message translates to:
  /// **'Directory format'**
  String get channelFormatDirectory;

  /// No description provided for @defaultRepository.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get defaultRepository;

  /// No description provided for @customRepository.
  ///
  /// In en, this message translates to:
  /// **'Custom repository'**
  String get customRepository;

  /// No description provided for @localTemporaryBuild.
  ///
  /// In en, this message translates to:
  /// **'Local emergency build'**
  String get localTemporaryBuild;

  /// No description provided for @localTemporaryBuildDescription.
  ///
  /// In en, this message translates to:
  /// **'Use only after a Steam update when every online data channel is unavailable. The generated files apply only to the current Steam client build.'**
  String get localTemporaryBuildDescription;

  /// No description provided for @localBuildTitle.
  ///
  /// In en, this message translates to:
  /// **'Local emergency build'**
  String get localBuildTitle;

  /// No description provided for @localBuildIdleDescription.
  ///
  /// In en, this message translates to:
  /// **'Read the installed Steam DLLs and generate temporary signature files for this exact Steam build.'**
  String get localBuildIdleDescription;

  /// No description provided for @localBuildSteamDlls.
  ///
  /// In en, this message translates to:
  /// **'Steam DLLs'**
  String get localBuildSteamDlls;

  /// No description provided for @localBuildDllLocated.
  ///
  /// In en, this message translates to:
  /// **'{name} · {size} · {path}'**
  String localBuildDllLocated(String name, String size, String path);

  /// No description provided for @localBuildHashComputed.
  ///
  /// In en, this message translates to:
  /// **'{name} SHA256 · {sha}'**
  String localBuildHashComputed(String name, String sha);

  /// No description provided for @localBuildPatternScan.
  ///
  /// In en, this message translates to:
  /// **'Resolving {component} hooks'**
  String localBuildPatternScan(String component);

  /// No description provided for @localBuildHookResolved.
  ///
  /// In en, this message translates to:
  /// **'{name} → {rva} · {bytes} byte signature'**
  String localBuildHookResolved(String name, String rva, String bytes);

  /// No description provided for @localBuildHookMissing.
  ///
  /// In en, this message translates to:
  /// **'{name} · no unique match'**
  String localBuildHookMissing(String name);

  /// No description provided for @localBuildComponentWritten.
  ///
  /// In en, this message translates to:
  /// **'{component} · {resolved}/{total} written'**
  String localBuildComponentWritten(
    String component,
    String resolved,
    String total,
  );

  /// No description provided for @localBuildComponentRejected.
  ///
  /// In en, this message translates to:
  /// **'{component} · {resolved}/{total}; existing file was not overwritten'**
  String localBuildComponentRejected(
    String component,
    String resolved,
    String total,
  );

  /// No description provided for @localBuildIpcWrapper.
  ///
  /// In en, this message translates to:
  /// **'{name} · wrapper {rva}'**
  String localBuildIpcWrapper(String name, String rva);

  /// No description provided for @localBuildIpcVtable.
  ///
  /// In en, this message translates to:
  /// **'{name} · vtable {rva}'**
  String localBuildIpcVtable(String name, String rva);

  /// No description provided for @localBuildCompleted.
  ///
  /// In en, this message translates to:
  /// **'{written}/{total} files written'**
  String localBuildCompleted(String written, String total);

  /// No description provided for @localBuildStart.
  ///
  /// In en, this message translates to:
  /// **'Start build'**
  String get localBuildStart;

  /// No description provided for @localBuildRestart.
  ///
  /// In en, this message translates to:
  /// **'Build again'**
  String get localBuildRestart;

  /// No description provided for @localBuildLog.
  ///
  /// In en, this message translates to:
  /// **'Build log'**
  String get localBuildLog;

  /// No description provided for @localBuildCloseSteam.
  ///
  /// In en, this message translates to:
  /// **'Close Steam before starting the local build.'**
  String get localBuildCloseSteam;

  /// No description provided for @kernelEntryDwmapiDescription.
  ///
  /// In en, this message translates to:
  /// **'Best compatibility and the recommended daily entry'**
  String get kernelEntryDwmapiDescription;

  /// No description provided for @kernelEntryVersionDescription.
  ///
  /// In en, this message translates to:
  /// **'Useful when a first-load isolation entry is required'**
  String get kernelEntryVersionDescription;

  /// No description provided for @kernelActions.
  ///
  /// In en, this message translates to:
  /// **'Kernel actions'**
  String get kernelActions;

  /// No description provided for @kernelResidualScan.
  ///
  /// In en, this message translates to:
  /// **'Scan kernel residuals'**
  String get kernelResidualScan;

  /// No description provided for @kernelResidualScanDescription.
  ///
  /// In en, this message translates to:
  /// **'Read-only scan of known kernel files and folders; clean only after confirmation'**
  String get kernelResidualScanDescription;

  /// No description provided for @kernelUpdateCheckOnStartup.
  ///
  /// In en, this message translates to:
  /// **'Check for kernel updates at startup'**
  String get kernelUpdateCheckOnStartup;

  /// No description provided for @kernelUpdateCheckOnStartupDescription.
  ///
  /// In en, this message translates to:
  /// **'Show when the installed kernel has a newer official release'**
  String get kernelUpdateCheckOnStartupDescription;

  /// No description provided for @kernelLatest.
  ///
  /// In en, this message translates to:
  /// **'Latest'**
  String get kernelLatest;

  /// No description provided for @kernelScanTitle.
  ///
  /// In en, this message translates to:
  /// **'Kernel residuals'**
  String get kernelScanTitle;

  /// No description provided for @kernelScanSummary.
  ///
  /// In en, this message translates to:
  /// **'{count} items found, {cleanable} cleanable, {size}'**
  String kernelScanSummary(Object cleanable, Object count, Object size);

  /// No description provided for @kernelResidualOpenSteamTool.
  ///
  /// In en, this message translates to:
  /// **'OpenSteamTool'**
  String get kernelResidualOpenSteamTool;

  /// No description provided for @kernelResidualOpenSteamToolDescription.
  ///
  /// In en, this message translates to:
  /// **'OpenSteamTool core files, configuration, or cached data'**
  String get kernelResidualOpenSteamToolDescription;

  /// No description provided for @kernelResidualSteamTools.
  ///
  /// In en, this message translates to:
  /// **'SteamTools'**
  String get kernelResidualSteamTools;

  /// No description provided for @kernelResidualSteamToolsDescription.
  ///
  /// In en, this message translates to:
  /// **'SteamTools injection DLLs or plugin data'**
  String get kernelResidualSteamToolsDescription;

  /// No description provided for @kernelResidualTbBiao.
  ///
  /// In en, this message translates to:
  /// **'TB / BIAO'**
  String get kernelResidualTbBiao;

  /// No description provided for @kernelResidualTbBiaoDescription.
  ///
  /// In en, this message translates to:
  /// **'TB/BIAO or GreenLuma injection files'**
  String get kernelResidualTbBiaoDescription;

  /// No description provided for @kernelResidualSteamConfig.
  ///
  /// In en, this message translates to:
  /// **'Steam configuration'**
  String get kernelResidualSteamConfig;

  /// No description provided for @kernelResidualSteamConfigDescription.
  ///
  /// In en, this message translates to:
  /// **'Steam settings that may disable updates or change startup behavior'**
  String get kernelResidualSteamConfigDescription;

  /// No description provided for @kernelResidualInfo.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get kernelResidualInfo;

  /// No description provided for @kernelResidualWarning.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get kernelResidualWarning;

  /// No description provided for @kernelResidualHigh.
  ///
  /// In en, this message translates to:
  /// **'High risk'**
  String get kernelResidualHigh;

  /// No description provided for @kernelResidualCanClean.
  ///
  /// In en, this message translates to:
  /// **'Cleanable'**
  String get kernelResidualCanClean;

  /// No description provided for @kernelResidualReportOnly.
  ///
  /// In en, this message translates to:
  /// **'Report only'**
  String get kernelResidualReportOnly;

  /// No description provided for @kernelResidualDirectory.
  ///
  /// In en, this message translates to:
  /// **'Folder'**
  String get kernelResidualDirectory;

  /// No description provided for @kernelResidualFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get kernelResidualFile;

  /// No description provided for @kernelResidualBackupAndClean.
  ///
  /// In en, this message translates to:
  /// **'Back up and clean'**
  String get kernelResidualBackupAndClean;

  /// No description provided for @kernelResidualRescan.
  ///
  /// In en, this message translates to:
  /// **'Rescan'**
  String get kernelResidualRescan;

  /// No description provided for @kernelResidualNoResults.
  ///
  /// In en, this message translates to:
  /// **'No known kernel residuals were found'**
  String get kernelResidualNoResults;

  /// No description provided for @kernelResidualSelectCleanable.
  ///
  /// In en, this message translates to:
  /// **'Select cleanable items'**
  String get kernelResidualSelectCleanable;

  /// No description provided for @kernelResidualCleanupCompleted.
  ///
  /// In en, this message translates to:
  /// **'Backed up and removed {count} residual items'**
  String kernelResidualCleanupCompleted(Object count);

  /// No description provided for @kernelResidualCleanupPartial.
  ///
  /// In en, this message translates to:
  /// **'Removed {deleted}; {failed} failed'**
  String kernelResidualCleanupPartial(Object deleted, Object failed);

  /// No description provided for @kernelTomlPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Fetch Steam signatures'**
  String get kernelTomlPreviewTitle;

  /// No description provided for @kernelBuildId.
  ///
  /// In en, this message translates to:
  /// **'Build ID'**
  String get kernelBuildId;

  /// No description provided for @kernelClientSha.
  ///
  /// In en, this message translates to:
  /// **'steamclient64 SHA256'**
  String get kernelClientSha;

  /// No description provided for @kernelUiSha.
  ///
  /// In en, this message translates to:
  /// **'steamui SHA256'**
  String get kernelUiSha;

  /// No description provided for @kernelTomlFiles.
  ///
  /// In en, this message translates to:
  /// **'Signatures to fetch'**
  String get kernelTomlFiles;

  /// No description provided for @kernelStartFetch.
  ///
  /// In en, this message translates to:
  /// **'Start fetching'**
  String get kernelStartFetch;

  /// No description provided for @kernelTomlResults.
  ///
  /// In en, this message translates to:
  /// **'Signature results'**
  String get kernelTomlResults;

  /// No description provided for @kernelTomlReady.
  ///
  /// In en, this message translates to:
  /// **'Fetched'**
  String get kernelTomlReady;

  /// No description provided for @kernelTomlNoUpstream.
  ///
  /// In en, this message translates to:
  /// **'Not published upstream'**
  String get kernelTomlNoUpstream;

  /// No description provided for @kernelTomlFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get kernelTomlFailed;

  /// No description provided for @kernelNoUpdate.
  ///
  /// In en, this message translates to:
  /// **'No update is available'**
  String get kernelNoUpdate;

  /// No description provided for @injectionEntry.
  ///
  /// In en, this message translates to:
  /// **'Injection entry'**
  String get injectionEntry;

  /// No description provided for @selectAnOutputFolder.
  ///
  /// In en, this message translates to:
  /// **'Choose an output folder.'**
  String get selectAnOutputFolder;

  /// No description provided for @chooseFilesToConvert.
  ///
  /// In en, this message translates to:
  /// **'Choose at least one file to convert.'**
  String get chooseFilesToConvert;

  /// No description provided for @noSupportedFilesFound.
  ///
  /// In en, this message translates to:
  /// **'No supported Lua, VDF or ACF files were found.'**
  String get noSupportedFilesFound;

  /// No description provided for @convertedFileCount.
  ///
  /// In en, this message translates to:
  /// **'Converted {count} files.'**
  String convertedFileCount(String count);

  /// No description provided for @conversionOptions.
  ///
  /// In en, this message translates to:
  /// **'Conversion options'**
  String get conversionOptions;

  /// No description provided for @fileCount.
  ///
  /// In en, this message translates to:
  /// **'{count} files selected'**
  String fileCount(String count);

  /// No description provided for @noFilesSelected.
  ///
  /// In en, this message translates to:
  /// **'No files selected'**
  String get noFilesSelected;

  /// No description provided for @chooseLuaVdfOrAcfFiles.
  ///
  /// In en, this message translates to:
  /// **'Choose Lua, VDF or ACF files. Existing output files are never overwritten.'**
  String get chooseLuaVdfOrAcfFiles;

  /// No description provided for @chooseFiles.
  ///
  /// In en, this message translates to:
  /// **'Choose files'**
  String get chooseFiles;

  /// No description provided for @notSelected.
  ///
  /// In en, this message translates to:
  /// **'Not selected'**
  String get notSelected;

  /// No description provided for @monitorRunning.
  ///
  /// In en, this message translates to:
  /// **'Monitoring Steam content requests'**
  String get monitorRunning;

  /// No description provided for @monitorStopped.
  ///
  /// In en, this message translates to:
  /// **'Manifest monitor is stopped'**
  String get monitorStopped;

  /// No description provided for @activityLog.
  ///
  /// In en, this message translates to:
  /// **'Activity log'**
  String get activityLog;

  /// No description provided for @depotEntryCount.
  ///
  /// In en, this message translates to:
  /// **'{count} depot entries'**
  String depotEntryCount(String count);

  /// No description provided for @pinInstalledDescription.
  ///
  /// In en, this message translates to:
  /// **'Use the manifest IDs already recorded by the installed Steam app.'**
  String get pinInstalledDescription;

  /// No description provided for @latestPublicDescription.
  ///
  /// In en, this message translates to:
  /// **'Read the latest public manifest IDs from SteamCMD metadata.'**
  String get latestPublicDescription;

  /// No description provided for @unpinDescription.
  ///
  /// In en, this message translates to:
  /// **'Comment out manifest pins while retaining them for later recovery.'**
  String get unpinDescription;

  /// No description provided for @depotEntries.
  ///
  /// In en, this message translates to:
  /// **'Depot entries'**
  String get depotEntries;

  /// No description provided for @pinned.
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get pinned;

  /// No description provided for @notPinned.
  ///
  /// In en, this message translates to:
  /// **'Not pinned'**
  String get notPinned;

  /// No description provided for @noDepotEntries.
  ///
  /// In en, this message translates to:
  /// **'No depot entries were found in this Lua file.'**
  String get noDepotEntries;

  /// No description provided for @manifestPinFooter.
  ///
  /// In en, this message translates to:
  /// **'Changes are written to the game\'s Lua file after creating a backup.'**
  String get manifestPinFooter;

  /// No description provided for @enterValidDlcAppIds.
  ///
  /// In en, this message translates to:
  /// **'Enter one or more valid DLC AppIDs.'**
  String get enterValidDlcAppIds;

  /// No description provided for @addedDlcCount.
  ///
  /// In en, this message translates to:
  /// **'Added {count} DLC entries.'**
  String addedDlcCount(String count);

  /// No description provided for @removeDlc.
  ///
  /// In en, this message translates to:
  /// **'Remove DLC entry'**
  String get removeDlc;

  /// No description provided for @removedDlcEntry.
  ///
  /// In en, this message translates to:
  /// **'Removed AppID {appId}.'**
  String removedDlcEntry(String appId);

  /// No description provided for @luaEntries.
  ///
  /// In en, this message translates to:
  /// **'Lua entries'**
  String get luaEntries;

  /// No description provided for @diagnosticsSummary.
  ///
  /// In en, this message translates to:
  /// **'{passed} of {total} checks passed'**
  String diagnosticsSummary(String passed, String total);

  /// No description provided for @missing.
  ///
  /// In en, this message translates to:
  /// **'Missing'**
  String get missing;

  /// No description provided for @noDiagnosticsFound.
  ///
  /// In en, this message translates to:
  /// **'No diagnostic checks are available.'**
  String get noDiagnosticsFound;

  /// No description provided for @diagnosticsFooter.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics only read the configured paths and do not modify Steam files.'**
  String get diagnosticsFooter;

  /// No description provided for @applicationFolders.
  ///
  /// In en, this message translates to:
  /// **'Application folders'**
  String get applicationFolders;

  /// No description provided for @applicationFoldersFooter.
  ///
  /// In en, this message translates to:
  /// **'Logs and backups stay inside the application data directory. Opening a folder does not modify its contents.'**
  String get applicationFoldersFooter;

  /// No description provided for @openLogsAndBackups.
  ///
  /// In en, this message translates to:
  /// **'Open log and backup folders'**
  String get openLogsAndBackups;

  /// No description provided for @dlcAnalysisDescription.
  ///
  /// In en, this message translates to:
  /// **'Manage DLC records, compare Steam depot metadata with Lua, and preview additions.'**
  String get dlcAnalysisDescription;

  /// No description provided for @managePatchesAndLicenses.
  ///
  /// In en, this message translates to:
  /// **'Apply patches and manage license configuration.'**
  String get managePatchesAndLicenses;

  /// No description provided for @setLuaDirectory.
  ///
  /// In en, this message translates to:
  /// **'Set Lua library folder'**
  String get setLuaDirectory;

  /// No description provided for @luaDirectoryUpdated.
  ///
  /// In en, this message translates to:
  /// **'Lua library folder updated and the library was refreshed.'**
  String get luaDirectoryUpdated;

  /// No description provided for @kernelDownloadsAndNetwork.
  ///
  /// In en, this message translates to:
  /// **'Kernel, downloads and network'**
  String get kernelDownloadsAndNetwork;

  /// No description provided for @conversionResults.
  ///
  /// In en, this message translates to:
  /// **'Conversion results'**
  String get conversionResults;

  /// No description provided for @noMatchingManifestsFound.
  ///
  /// In en, this message translates to:
  /// **'No matching manifests were found.'**
  String get noMatchingManifestsFound;

  /// No description provided for @versionLabel.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get versionLabel;

  /// No description provided for @platformLabel.
  ///
  /// In en, this message translates to:
  /// **'Platform'**
  String get platformLabel;

  /// No description provided for @updatedLabel.
  ///
  /// In en, this message translates to:
  /// **'Updated'**
  String get updatedLabel;

  /// No description provided for @fileSizeLabel.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get fileSizeLabel;

  /// No description provided for @sourceLabel.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get sourceLabel;

  /// No description provided for @destinationLabel.
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get destinationLabel;

  /// No description provided for @actionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get actionsLabel;

  /// No description provided for @selectAGameToShowGameTools.
  ///
  /// In en, this message translates to:
  /// **'Select a game to show its specific tools.'**
  String get selectAGameToShowGameTools;

  /// No description provided for @lanTransfer.
  ///
  /// In en, this message translates to:
  /// **'LAN transfer'**
  String get lanTransfer;

  /// No description provided for @lanTransferDescription.
  ///
  /// In en, this message translates to:
  /// **'Send an installed game, its Lua and the related manifests directly to another FlSteamLua PC on this network.'**
  String get lanTransferDescription;

  /// No description provided for @allowLanTransfers.
  ///
  /// In en, this message translates to:
  /// **'Allow transfers to this device'**
  String get allowLanTransfers;

  /// No description provided for @allowLanTransfersDescription.
  ///
  /// In en, this message translates to:
  /// **'Run the encrypted receiver while FlSteamLua stays open or in the tray.'**
  String get allowLanTransfersDescription;

  /// No description provided for @lanTransferTask.
  ///
  /// In en, this message translates to:
  /// **'Transfer {game}'**
  String lanTransferTask(String game);

  /// No description provided for @lanNearbyDevices.
  ///
  /// In en, this message translates to:
  /// **'Nearby devices'**
  String get lanNearbyDevices;

  /// No description provided for @lanNearbyDevicesDescription.
  ///
  /// In en, this message translates to:
  /// **'Devices appear automatically on the same private network. Unknown devices still need approval before sending files.'**
  String get lanNearbyDevicesDescription;

  /// No description provided for @lanNoDevices.
  ///
  /// In en, this message translates to:
  /// **'No receiving device found'**
  String get lanNoDevices;

  /// No description provided for @lanNoDevicesDescription.
  ///
  /// In en, this message translates to:
  /// **'Enable receiving on the other PC, or add its IP address manually.'**
  String get lanNoDevicesDescription;

  /// No description provided for @lanAddDevice.
  ///
  /// In en, this message translates to:
  /// **'Add device'**
  String get lanAddDevice;

  /// No description provided for @lanDeviceAddress.
  ///
  /// In en, this message translates to:
  /// **'Device address'**
  String get lanDeviceAddress;

  /// No description provided for @lanDeviceAddressHint.
  ///
  /// In en, this message translates to:
  /// **'192.168.1.20'**
  String get lanDeviceAddressHint;

  /// No description provided for @lanConnectDevice.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get lanConnectDevice;

  /// No description provided for @lanManualDevice.
  ///
  /// In en, this message translates to:
  /// **'Manual address'**
  String get lanManualDevice;

  /// No description provided for @lanTrusted.
  ///
  /// In en, this message translates to:
  /// **'Trusted'**
  String get lanTrusted;

  /// No description provided for @lanUntrusted.
  ///
  /// In en, this message translates to:
  /// **'Needs approval'**
  String get lanUntrusted;

  /// No description provided for @lanSendGame.
  ///
  /// In en, this message translates to:
  /// **'Send game'**
  String get lanSendGame;

  /// No description provided for @lanChooseDevice.
  ///
  /// In en, this message translates to:
  /// **'Receiver'**
  String get lanChooseDevice;

  /// No description provided for @lanSendToLan.
  ///
  /// In en, this message translates to:
  /// **'Send over LAN'**
  String get lanSendToLan;

  /// No description provided for @lanReceiveTransfer.
  ///
  /// In en, this message translates to:
  /// **'Receive transfer'**
  String get lanReceiveTransfer;

  /// No description provided for @lanIncomingTransferTitle.
  ///
  /// In en, this message translates to:
  /// **'Receive {game}'**
  String lanIncomingTransferTitle(String game);

  /// No description provided for @lanTransferFromDevice.
  ///
  /// In en, this message translates to:
  /// **'From {device}'**
  String lanTransferFromDevice(String device);

  /// No description provided for @lanAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get lanAccept;

  /// No description provided for @lanReject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get lanReject;

  /// No description provided for @lanRememberDevice.
  ///
  /// In en, this message translates to:
  /// **'Remember this device'**
  String get lanRememberDevice;

  /// No description provided for @lanAcceptAndRemember.
  ///
  /// In en, this message translates to:
  /// **'Accept and remember'**
  String get lanAcceptAndRemember;

  /// No description provided for @lanContentToTransfer.
  ///
  /// In en, this message translates to:
  /// **'Content to transfer'**
  String get lanContentToTransfer;

  /// No description provided for @lanOfficialFiles.
  ///
  /// In en, this message translates to:
  /// **'Official game files'**
  String get lanOfficialFiles;

  /// No description provided for @lanModifiedFiles.
  ///
  /// In en, this message translates to:
  /// **'Modified game files'**
  String get lanModifiedFiles;

  /// No description provided for @lanExtraFiles.
  ///
  /// In en, this message translates to:
  /// **'Additional files and mods'**
  String get lanExtraFiles;

  /// No description provided for @lanLuaAndManifests.
  ///
  /// In en, this message translates to:
  /// **'Lua and manifests'**
  String get lanLuaAndManifests;

  /// No description provided for @lanDepotManifests.
  ///
  /// In en, this message translates to:
  /// **'Depot manifests'**
  String get lanDepotManifests;

  /// No description provided for @lanExtrasWarning.
  ///
  /// In en, this message translates to:
  /// **'Additional files may include mods, patches or saves stored inside the game folder. Select only what the receiver needs.'**
  String get lanExtrasWarning;

  /// No description provided for @lanNoManifestWarning.
  ///
  /// In en, this message translates to:
  /// **'No local depot manifest was found. Official files cannot be identified automatically, so every game file requires manual selection.'**
  String get lanNoManifestWarning;

  /// No description provided for @lanNetworkSpeed.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get lanNetworkSpeed;

  /// No description provided for @lanPeakSpeed.
  ///
  /// In en, this message translates to:
  /// **'Peak'**
  String get lanPeakSpeed;

  /// No description provided for @lanProgress.
  ///
  /// In en, this message translates to:
  /// **'Transferring game data'**
  String get lanProgress;

  /// No description provided for @lanRemainingTime.
  ///
  /// In en, this message translates to:
  /// **'Time remaining'**
  String get lanRemainingTime;

  /// No description provided for @lanPause.
  ///
  /// In en, this message translates to:
  /// **'Pause transfer'**
  String get lanPause;

  /// No description provided for @lanPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get lanPaused;

  /// No description provided for @lanResume.
  ///
  /// In en, this message translates to:
  /// **'Resume transfer'**
  String get lanResume;

  /// No description provided for @lanCancelTransfer.
  ///
  /// In en, this message translates to:
  /// **'Cancel transfer'**
  String get lanCancelTransfer;

  /// No description provided for @lanWaitingApproval.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the receiver to approve'**
  String get lanWaitingApproval;

  /// No description provided for @lanWaitingSteam.
  ///
  /// In en, this message translates to:
  /// **'Downloaded. Close Steam on the receiving PC to finish installation.'**
  String get lanWaitingSteam;

  /// No description provided for @lanCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get lanCompleted;

  /// No description provided for @lanFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get lanFailed;

  /// No description provided for @lanActiveTransfer.
  ///
  /// In en, this message translates to:
  /// **'Active transfer'**
  String get lanActiveTransfer;

  /// No description provided for @lanRecentTransfers.
  ///
  /// In en, this message translates to:
  /// **'Recent transfers'**
  String get lanRecentTransfers;

  /// No description provided for @lanHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'Completed transfers will appear here.'**
  String get lanHistoryEmpty;

  /// No description provided for @lanDestinationLibrary.
  ///
  /// In en, this message translates to:
  /// **'Destination Steam library'**
  String get lanDestinationLibrary;

  /// No description provided for @lanSteamRestartNotice.
  ///
  /// In en, this message translates to:
  /// **'FlSteamLua sees the game immediately. Restart Steam after installation to refresh its installed-game list.'**
  String get lanSteamRestartNotice;

  /// No description provided for @lanForgetDevice.
  ///
  /// In en, this message translates to:
  /// **'Forget device'**
  String get lanForgetDevice;

  /// No description provided for @lanDeviceFingerprint.
  ///
  /// In en, this message translates to:
  /// **'Device fingerprint'**
  String get lanDeviceFingerprint;

  /// No description provided for @lanReceiveDisabled.
  ///
  /// In en, this message translates to:
  /// **'Receiving is off'**
  String get lanReceiveDisabled;

  /// No description provided for @lanReceiveEnabled.
  ///
  /// In en, this message translates to:
  /// **'Ready to receive'**
  String get lanReceiveEnabled;

  /// No description provided for @lanTransferSettings.
  ///
  /// In en, this message translates to:
  /// **'This PC'**
  String get lanTransferSettings;

  /// No description provided for @lanNoLibrary.
  ///
  /// In en, this message translates to:
  /// **'No writable Steam library was found.'**
  String get lanNoLibrary;

  /// No description provided for @lanDiskUsage.
  ///
  /// In en, this message translates to:
  /// **'Disk activity'**
  String get lanDiskUsage;

  /// No description provided for @lanGameFiles.
  ///
  /// In en, this message translates to:
  /// **'Game files'**
  String get lanGameFiles;

  /// No description provided for @lanPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing files'**
  String get lanPreparing;

  /// No description provided for @lanVerifying.
  ///
  /// In en, this message translates to:
  /// **'Verifying files'**
  String get lanVerifying;

  /// No description provided for @lanCommitting.
  ///
  /// In en, this message translates to:
  /// **'Installing game'**
  String get lanCommitting;

  /// No description provided for @lanCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get lanCancelled;

  /// No description provided for @lanSelectDestinationDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose a registered Steam library with enough free space.'**
  String get lanSelectDestinationDescription;

  /// No description provided for @lanNoSelectedFiles.
  ///
  /// In en, this message translates to:
  /// **'No files selected'**
  String get lanNoSelectedFiles;

  /// No description provided for @lanRefreshDevices.
  ///
  /// In en, this message translates to:
  /// **'Refresh devices'**
  String get lanRefreshDevices;

  /// No description provided for @lanChunkProgress.
  ///
  /// In en, this message translates to:
  /// **'Chunk progress'**
  String get lanChunkProgress;

  /// No description provided for @lanCachedChunks.
  ///
  /// In en, this message translates to:
  /// **'Cached chunks'**
  String get lanCachedChunks;

  /// No description provided for @lanChunkCache.
  ///
  /// In en, this message translates to:
  /// **'Chunk cache'**
  String get lanChunkCache;

  /// No description provided for @lanClearChunkCache.
  ///
  /// In en, this message translates to:
  /// **'Clear chunk cache'**
  String get lanClearChunkCache;

  /// No description provided for @lanChunkCacheCleared.
  ///
  /// In en, this message translates to:
  /// **'Chunk cache cleared.'**
  String get lanChunkCacheCleared;

  /// No description provided for @lanManualAddressInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid IPv4 address or host name.'**
  String get lanManualAddressInvalid;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @screenshots.
  ///
  /// In en, this message translates to:
  /// **'Screenshots'**
  String get screenshots;

  /// No description provided for @previewImage.
  ///
  /// In en, this message translates to:
  /// **'Preview image'**
  String get previewImage;

  /// No description provided for @previousImage.
  ///
  /// In en, this message translates to:
  /// **'Previous image'**
  String get previousImage;

  /// No description provided for @nextImage.
  ///
  /// In en, this message translates to:
  /// **'Next image'**
  String get nextImage;

  /// No description provided for @selectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get selectAll;

  /// No description provided for @contentPreview.
  ///
  /// In en, this message translates to:
  /// **'Content preview'**
  String get contentPreview;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
