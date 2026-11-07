// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get languageName => 'English';

  @override
  String get quickStart => 'Quick start';

  @override
  String get quickStartSkip => 'Skip setup';

  @override
  String get quickStartBack => 'Back';

  @override
  String get quickStartNext => 'Next';

  @override
  String get quickStartEnter => 'Enter app';

  @override
  String get quickStartAppearance => 'Appearance';

  @override
  String get quickStartFolders => 'Game folders';

  @override
  String get quickStartPrepare => 'Get ready';

  @override
  String get quickStartAppearanceTitle => 'Make it yours';

  @override
  String get quickStartAppearanceHint =>
      'Choose your language, colors and sidebar. Changes appear immediately.';

  @override
  String get quickStartFoldersTitle => 'Connect your library';

  @override
  String get quickStartFoldersHint =>
      'Choose your Steam installation and the folder where new Lua files will be saved.';

  @override
  String get quickStartPrepareTitle => 'Ready when you are';

  @override
  String get quickStartPrepareHint =>
      'Set up the core and content sources as needed. You can return to quick start from Settings at any time.';

  @override
  String get quickStartMoreAppearance => 'More appearance settings';

  @override
  String get quickStartNetworkHint => 'Proxy and download mirrors';

  @override
  String quickStartSources(int count) {
    return '$count configured sources enabled';
  }

  @override
  String quickStartStep(int current, int total) {
    return '$current / $total';
  }

  @override
  String get updateKeySubscriptions => 'Update key subscriptions';

  @override
  String launch(String value1) {
    return 'Launch $value1';
  }

  @override
  String stop(String value1) {
    return 'Stop $value1';
  }

  @override
  String get deleteLuaRecord => 'Delete Lua record?';

  @override
  String
  get onlyThisLuaFileIsRemovedTheGameStaysInstalledAndABackupIsSavedFirst =>
      'Only this Lua file is removed. The game stays installed, and a backup is saved first.';

  @override
  String get cancel => 'Cancel';

  @override
  String get deleteRecord => 'Delete record';

  @override
  String get deleteLuaRecord2 => 'Delete Lua record';

  @override
  String get unfavorite => 'Unfavorite';

  @override
  String get favorite => 'Favorite';

  @override
  String get manage => 'Manage';

  @override
  String get manageSaves => 'Manage saves';

  @override
  String get manageAchievements => 'Manage achievements';

  @override
  String get trainers => 'Trainers';

  @override
  String get onlineFixes => 'Online fixes';

  @override
  String get dlcAnalysis => 'DLC management';

  @override
  String get keySubscriptionsOfflineLua => 'Get Lua / manifests';

  @override
  String get gameToolsAndVersionManagement =>
      'Game tools and version management';

  @override
  String get installOrRestorePatches => 'Install or restore patches';

  @override
  String get extractAccountGameData => 'Extract account game data';

  @override
  String get running => 'Running';

  @override
  String get installed => 'Installed';

  @override
  String get luaConfigured => 'Lua configured';

  @override
  String get luaDisabled => 'Lua disabled';

  @override
  String get accountOwnsThisGame => 'Account owns this game';

  @override
  String get notOwnedByAccount => 'Not owned by account';

  @override
  String get ownershipUnknown => 'Ownership unknown';

  @override
  String get stopGame => 'Stop game';

  @override
  String get play => 'Play';

  @override
  String get onlineLaunch => 'Launch online';

  @override
  String get onlineLaunchOptions => 'Online launch options';

  @override
  String get onlineFixOnly => 'Online launch (-onlinefix)';

  @override
  String get onlineFixWithRealAppId => 'Online launch (-onlinefix -realappid)';

  @override
  String get installWithSteam => 'Install with Steam';

  @override
  String get getLuaManifests => 'Get Lua / manifests';

  @override
  String get addToLibrary => 'Add to Lua library';

  @override
  String get openGameFolder => 'Open game folder';

  @override
  String get playtime => 'Playtime';

  @override
  String playtimeHours(String hours) {
    return '$hours hours';
  }

  @override
  String minutes(String playtimeMinutes) {
    return '$playtimeMinutes minutes';
  }

  @override
  String get lastPlayed => 'Last played';

  @override
  String get notRecorded => 'Not recorded';

  @override
  String get diskSpace => 'Disk space';

  @override
  String get storePrice => 'Store price';

  @override
  String get achievements => 'Achievements';

  @override
  String get viewAndManageGameAchievements =>
      'View and manage game achievements';

  @override
  String get cloudSaves => 'Cloud saves';

  @override
  String get backUpSyncAndRestoreProgress => 'View save locations and backups';

  @override
  String get gameManagement => 'Game management';

  @override
  String get trainersMultiplayerAndMore => 'Trainers, multiplayer and more';

  @override
  String get luaRecord => 'Lua record';

  @override
  String get enabledTakesEffectAfterRestartingSteam =>
      'Enabled; the core can reload this Lua automatically';

  @override
  String get disabledFileIsPreserved => 'Disabled; file is preserved';

  @override
  String get changeLuaState => 'Change Lua state';

  @override
  String get aboutThisGame => 'About this game';

  @override
  String get steamStore => 'Steam store';

  @override
  String get storeDetailsAreUnavailableLocalGameActionsRemainAvailable =>
      'Store details are unavailable. Local game actions remain available.';

  @override
  String get retry => 'Retry';

  @override
  String get developer => 'Developer';

  @override
  String get released => 'Released';

  @override
  String get selectDlcManifestsToRetrieveThisDoesNotPurchaseOrInstallDlc =>
      'Select DLC manifests to retrieve. This does not purchase or install DLC.';

  @override
  String get loadDlcNames => 'Load DLC names';

  @override
  String get clearSelection => 'Clear selection';

  @override
  String getSelected(String selectedDlcCount) {
    return 'Get selected ($selectedDlcCount)';
  }

  @override
  String get importLuaAndManifests => 'Import Lua and manifests';

  @override
  String get importResults => 'Import results';

  @override
  String completedSkippedFailed(
    String writtenCount,
    String skippedCount,
    String errorsCount,
  ) {
    return 'Completed $writtenCount · Skipped $skippedCount · Failed $errorsCount';
  }

  @override
  String get completed => 'Completed';

  @override
  String get existingFilesLeftUnchanged => 'Existing files, left unchanged';

  @override
  String get errors => 'Errors';

  @override
  String get close => 'Close';

  @override
  String get backUpAndReimportWithOverwrite =>
      'Back up and reimport with overwrite';

  @override
  String get fetchGameNamesAndCovers => 'Fetch game names and covers';

  @override
  String get chooseALuaAndManifestFolder => 'Choose a Lua and manifest folder';

  @override
  String get exportLuaToFolder => 'Export Lua to folder';

  @override
  String get exportLua => 'Export Lua';

  @override
  String get exportResults => 'Export results';

  @override
  String get enableSelectedLua => 'Enable selected Lua';

  @override
  String get disableSelectedLua => 'Disable selected Lua';

  @override
  String get deleteLua => 'Delete Lua';

  @override
  String deleteLuaFiles(String targetsCount) {
    return 'Delete $targetsCount Lua files?';
  }

  @override
  String luaFilesAreBackedUpBeforeDeletionSteamGamesAndSavesAreKept(
    String value1,
  ) {
    return 'Lua files are backed up before deletion. Steam games and saves are kept.\n\n$value1';
  }

  @override
  String get backUpAndDelete => 'Back up and delete';

  @override
  String get gameDetails => 'Game details';

  @override
  String get editLua => 'Edit Lua';

  @override
  String get disableLua => 'Disable Lua';

  @override
  String get enableLua => 'Enable Lua';

  @override
  String get openLuaFolder => 'Open Lua folder';

  @override
  String get pinLatestPublicVersion => 'Pin latest public version';

  @override
  String get pinInstalledVersion => 'Pin installed version';

  @override
  String get unpinVersion => 'Unpin version';

  @override
  String get dlcManagementAndAnalysis => 'DLC management and analysis';

  @override
  String get manageGameSaves => 'Manage game saves';

  @override
  String get editAchievements => 'Edit achievements';

  @override
  String get manageGamePatches => 'Manage game patches';

  @override
  String get copyAppid => 'Copy AppID';

  @override
  String get updateManifestPins => 'Update manifest pins';

  @override
  String get launchGame => 'Launch game';

  @override
  String manage2(String value1) {
    return 'Manage $value1';
  }

  @override
  String min(String playtimeMinutes) {
    return '$playtimeMinutes min';
  }

  @override
  String get luaEnabled => 'Lua enabled';

  @override
  String get luaDisabled2 => 'Lua disabled';

  @override
  String get game => 'Game';

  @override
  String get status => 'Status';

  @override
  String get luaFile => 'Lua file';

  @override
  String selected(String selectedCount, String gamesCount) {
    return 'Selected $selectedCount / $gamesCount';
  }

  @override
  String get selectAllFiltered => 'Select all filtered';

  @override
  String get clearSelection2 => 'Clear selection';

  @override
  String get enableSelected => 'Enable selected';

  @override
  String get disableSelected => 'Disable selected';

  @override
  String get export => 'Export';

  @override
  String get library => 'Library';

  @override
  String get manageLuaConfigurationsAndInstalledGames =>
      'Manage Lua configurations and installed games.';

  @override
  String get import => 'Import';

  @override
  String get importFilesOrArchives => 'Import files or archives';

  @override
  String get importFolder => 'Import folder';

  @override
  String get luaLibrary => 'Lua library';

  @override
  String get steamGames => 'Steam games';

  @override
  String get searchGameNamesOrAppid => 'Search game names or AppID';

  @override
  String get rescan => 'Rescan';

  @override
  String get view => 'View';

  @override
  String get gridView => 'Grid view';

  @override
  String get listView => 'List view';

  @override
  String get tableView => 'Table view';

  @override
  String get sort => 'Sort';

  @override
  String get filter => 'Filter';

  @override
  String get nameAscending => 'Name ascending';

  @override
  String get nameDescending => 'Name descending';

  @override
  String get recentlyPlayed => 'Recently played';

  @override
  String get libraryActions => 'Library actions';

  @override
  String get refreshGameInformation => 'Refresh game information';

  @override
  String get disableSteamOfflineMode => 'Disable Steam offline mode';

  @override
  String get enableSteamOfflineMode => 'Enable Steam offline mode';

  @override
  String get all => 'All';

  @override
  String get enabled => 'Enabled';

  @override
  String get disabled => 'Disabled';

  @override
  String get favorites => 'Favorites';

  @override
  String get done => 'Done';

  @override
  String get select => 'Select';

  @override
  String informationCouldNotBeLoadedForGamesLocalRecordsAreKept(
    String metadataErrorsCount,
  ) {
    return 'Information could not be loaded for $metadataErrorsCount games. Local records are kept.';
  }

  @override
  String get libraryDetails => 'Library details';

  @override
  String get details => 'Details';

  @override
  String get descriptionLabel => 'Description';

  @override
  String get connectYourSteamLibrary => 'Connect your Steam library';

  @override
  String
  get chooseYourSteamInstallationToReadLuaConfigurationsAndInstalledGames =>
      'Choose your Steam installation to read Lua configurations and installed games.';

  @override
  String get chooseSteamFolder => 'Choose Steam folder';

  @override
  String get noMatchingLuaConfigurations => 'No matching Lua configurations';

  @override
  String get noMatchingInstalledGames => 'No matching installed games';

  @override
  String get noSearchResults => 'No matching results';

  @override
  String get dropLuaFilesManifestsOrArchivesHereOrChangeTheFilter =>
      'Drop Lua files, manifests or archives here, or change the filter.';

  @override
  String
  get installedGamesAreReadFromSteamAppmanifestFilesLuaConfigurationsAreInTheFirstTab =>
      'Installed games are read from Steam appmanifest files. Lua configurations are in the first tab.';

  @override
  String get importLua => 'Import Lua';

  @override
  String get chooseASteamFolderFirst => 'Choose a Steam folder first';

  @override
  String get dropToImportLuaManifestsOrArchives =>
      'Drop to import Lua, manifests or archives';

  @override
  String get owned => 'Owned';

  @override
  String get tasks => 'Tasks';

  @override
  String get clearCompleted => 'Clear finished tasks';

  @override
  String get allClear => 'All clear';

  @override
  String get downloadsImportsAndBackupsWillAppearHere =>
      'Downloads, imports and backups will appear here.';

  @override
  String get cancelling => 'Cancelling…';

  @override
  String get showLogs => 'Show logs';

  @override
  String get start => 'Start';

  @override
  String get stop2 => 'Stop';

  @override
  String linkedTrainer(String Stop, String appId) {
    return '$Stop linked trainer · $appId';
  }

  @override
  String get discardPendingChanges => 'Discard pending changes?';

  @override
  String
  get reloadingOrSwitchingGamesDiscardsUnsavedAchievementAndStatisticChanges =>
      'Reloading or switching games discards unsaved achievement and statistic changes.';

  @override
  String get keepEditing => 'Keep editing';

  @override
  String get discardAndContinue => 'Discard and continue';

  @override
  String chooseAGameToManageAchievementsAndStatisticsGames(
    String allGamesCount,
  ) {
    return 'Choose a game to manage achievements and statistics. $allGamesCount games';
  }

  @override
  String get searchGamesOrAppid => 'Search games or AppID';

  @override
  String get appidAscending => 'AppID ascending';

  @override
  String get appidDescending => 'AppID descending';

  @override
  String continueEditing(String value1) {
    return 'Continue editing $value1';
  }

  @override
  String get pendingChanges => 'pending changes';

  @override
  String get yourLibraryHasNoGamesYet => 'Your library has no games yet';

  @override
  String get noMatchingGames => 'No matching games';

  @override
  String saveChanges(String count) {
    return 'Save $count changes';
  }

  @override
  String get unlock => 'Unlock';

  @override
  String get lock => 'Lock';

  @override
  String get saveToSteam => 'Save to Steam';

  @override
  String get savedAndConfirmedByReadingBackFromSteam =>
      'Saved and confirmed by reading back from Steam.';

  @override
  String get integerValue => 'Integer value';

  @override
  String get value => 'Value';

  @override
  String get enterAValidValueInRange => 'Enter a valid value in range';

  @override
  String get stageChange => 'Stage change';

  @override
  String get chooseAGame => 'Choose a game';

  @override
  String get reload => 'Reload';

  @override
  String get unlocked => 'unlocked';

  @override
  String get couldNotLoadAchievements => 'Could not load achievements';

  @override
  String get startSteamSignInThenSelectReload =>
      'Start Steam, sign in, then select Reload.';

  @override
  String get statistics => 'Statistics';

  @override
  String get searchAchievements => 'Search achievements';

  @override
  String get unlocked2 => 'Unlocked';

  @override
  String get locked => 'Locked';

  @override
  String get pending => 'Pending';

  @override
  String get unlockAll => 'Unlock all';

  @override
  String get lockAll => 'Lock all';

  @override
  String get invert => 'Invert';

  @override
  String get noMatchingAchievements => 'No matching achievements';

  @override
  String get thisAchievementIsManagedByTheGameServer =>
      'This achievement is managed by the game server';

  @override
  String get hiddenAchievement => 'Hidden achievement';

  @override
  String get searchStatisticNameOrId => 'Search statistic name or ID';

  @override
  String get noReadableLocalStatisticsForThisGame =>
      'No readable local statistics for this game';

  @override
  String get noMatchingStatistics => 'No matching statistics';

  @override
  String get editStatistic => 'Edit statistic';

  @override
  String changesPending(String value1) {
    return '$value1 changes pending';
  }

  @override
  String get changesAreSubmittedToSteamWhenSaved =>
      'Changes are submitted to Steam when saved';

  @override
  String get discard => 'Discard';

  @override
  String get saveChanges2 => 'Save changes';

  @override
  String get loadCloudSaves => 'Load cloud saves';

  @override
  String get completed2 => 'Completed';

  @override
  String get localFolder => 'Local folder';

  @override
  String get configureLocalRedirectionAndRemoteStorageSeparately =>
      'Configure local redirection and remote storage separately.';

  @override
  String get refresh => 'Refresh';

  @override
  String get refreshCloudSaves => 'Refresh cloud saves';

  @override
  String get localSaveRedirection => 'Save redirection';

  @override
  String get enabledRestartSteamAfterChanges =>
      'Enabled in configuration; restart Steam after changes';

  @override
  String get disabledEnablingDownloadsAndVerifiesTheCloudredirectDll =>
      'Disabled; enabling downloads and verifies the CloudRedirect DLL';

  @override
  String get enableSaveRedirection => 'Enable save redirection';

  @override
  String
  get downloadCloudredirectAndUpdateSteamFilesAndKernelConfigurationRestartSteamAfterwards =>
      'Download CloudRedirect and update Steam files and kernel configuration. Restart Steam afterwards.';

  @override
  String get configureRedirection => 'Configure redirection';

  @override
  String get localSaveFolder => 'Folder-provider directory';

  @override
  String get remoteStorage => 'Remote storage';

  @override
  String get configured => 'Configured';

  @override
  String get remoteSyncIsNotConfigured => 'Remote storage is not configured';

  @override
  String get configure => 'Configure';

  @override
  String get testCloudConnection => 'Test cloud connection';

  @override
  String get testConnection => 'Test connection';

  @override
  String get connectCloudAccount => 'Connect cloud account';

  @override
  String get authorize => 'Authorize';

  @override
  String get disconnectAccount => 'Disconnect account';

  @override
  String get removeLocalCredentialsRemoteSavesRemain =>
      'Remove local credentials. Remote saves remain.';

  @override
  String get disconnectAccount2 => 'Disconnect account';

  @override
  String get disconnect => 'Disconnect';

  @override
  String get gameSaves => 'Game saves';

  @override
  String get backups => 'Backups';

  @override
  String get dataManagement => 'Data management';

  @override
  String get storageUsage => 'Storage usage';

  @override
  String get storageLocations => 'Storage locations';

  @override
  String get storageLocationsDescription =>
      'Cache, backups, downloads, and logs can use separate folders. Lua stays managed by Steam and game files.';

  @override
  String get appCache => 'Cache';

  @override
  String get logs => 'Logs';

  @override
  String get appData => 'App data';

  @override
  String get lanTransferCache => 'Transfer staging';

  @override
  String get cleanup => 'Cleanup';

  @override
  String get clearCache => 'Clear cache';

  @override
  String get clearCacheDescription =>
      'Remove covers, cached metadata, key caches, and LAN transfer chunks.';

  @override
  String get clearCacheConfirmation =>
      'Clear all cached files? Backups, downloads, settings, and save data are not removed.';

  @override
  String get clearingCache => 'Clearing cached files';

  @override
  String get cacheCleared => 'Cache cleared';

  @override
  String get scanningStorage => 'Calculating storage usage';

  @override
  String get changeStorageFolder => 'Change folder';

  @override
  String get chooseStorageFolder => 'Choose storage folder';

  @override
  String get storageChangeBlockedByTasks =>
      'Wait for running tasks to finish before changing storage folders.';

  @override
  String get chooseSeparateStorageFolder =>
      'Choose a folder that is not inside the current storage folder.';

  @override
  String get chooseEmptyStorageFolder => 'Choose an empty destination folder.';

  @override
  String moveStorageData(String name) {
    return 'Move $name data';
  }

  @override
  String get moveStorageDataDescription =>
      'Existing files will be copied to the new folder, then removed from the old folder.';

  @override
  String get preparingStorageFolder => 'Preparing storage folder';

  @override
  String get storageFolderUpdated => 'Storage folder updated';

  @override
  String get restoreDefault => 'Use default folder';

  @override
  String get noRedirectedSavesFound => 'No redirected saves found';

  @override
  String
  get chooseAFolderOrConnectRemoteStoragePlayAGameWithRedirectionEnabledToCreateSaves =>
      'Choose a folder or connect remote storage. Play a game with redirection enabled to create saves.';

  @override
  String get remote => 'Remote';

  @override
  String get local => 'Local';

  @override
  String get files => 'files';

  @override
  String get openFolder => 'Open folder';

  @override
  String get backUpThisGame => 'Back up selected save location';

  @override
  String get downloadToFolder => 'Export raw repository';

  @override
  String get uploadToRemote => 'Copy folder repository to remote';

  @override
  String get previewDeletion => 'Preview deletion';

  @override
  String get confirm => 'Confirm';

  @override
  String get chooseSaveFolder => 'Choose save folder';

  @override
  String get changeSaveFolder => 'Change save folder';

  @override
  String
  get closeSteamAndAllGamesThenChooseAnEmptyFolderCurrentSavesWillBeCopiedToTheNewFolderAnd =>
      'Close Steam and all games, then choose an empty folder. Current saves will be copied to the new folder and the originals retained. Existing destination files will not be overwritten. Restart Steam when finished.';

  @override
  String get setSaveFolder => 'Set save folder';

  @override
  String get backUpSaves => 'Back up saves';

  @override
  String get downloadSaves => 'Export save repository';

  @override
  String get uploadSaves => 'Copy save repository';

  @override
  String get remoteFilesWithTheSameNamesWillBeReplacedCloseTheGameFirst =>
      'Remote files with the same names will be replaced. Close the game first.';

  @override
  String get prepareDeletionPreview => 'Prepare deletion preview';

  @override
  String get deleteThisGameSSaves =>
      'Delete saves at the selected account and location';

  @override
  String get aCompleteBackupIsCreatedBeforeDeleting =>
      'Back up and then delete the selected locations:';

  @override
  String get backupLocation => 'Backup location';

  @override
  String get saveBackups => 'Save backups';

  @override
  String get noBackupsYet => 'No backups yet';

  @override
  String get restoreBackup => 'Restore backup';

  @override
  String
  get restoreToTheCurrentConfiguredLocationsExistingLocalSavesArePreservedInAPreRestoreBack =>
      'Restore to the current configured locations. Existing local saves are preserved in a pre-restore backup; remote files with the same names are replaced. Close the game first.';

  @override
  String get restoreSaves => 'Restore saves';

  @override
  String get restore => 'Restore';

  @override
  String get configureStorage => 'Configure storage';

  @override
  String get provider => 'Provider';

  @override
  String get saveThenChooseAuthorizeToSignInUsingYourBrowser =>
      'Save, then choose Authorize to sign in using your browser.';

  @override
  String get authentication => 'Authentication';

  @override
  String
  get usesTheWindowsCredentialsEnteredBelowDomainUsernameOrUsernameDomain =>
      'Uses the Windows credentials entered below: DOMAIN\\username or username@domain.';

  @override
  String get allowHttpCredentialsAndSavesAreSentWithoutEncryption =>
      'Allow HTTP (credentials and saves are sent without encryption)';

  @override
  String get skipTlsCertificateValidationUnsafeTrustedSelfHostedServersOnly =>
      'Skip TLS certificate validation (unsafe; trusted self-hosted servers only)';

  @override
  String get signRequestPayload => 'Sign request payload';

  @override
  String get save => 'Save';

  @override
  String get saveCloudConfiguration => 'Save cloud configuration';

  @override
  String get operationCompleted => 'Operation completed';

  @override
  String get operationCancelled => 'Operation cancelled';

  @override
  String get continueLabel => 'Continue';

  @override
  String get importKernelPackage => 'Import kernel package';

  @override
  String get switchKernel => 'Switch kernel';

  @override
  String currentKernelFilesWillBeBackedUpBeforeInstallingCloseSteamFirst(
    String displayName,
  ) {
    return 'FlSteamLua will prepare the Steam signatures, back up and replace old kernel entries, and remove known incompatible injection files before installing $displayName. Close Steam first.';
  }

  @override
  String kernelSignaturesUnavailable(String build, String files, String error) {
    return 'Could not prepare Steam signatures for build $build. Missing: $files. $error. The kernel was not installed.';
  }

  @override
  String get kernelSignatureFallbackUnavailable =>
      'Local signature generation did not produce all required files';

  @override
  String get noInstalledKernelFilesFound => 'No installed kernel files found.';

  @override
  String get uninstallKernel => 'Uninstall kernel';

  @override
  String get onlyTheseFilesWillBeRemovedAfterSavingABackupCloseSteamFirst =>
      'Only these files will be removed, after saving a backup. Close Steam first.';

  @override
  String get noOtherKernelFilesFound => 'No other kernel files found.';

  @override
  String get cleanOtherKernels => 'Clean other kernels';

  @override
  String
  get selectFilesToRemoveTheyWillBeBackedUpLuaFoldersAndSteamCfgArePreserved =>
      'Select files to remove. They will be backed up; Lua folders and steam.cfg are preserved.';

  @override
  String get backUpAndRemove => 'Back up and remove';

  @override
  String get kernelManagement => 'Kernel management';

  @override
  String get coreAndPlugins => 'Core and plugins';

  @override
  String get downloadsAndNetwork => 'Downloads and network';

  @override
  String get cloudRedirectPlugin => 'CloudRedirect save plugin';

  @override
  String get pluginManagement => 'Plugin management';

  @override
  String get installOrUpdatePlugin => 'Install or update plugin';

  @override
  String get cloudRedirectPluginDescription =>
      'Loaded by OpenSteamTool inside Steam to redirect cloud saves for added games.';

  @override
  String get kernelIntegration => 'Kernel integration';

  @override
  String get openSteamtoolCore => 'OpenSteamTool core';

  @override
  String get actions => 'Actions';

  @override
  String get path => 'Path';

  @override
  String get removeCloudRedirectPlugin => 'Remove CloudRedirect plugin';

  @override
  String get removeCloudRedirectPluginDescription =>
      'Disable kernel integration, back up and remove the CloudRedirect DLL from the Steam folder.';

  @override
  String
  get officialAndLocalKernelPackagesAreCachedForOfflineSwitchingCloseSteamBeforeChangingIts =>
      'Official and local kernel packages are cached for offline switching. Close Steam before changing its files.';

  @override
  String get currentKernel => 'Current kernel';

  @override
  String get unknownVersion => 'Unknown version';

  @override
  String get noKernelInstalled => 'No kernel installed';

  @override
  String get disabled2 => 'Disabled';

  @override
  String get selectYourSteamFolderInSettingsFirst =>
      'Select your Steam folder in settings first.';

  @override
  String get bothInjectionEntriesAreActiveSelectOneEntry =>
      'Both injection entries are active. Select one entry.';

  @override
  String get enableKernel => 'Enable kernel';

  @override
  String get disableKernel => 'Disable kernel';

  @override
  String get kernelFilesWillBeRenamedAfterSavingABackupCloseSteamFirst =>
      'Kernel files will be renamed after saving a backup. Close Steam first.';

  @override
  String get disable => 'Disable';

  @override
  String get enable => 'Enable';

  @override
  String get entryDwmapi => 'Entry: dwmapi';

  @override
  String get entryVersion => 'Entry: version';

  @override
  String get changeInjectionEntry => 'Change injection entry';

  @override
  String get onlyTheSelectedEntryWillRemainActiveCloseSteamFirst =>
      'Only the selected entry will remain active. Close Steam first.';

  @override
  String get fetchSteamSignatures => 'Fetch Steam signatures';

  @override
  String get uninstall => 'Uninstall';

  @override
  String get availablePackages => 'Available packages';

  @override
  String get importZip => 'Import ZIP';

  @override
  String get refreshKernelReleases => 'Refresh kernel releases';

  @override
  String get refreshToLoadOfficialReleasesOrImportALocalKernelZip =>
      'Refresh to load official releases, or import a local kernel ZIP.';

  @override
  String get active => 'Active';

  @override
  String get local2 => 'Local';

  @override
  String get official => 'Official';

  @override
  String get cached => 'Cached';

  @override
  String get notDownloaded => 'Not downloaded';

  @override
  String get downloadOnly => 'Download only';

  @override
  String get downloadKernel => 'Download kernel';

  @override
  String get switchLabel => 'Switch';

  @override
  String get deleteCache => 'Delete cache';

  @override
  String deleteTheCachedPackageBackupsArePreserved(String displayName) {
    return 'Delete the cached $displayName package? Backups are preserved.';
  }

  @override
  String get switchAndRecoveryBackups => 'Switch and recovery backups';

  @override
  String get aRecoverableSnapshotIsSavedBeforeSwitchingOrUninstalling =>
      'A recoverable snapshot is saved before switching or uninstalling.';

  @override
  String get restoreKernelBackup => 'Restore kernel backup';

  @override
  String
  get restoreTheseFilesAndRemoveKernelFilesAbsentFromThisSnapshotCloseSteamFirst =>
      'Restore these files and remove kernel files absent from this snapshot. Close Steam first.';

  @override
  String get repository => 'Repository';

  @override
  String get luaSavedTheOriginalWasBackedUp =>
      'Lua saved. The original was backed up.';

  @override
  String get discardUnsavedChanges => 'Discard unsaved changes?';

  @override
  String get theseChangesHaveNotBeenSavedToTheLuaFile =>
      'These changes have not been saved to the Lua file.';

  @override
  String get enabled2 => 'enabled';

  @override
  String get commented => 'commented';

  @override
  String manifestPinsSaveToApply(String changed, String commented) {
    return '$changed manifest pins $commented. Save to apply.';
  }

  @override
  String get enablePins => 'Enable pins';

  @override
  String get disablePins => 'Disable pins';

  @override
  String ctrlSToSaveOriginalBackedUpBeforeSavingLines(String value1) {
    return 'Ctrl+S to save · Original backed up before saving · $value1 lines';
  }

  @override
  String get directGithub => 'Direct GitHub';

  @override
  String get testCoverSources => 'Test cover sources';

  @override
  String get testGithubDownloadSources => 'Test GitHub download sources';

  @override
  String get testCancelled => 'Test cancelled';

  @override
  String get networkAndDownloadSources => 'Network and download sources';

  @override
  String
  get chooseCoverAndPublicDownloadSourcesForYourConnectionTestsShowCurrentResultsWithoutCha =>
      'Choose cover and public download sources for your connection. Tests show current results without changing your preferences.';

  @override
  String get gameCovers => 'Game covers';

  @override
  String get preferredSource => 'Preferred source';

  @override
  String
  get byDefaultUseTheOfficialImageUrlFromGameDetailsThisPreferenceAffectsArtworkOnlyNotStea =>
      'By default, use the official image URL from game details. This preference affects artwork only, not Steam sign-in, Store APIs or content downloads.';

  @override
  String get githubDownloads => 'GitHub downloads';

  @override
  String get preferredPublicDownloadSource =>
      'Preferred public download source';

  @override
  String get customGithubMirror => 'Custom GitHub mirror';

  @override
  String get githubMirrorHint => 'https://mirror.example.com';

  @override
  String get directDefault => 'Direct (default)';

  @override
  String
  get mirrorsApplyOnlyToAnonymousPublicGithubFileDownloadsSignInApiTokenAndCredentialBearin =>
      'Mirrors apply only to anonymous public GitHub file downloads. Sign-in, API, token and credential-bearing requests always stay direct. The selected mirror processes those public download requests.';

  @override
  String get testPublicDownloadSources => 'Test public download sources';

  @override
  String
  get testingSourcesViewOrCancelTheOperationInGlobalTasksNavigationKeepsItRunning =>
      'Testing sources. View or cancel the operation in global tasks; navigation keeps it running.';

  @override
  String get failed => 'Failed';

  @override
  String get gameManagement2 => 'Game management';

  @override
  String get patchSettings => 'Patch tools';

  @override
  String get patchSettingsDescription =>
      'Verify game files, manage Goldberg and download network patches.';

  @override
  String get patchTools => 'Patch tools';

  @override
  String get patchToolsDescription =>
      'Patch archives are not installed generically. Inspect game files against Steam manifests or use the network patch downloader.';

  @override
  String get gameFileVerification => 'Game file verification';

  @override
  String get gameFileVerificationDescription =>
      'Compare installed files with the manifests recorded by Steam.';

  @override
  String get gamePatchDownload => 'Game patch download';

  @override
  String get gamePatchDownloadDescription =>
      'Download and extract a network patch package without installing it.';

  @override
  String get goldbergEmulator => 'Goldberg emulator';

  @override
  String get goldbergSettings => 'Goldberg settings';

  @override
  String get goldbergDescription =>
      'Download, deploy and configure the Goldberg emulator for this game.';

  @override
  String get goldbergSettingsFooter =>
      'Only the standardized Goldberg deployment is automated. Generic patch archives remain manual.';

  @override
  String get authorizationTicketDescription =>
      'Import and verify tickets while preserving the existing authorization identity by default.';

  @override
  String get matchingLua => 'Matching Lua';

  @override
  String get matchingLuaFound => 'A matching Lua file was found for this game.';

  @override
  String get matchingLuaMissing =>
      'No matching Lua file was found. The ticket can still be applied.';

  @override
  String get ticketActions => 'Ticket actions';

  @override
  String get networkSource => 'Network source';

  @override
  String get selectedPatch => 'Selected';

  @override
  String get loadPatches => 'Load patches';

  @override
  String patchSourceLoaded(String count) {
    return 'Loaded $count patch options.';
  }

  @override
  String get choosePatchType => 'Choose a patch type first.';

  @override
  String get patchType => 'Patch type';

  @override
  String get noPatchesAvailable => 'No patches available';

  @override
  String get noPatchesAvailableDescription =>
      'This game has no entry in the configured network patch table.';

  @override
  String get gamePatchDownloadFooter =>
      'The downloaded archive is extracted to the application downloads folder. Nothing is copied into the game.';

  @override
  String downloadingPatch(String label) {
    return 'Downloading $label';
  }

  @override
  String get downloadPatch => 'Download patch';

  @override
  String patchDownloadComplete(String files, String size, String path) {
    return 'Downloaded $files files ($size) to $path.';
  }

  @override
  String patchDownloadFailed(String error) {
    return 'Patch download failed: $error';
  }

  @override
  String get patchExtracted => 'Patch extracted';

  @override
  String virtualMachinePatch(String buildId) {
    return 'Virtual machine (BuildID: $buildId)';
  }

  @override
  String get v38Patch => 'V38 patch';

  @override
  String get onlinePatch => 'Online patch (fix)';

  @override
  String get offlinePatch => 'Offline patch (crack)';

  @override
  String get vbsPatch => 'VBS patch';

  @override
  String get searchFiles => 'Search files';

  @override
  String get verifyGameFiles => 'Verify game files';

  @override
  String get verificationTarget => 'Verification target';

  @override
  String get gameDirectoryUnavailable => 'The game directory is unavailable.';

  @override
  String get verificationEmptyDescription =>
      'The verification uses appmanifest and local depotcache manifests. Unexpected files are suggestions and are never deleted automatically.';

  @override
  String get startVerification => 'Start verification';

  @override
  String get filesMatchManifests => 'Files match the installed manifests';

  @override
  String filesNeedAttention(String count) {
    return '$count files need attention';
  }

  @override
  String verifiedCount(String count) {
    return 'Verified $count';
  }

  @override
  String missingCount(String count) {
    return 'Missing $count';
  }

  @override
  String changedCount(String count) {
    return 'Changed $count';
  }

  @override
  String unexpectedCount(String count) {
    return 'Unexpected $count';
  }

  @override
  String unverifiedCount(String count) {
    return 'Unverified $count';
  }

  @override
  String manifestSummary(String depots, String manifests) {
    return '$depots depots · $manifests manifests parsed';
  }

  @override
  String get manifestNotes => 'Manifest notes';

  @override
  String get manifestVerificationWarning =>
      'Encrypted manifests need the depot key from the game Lua file. Files that cannot be compared are reported here.';

  @override
  String get manifestInventoryOnly =>
      'Manifest data is unavailable; showing a file inventory only';

  @override
  String get manifestPartialSummary =>
      'Some depots were checked; unmatched files require manual review';

  @override
  String get allFiles => 'All files';

  @override
  String get issuesOnly => 'Issues';

  @override
  String get unexpectedFiles => 'Unexpected files';

  @override
  String get noMatchingFiles => 'No matching files';

  @override
  String get verificationResults => 'Verification results';

  @override
  String get unexpectedFilesHint =>
      'Unexpected files are suggestions only. Review them before changing anything.';

  @override
  String get unverifiedFilesHint =>
      'Files from depots without readable manifests cannot be classified as unexpected.';

  @override
  String get verified => 'Verified';

  @override
  String get changed => 'Changed';

  @override
  String get unexpected => 'Unexpected';

  @override
  String get unverified => 'Unverified';

  @override
  String expectedSize(String size) {
    return 'Expected $size bytes';
  }

  @override
  String actualSize(String size) {
    return 'Actual $size bytes';
  }

  @override
  String get emulatorNotDownloaded => 'No Goldberg release is cached.';

  @override
  String currentEmulatorVersion(String version) {
    return 'Cached version: $version';
  }

  @override
  String get goldbergDeployDescription =>
      'Replace the Steam API DLLs found in this game with the cached Goldberg build.';

  @override
  String get connectionAndIdentity => 'Connection and identity';

  @override
  String get steamId => 'SteamID';

  @override
  String get dlcIds => 'DLC IDs';

  @override
  String get depotIds => 'Depot IDs';

  @override
  String get steamInterfaces => 'Steam interfaces';

  @override
  String get steamInput => 'Steam Input';

  @override
  String get contentConfiguration => 'Content configuration';

  @override
  String get behavior => 'Behavior';

  @override
  String get configurationActions => 'Configuration actions';

  @override
  String get jsonDefinitions => 'JSON definitions';

  @override
  String get luaExtraction => 'Lua extraction';

  @override
  String get luaExtractionDescription =>
      'Query the selected Steam app, fetch its authorized depot keys and write a Lua file plus optional manifests. The account must own the game.';

  @override
  String get denuvoTicketExtraction => 'Denuvo ticket extraction';

  @override
  String get denuvoTicketExtractionDescription =>
      'Extract AppTicket and ETicket from the signed-in local Steam user. The account must own the game.';

  @override
  String get steamLoginRequired =>
      'Sign in to Steam before extracting Lua content.';

  @override
  String get useLocalSteamLogin => 'Use local Steam login';

  @override
  String get useLocalSteamLoginDescription =>
      'Read the signed-in Steam account from local.vdf without entering a password.';

  @override
  String get localSteamLoginUnavailable =>
      'No usable local Steam login was found. Start Steam and sign in, or use the manual login below.';

  @override
  String get realOwnershipRequiredNotice =>
      'Real ownership is required: only use extraction for games you personally own. This app does not verify purchases.';

  @override
  String get notSignedIn => 'Not signed in';

  @override
  String get luaLoginDescription =>
      'Extraction will try the local Steam session. You can also sign in from the account page.';

  @override
  String get appIdForExtraction => 'Game AppID';

  @override
  String get outputDirectory => 'Output directory';

  @override
  String get useDefaultOutputDirectory =>
      'Use the application downloads directory';

  @override
  String get extractionTarget => 'Extraction target';

  @override
  String get extractionOptions => 'Extraction options';

  @override
  String get copyAchievements => 'Include local achievement cache';

  @override
  String get extractionResult => 'Extraction result';

  @override
  String extractingLua(String appId) {
    return 'Extracting Lua for AppID $appId';
  }

  @override
  String get extractLua => 'Extract Lua';

  @override
  String luaExtractionComplete(String keys, String manifests) {
    return 'Lua extraction complete · $keys depot keys · $manifests manifests';
  }

  @override
  String get ownershipRequired =>
      'This Steam account does not truly own this game.';

  @override
  String get steamMustBeRunningAndSignedIn =>
      'Start Steam and sign in to the account that owns this game first.';

  @override
  String get outputDirectoryDoesNotExist =>
      'The output directory does not exist.';

  @override
  String get ticketExtractionFileHeader =>
      'Extracted by FlSteamLua. Use the ticket before it expires.';

  @override
  String ticketExtractionComplete(String path) {
    return 'Ticket written to $path';
  }

  @override
  String get ticketExtractionOptions => 'Ticket options';

  @override
  String get extractDenuvoTicket => 'Extract tickets';

  @override
  String get openAuthorizationPage => 'Open authorization page';

  @override
  String get patchesRestore => 'Patches & restore';

  @override
  String get tickets => 'Tickets';

  @override
  String get gameDirectory => 'Game directory';

  @override
  String get selectGameDirectory => 'Select game directory';

  @override
  String get choose => 'Choose';

  @override
  String get patchInstallation => 'Patch installation';

  @override
  String
  get previewFilesBeforeInstallationOriginalsAreBackedUpAndLaterChangesAreCheckedBeforeRest =>
      'Preview files before installation. Originals are backed up, and later changes are checked before restoration.';

  @override
  String get choosePatchArchive => 'Choose patch archive';

  @override
  String get inspectExecutable => 'Inspect executable';

  @override
  String
  get downloadTheUpstreamWindowsReleaseOnDemandDeploymentReplacesExistingSteamApiDllsAndCre =>
      'Download the upstream Windows release on demand. Deployment replaces existing Steam API DLLs and creates a restorable backup; edit configuration in the next tab.';

  @override
  String get downloadUpdateEmulator => 'Download/update emulator';

  @override
  String get deployGoldberg => 'Deploy Goldberg';

  @override
  String
  get replaceSteamApiDllsInThisGameDirectoryOriginalFilesWillBeSavedInApplicationBackups =>
      'Replace Steam API DLLs in this game directory? Original files will be saved in application backups.';

  @override
  String get deployToThisGame => 'Deploy to this game';

  @override
  String get patchBackups => 'Patch backups';

  @override
  String get noPatchBackupsForThisGame => 'No patch backups for this game.';

  @override
  String get restored => 'Restored';

  @override
  String get available => 'Available';

  @override
  String get restore2 => 'Restore';

  @override
  String get inspectPatchArchive => 'Inspect patch archive';

  @override
  String get thisArchiveContainsManifestsOnlyImportItFromTheLibrary =>
      'This archive contains manifests only. Import it from the library.';

  @override
  String get installPatch => 'Install patch';

  @override
  String get restorePatchBackup => 'Restore patch backup';

  @override
  String get restorePatch => 'Restore patch';

  @override
  String get fileHasChanged => 'File has changed';

  @override
  String
  get theseFilesWereModifiedAfterPatchInstallationReplaceThemWithTheOriginalBackupsAnyway =>
      'These files were modified after patch installation. Replace them with the original backups anyway?';

  @override
  String get inspectPeExecutable => 'Inspect PE executable';

  @override
  String
  get aBindSectionWasFoundAutomaticUnpackingIsNotIncludedTheOriginalSteamlessCodeDeclaresCc =>
      'A .bind section was found. Automatic unpacking is not included: the original Steamless code declares CC BY-NC-ND 4.0 and cannot be ported into this GPL distribution. This file was not modified.';

  @override
  String get noBindSectionFoundThisDoesNotIdentifyOtherProtectionTypes =>
      'No .bind section found; this does not identify other protection types.';

  @override
  String get downloadGoldberg => 'Download Goldberg';

  @override
  String get downloadEmulator => 'Download emulator';

  @override
  String get emulatorConfiguration => 'Emulator configuration';

  @override
  String
  get unknownIniKeysArePreservedInputIsValidatedAndConfigurationFilesAreBackedUpBeforeSavin =>
      'Unknown INI keys are preserved. Input is validated and configuration files are backed up before saving.';

  @override
  String get accountName => 'Account name';

  @override
  String get applicationTicketBase64 => 'Application ticket (Base64)';

  @override
  String get languageCode => 'Language code';

  @override
  String get listenPort => 'Listen port';

  @override
  String get localSavePath => 'Local save path';

  @override
  String get supportedLanguages => 'Supported languages';

  @override
  String get customBroadcasts => 'Custom broadcasts';

  @override
  String get disableNetworking => 'Disable networking';

  @override
  String get offlineMode => 'Offline mode';

  @override
  String get allDlc => 'All DLC';

  @override
  String get emulatedCloudSaves => 'Emulated cloud saves';

  @override
  String get createCloudDirectory => 'Create cloud directory';

  @override
  String get experimentalOverlay => 'Experimental overlay';

  @override
  String get saveGoldbergConfiguration => 'Save Goldberg configuration';

  @override
  String get saveConfiguration => 'Save configuration';

  @override
  String get achievementsStatsItemsJson => 'Achievements/stats/items JSON';

  @override
  String get exportZip => 'Export ZIP';

  @override
  String get importConfigurationZip => 'Import configuration ZIP';

  @override
  String get reload2 => 'Reload';

  @override
  String get editJsonDefinitions => 'Edit JSON definitions';

  @override
  String get applyToDraft => 'Apply to draft';

  @override
  String get exportConfiguration => 'Export configuration';

  @override
  String get exportGoldbergConfiguration => 'Export Goldberg configuration';

  @override
  String get importConfiguration => 'Import configuration';

  @override
  String get existingConfigurationWillBeBackedUpBeforeReplacementContinue =>
      'Existing configuration will be backed up before replacement. Continue?';

  @override
  String get importGoldbergConfiguration => 'Import Goldberg configuration';

  @override
  String get authorizationTickets => 'Ticket management';

  @override
  String get authorization => 'Authorization';

  @override
  String get denuvoAuthorization => 'Denuvo ticket management';

  @override
  String get denuvoAuthorizationDescription =>
      'Extract, back up and manage AppTicket and ETicket. Changing authorization identity requires an explicit selection.';

  @override
  String
  get importedTicketsTxtFilesAreCheckedForAppidAndPayloadLengthsLocalBackupsUseCurrentUserW =>
      'Imported tickets.txt files are checked for AppID and payload lengths. Local backups use current-user Windows DPAPI; the Steam registry changes only when you apply a ticket.';

  @override
  String get importTicketsTxt => 'Import tickets.txt';

  @override
  String get importOneTicketFileAtATime =>
      'Import one tickets.txt file at a time.';

  @override
  String get applyToSteam => 'Apply to Steam';

  @override
  String get saveTicketBackup => 'Save encrypted ticket backup';

  @override
  String get encryptedBackup => 'Encrypted backup';

  @override
  String get exportPlaintextFile => 'Export plaintext file';

  @override
  String get encryptedBackups => 'Encrypted backups';

  @override
  String get noSavedTickets => 'No saved tickets.';

  @override
  String get loadTicket => 'Load ticket';

  @override
  String get load => 'Load';

  @override
  String get deleteEncryptedBackup => 'Delete encrypted backup';

  @override
  String get deleteTicketBackup => 'Delete ticket backup';

  @override
  String get validateTicketFile => 'Validate ticket file';

  @override
  String get applySteamTicket => 'Apply tickets';

  @override
  String get thisReplacesExistingAppticketAndEticketValuesForThisGame =>
      'Back up and replace the two tickets for this game, preserving its cached authorization identity by default.';

  @override
  String get applyTicket => 'Write tickets';

  @override
  String get exportPlaintextTicket => 'Export plaintext ticket';

  @override
  String get exportTicket => 'Export ticket';

  @override
  String get configureTheReleaseRepositoryForThisFlutterApplicationFirst =>
      'Configure the release repository for this Flutter application first.';

  @override
  String get checkApplicationUpdates => 'Check application updates';

  @override
  String get setStartupRegistration => 'Set startup registration';

  @override
  String get setSteamOfflineMode => 'Set Steam offline mode';

  @override
  String get selectTheSteamFolderFirst => 'Select the Steam folder first.';

  @override
  String get setFriendPresence => 'Set friend presence';

  @override
  String get backgroundAndSteamPreferences =>
      'Background and Steam preferences';

  @override
  String get readSteamAndStartupState => 'Read Steam and startup state';

  @override
  String get automaticTasks => 'Automatic tasks';

  @override
  String get refreshTheLibraryAutomatically =>
      'Refresh the library automatically';

  @override
  String
  get watchManifestsAndLuaFilesAndScanAtTheSelectedIntervalRefreshManuallyFromTheLibraryWhe =>
      'Watch manifests and Lua files and scan at the selected interval. Refresh manually from the library when disabled.';

  @override
  String get refreshInterval => 'Refresh interval';

  @override
  String seconds(String seconds) {
    return '$seconds seconds';
  }

  @override
  String get checkForApplicationUpdatesAutomatically =>
      'Check for application updates automatically';

  @override
  String
  get checkAtStartupAndEvery24HoursUsingTheConfiguredFlutterApplicationReleaseRepository =>
      'Check when the selected interval has elapsed using the configured Flutter application release repository.';

  @override
  String get applicationUpdateCheckInterval => 'Application update interval';

  @override
  String get checkForKernelUpdatesAutomatically =>
      'Check for kernel updates automatically';

  @override
  String get kernelUpdateCheckInterval => 'Kernel update interval';

  @override
  String get everyHour => 'Every hour';

  @override
  String get everyDay => 'Every day';

  @override
  String everyHours(String hours) {
    return 'Every $hours hours';
  }

  @override
  String everyDays(String days) {
    return 'Every $days days';
  }

  @override
  String get updateKeySubscriptionsAutomatically =>
      'Update key subscriptions automatically';

  @override
  String
  get whenEnabledCheckEnabledSubscriptionsHourlyAndDownloadUpdatesWhenTheirSourceIntervalIs =>
      'When enabled, check enabled subscriptions hourly and download updates when their source interval is due.';

  @override
  String newVersion(String version) {
    return 'New version $version';
  }

  @override
  String get viewReleaseNotesAndDownloadsInSettings =>
      'View release notes and downloads in Settings.';

  @override
  String get startupAndSteam => 'Startup and Steam';

  @override
  String get launchFlsteamluaAtSignIn => 'Launch FlSteamLua at sign-in';

  @override
  String get readTheCurrentStateWithTheRefreshButton =>
      'Read the current state with the refresh button.';

  @override
  String get startWhenTheCurrentUserSignsInToWindows =>
      'Start when the current user signs in to Windows.';

  @override
  String get broadcastPlayStatusToFriends => 'Friend presence for Lua games';

  @override
  String
  get allowTheKernelToShowPlayStatusToSteamFriendsThroughSpacewarDisableToHideTheseBroadcas =>
      'Allow the kernel to show play status to Steam friends through Spacewar. Disable to hide these broadcasts.';

  @override
  String get broadcastStateHasNotBeenReadYet =>
      'Broadcast state has not been read yet.';

  @override
  String get steamOfflineMode => 'Steam offline mode';

  @override
  String
  get setOfflineOptionsForTheMostRecentAccountAppliesOnTheNextSteamLaunchWithoutRestartingS =>
      'Set offline options for the most recent account. Applies on the next Steam launch without restarting Steam automatically.';

  @override
  String get noRecentSteamAccountWasReadSignInToSteamThenRefreshTheState =>
      'No recent Steam account was read. Sign in to Steam, then refresh the state.';

  @override
  String lastBackgroundTaskFailure(String backgroundError) {
    return 'Last background task failure: $backgroundError';
  }

  @override
  String get steamGuardVerification => 'Steam Guard verification';

  @override
  String get enterTheCodeFromYourEmail => 'Enter the code from your email.';

  @override
  String get enterYourSteamMobileAuthenticatorCode =>
      'Enter your Steam mobile authenticator code.';

  @override
  String get approveThisSignInInTheSteamMobileAppThenContinue =>
      'Approve this sign-in in the Steam mobile app, then continue.';

  @override
  String get code => 'Code';

  @override
  String get signInToSteam => 'Sign in to Steam';

  @override
  String get enterAValidAppid => 'Enter a valid AppID';

  @override
  String get selectTheExportFolder => 'Select the export folder';

  @override
  String extractGame(String id) {
    return 'Extract game $id';
  }

  @override
  String get depotKeys => 'Depot keys';

  @override
  String get savedManifests => 'Saved manifests';

  @override
  String get itemsNotCompleted => 'Items not completed';

  @override
  String get filesSaved => 'Files saved';

  @override
  String get steamAccountExtraction => 'Steam account & extraction';

  @override
  String
  get connectToSteamToExportManifestsAccessibleToThisAccountYourPasswordIsUsedOnlyForSignIn =>
      'Connect to Steam to export manifests accessible to this account. Your password is used only for sign-in.';

  @override
  String get connectedToSteam => 'Connected to Steam';

  @override
  String get signOut => 'Sign out';

  @override
  String get signOutAndForgetSession => 'Sign out and forget session';

  @override
  String get accountName2 => 'Account name';

  @override
  String get password => 'Password';

  @override
  String get signIn => 'Sign in';

  @override
  String get restoreSteamSession => 'Restore Steam session';

  @override
  String get useSavedSession => 'Use saved session';

  @override
  String get exportLuaManifests => 'Export Lua & manifests';

  @override
  String get includeAccessibleDlc => 'Include accessible DLC';

  @override
  String get downloadManifestFiles => 'Download manifest files';

  @override
  String get pinCurrentPublicManifestVersions =>
      'Pin current public manifest versions';

  @override
  String get chooseFolderExport => 'Choose folder & export';

  @override
  String get store => 'Store';

  @override
  String get discoverGamesPurchaseAndInstallThroughSteam =>
      'Discover games. Purchase and install through Steam.';

  @override
  String get searchGameTitles => 'Search game titles';

  @override
  String get showAdultContent => 'Show adult content';

  @override
  String get hideAdultContent => 'Hide adult content';

  @override
  String get storeRegion => 'Store region';

  @override
  String get regionChinaMainland => 'Mainland China';

  @override
  String get regionHongKong => 'Hong Kong, China';

  @override
  String get regionTaiwan => 'Taiwan, China';

  @override
  String get regionUnitedStates => 'United States';

  @override
  String get regionJapan => 'Japan';

  @override
  String get regionSouthKorea => 'South Korea';

  @override
  String get regionSingapore => 'Singapore';

  @override
  String get regionUnitedKingdom => 'United Kingdom';

  @override
  String get regionGermany => 'Germany';

  @override
  String get regionFrance => 'France';

  @override
  String get regionCanada => 'Canada';

  @override
  String get regionAustralia => 'Australia';

  @override
  String get regionBrazil => 'Brazil';

  @override
  String get regionRussia => 'Russia';

  @override
  String get regionArgentina => 'Argentina';

  @override
  String get search => 'Search';

  @override
  String get popular => 'Popular';

  @override
  String get newReleases => 'New releases';

  @override
  String get specials => 'Specials';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String get noMatchingGames2 => 'No matching games';

  @override
  String get storeUnavailable => 'Store unavailable';

  @override
  String get reload3 => 'Reload';

  @override
  String ofGames(String itemsCount, String total) {
    return '$itemsCount of $total games';
  }

  @override
  String get loadMore => 'Load more';

  @override
  String get allResultsLoaded => 'All results loaded';

  @override
  String get viewStorePrice => 'View store price';

  @override
  String get viewFixFiles => 'View fix files';

  @override
  String get fixFiles => 'Fix files';

  @override
  String get downloadOnlineFix => 'Download online fix';

  @override
  String get downloaded => 'Downloaded';

  @override
  String get archivePasswordOnlineFixMe => 'Archive password: online-fix.me';

  @override
  String get copyPassword => 'Copy password';

  @override
  String get instructionsOriginalText => 'Instructions (original text)';

  @override
  String get showMore => 'Show more';

  @override
  String get showLess => 'Show less';

  @override
  String get filesAndInstructionsAreSavedInASeparateFolderForEachGame =>
      'Files and instructions are saved in a separate folder for each game.';

  @override
  String get sourcePage => 'Source page';

  @override
  String get parentFolder => 'Parent folder';

  @override
  String get cancelDownload => 'Cancel download';

  @override
  String get download => 'Download';

  @override
  String get noFixFilesAreAvailableInThisDirectory =>
      'No fix files are available in this directory.';

  @override
  String get noMatchingOnlineFixes => 'No matching online fixes';

  @override
  String get noOnlineFixesAvailable =>
      'No online fixes are available right now';

  @override
  String get searchAGameForFixFilesAndInstructions =>
      'Search a game for fix files and instructions';

  @override
  String get sourceOnlineFixMe => 'Source: online-fix.me';

  @override
  String get fixActions => 'Fix actions';

  @override
  String get backToResults => 'Back to results';

  @override
  String get searchOnlineFixes => 'Search online fixes';

  @override
  String get spacewar480Multiplayer => 'Spacewar (480) multiplayer';

  @override
  String
  get withAKernelThatSupportsOst480MultiplayerLaunchOptionsMapTheGameToSpacewarBothPlayersM =>
      'With a kernel that supports OST 480 multiplayer, launch options map the game to Spacewar. Both players must use the same multiplayer method.';

  @override
  String get setup => 'Setup';

  @override
  String
  get message1RightClickTheGameInSteamAndOpenProperties2AddTheOptionBelowToLaunchOptions3St =>
      '1. Right-click the game in Steam and open Properties.\n2. Add the option below to Launch Options.\n3. Start the game. Remove the option to restore the default.';

  @override
  String get copyLaunchOption => 'Copy launch option';

  @override
  String
  get requiresACompatibleKernelAndLobbyBasedGameOnlyOneSuchGameCanRunAtATime =>
      'Requires a compatible kernel and lobby-based game; only one such game can run at a time.';

  @override
  String get downloads => 'Downloads';

  @override
  String get spacewar480 => 'Spacewar (480)';

  @override
  String get previousPage => 'Previous page';

  @override
  String get nextPage => 'Next page';

  @override
  String get goToPage => 'Go to page';

  @override
  String get pageNumber => 'Page';

  @override
  String pageOutOfRange(int totalPages) {
    return 'Enter a page between 1 and $totalPages';
  }

  @override
  String get downloadTrainer => 'Download trainer';

  @override
  String get thisArchiveIsAvailableForDirectDownload =>
      'This archive is available for direct download.';

  @override
  String get addGameBinding => 'Add game binding';

  @override
  String get editGameBinding => 'Edit game binding';

  @override
  String get chooseFromLibrary => 'Choose from library';

  @override
  String get enterAValidAppid2 => 'Enter a valid AppID';

  @override
  String get gameName => 'Game name';

  @override
  String get enterTheGameName => 'Enter the game name';

  @override
  String get gameExecutable => 'Game executable';

  @override
  String get chooseGameExecutable => 'Choose game executable';

  @override
  String get trainerExecutable => 'Trainer executable';

  @override
  String get chooseTrainerExecutable => 'Choose trainer executable';

  @override
  String get useADownloadedTrainer => 'Use a downloaded trainer';

  @override
  String get startAndStopWithTheGame => 'Start and stop with the game';

  @override
  String get deleteTrainer => 'Delete trainer';

  @override
  String get associatedGameBindingsWillAlsoBeRemoved =>
      'Associated game bindings will also be removed.';

  @override
  String get delete => 'Delete';

  @override
  String get searchGameNames => 'Search game names';

  @override
  String get clear => 'Clear';

  @override
  String get recentUpdates => 'Recent updates';

  @override
  String get allTrainers => 'All trainers';

  @override
  String get archive => 'Archive';

  @override
  String get trainers2 => 'trainers';

  @override
  String get loadingFling => 'Loading FLiNG…';

  @override
  String get noMatchingTrainers => 'No matching trainers';

  @override
  String get downloadAgain => 'Download again';

  @override
  String get myTrainers => 'My trainers';

  @override
  String get downloadFolder => 'Download folder';

  @override
  String get noDownloadedTrainers => 'No downloaded trainers';

  @override
  String get downloadFromBrowseThenOpenArchivesToExtractAndBindAnExecutable =>
      'Download from Browse, then open archives to extract and bind an executable.';

  @override
  String get stop3 => 'Stop';

  @override
  String get open => 'Open';

  @override
  String get manageTrainer => 'Manage trainer';

  @override
  String get bindToGame => 'Bind to game';

  @override
  String get openContainingFolder => 'Open containing folder';

  @override
  String get createDesktopShortcut => 'Create desktop shortcut';

  @override
  String get gameAndTrainerBindings => 'Game and trainer bindings';

  @override
  String get addBinding => 'Add binding';

  @override
  String get bindALocalTrainerToAGame => 'Bind a local trainer to a game';

  @override
  String get enabledTrainersStartAndStopWithTheDetectedGameProcess =>
      'Enabled trainers start and stop with the detected game process.';

  @override
  String get launch2 => 'Launch';

  @override
  String get editBinding => 'Edit binding';

  @override
  String get removeBinding => 'Remove binding';

  @override
  String get browse => 'Browse';

  @override
  String get gameBindings => 'Game bindings';

  @override
  String get operationFailed => 'Operation failed';

  @override
  String get chooseOutputFolder => 'Choose output folder';

  @override
  String get luaVdfConversion => 'Lua / VDF conversion';

  @override
  String get writesNewFilesWithoutOverwritingLuaToVdfRequiresAnAppid =>
      'Writes new files without overwriting. Lua to VDF requires an AppID.';

  @override
  String get appidOptional => 'AppID (optional)';

  @override
  String get includeManifestPinsWhenConvertingVdf =>
      'Include manifest pins when converting VDF';

  @override
  String get convert => 'Convert';

  @override
  String get convertFiles => 'Convert files';

  @override
  String get chooseSourceFolder => 'Choose source folder';

  @override
  String get batchConversion => 'Batch conversion';

  @override
  String get pinGameVersion => 'Pin game version';

  @override
  String get pinCurrentlyInstalledManifests =>
      'Pin currently installed manifests';

  @override
  String get pinLatestPublicManifests => 'Pin latest public manifests';

  @override
  String get unpinKeepCommentedRecords => 'Unpin (keep commented records)';

  @override
  String get updateManifestPins2 => 'Update manifest pins';

  @override
  String get addDlcAppids => 'Add DLC AppIDs';

  @override
  String get dlcAppidsSeparatedBySpacesCommasOrNewlines =>
      'DLC AppIDs separated by spaces, commas or newlines';

  @override
  String get addToLua => 'Add to Lua';

  @override
  String get addDlc => 'Add DLC';

  @override
  String get environmentDiagnostics => 'Environment diagnostics';

  @override
  String get manifestMonitorAndDownloadRepair =>
      'Manifest monitor and download repair';

  @override
  String
  get watchNewSteamContentLogRequestsAndDownloadManifestsFromCodeProvidersAndSteamCdnIntoDe =>
      'Watch new Steam content_log requests and download manifests from code providers and Steam CDN into depotcache. Tasks continue across pages.';

  @override
  String get noLogEntriesYet => 'No log entries yet';

  @override
  String get stopMonitoring => 'Stop monitoring';

  @override
  String get startMonitoring => 'Start monitoring';

  @override
  String get tools => 'Tools';

  @override
  String get openToolsAsNeededOrStartFromAGameSDetailPage =>
      'Open tools as needed, or start from a game’s detail page.';

  @override
  String get filesAndManifests => 'Files and manifests';

  @override
  String get convertLuaVdfAndAcfFilesToASeparateOutputFolder =>
      'Convert Lua, VDF and ACF files to a separate output folder';

  @override
  String get convertAFolder => 'Convert a folder';

  @override
  String get processAllSupportedFilesInAFolder =>
      'Process all supported files in a folder';

  @override
  String get manifestMonitoring => 'Manifest request monitoring';

  @override
  String get fetchMissingManifestsRequestedBySteam =>
      'Fetch missing manifests requested by Steam';

  @override
  String get manifestVersionPins => 'Manifest version pins';

  @override
  String get installedManifestsLatestPublicManifestsOrUnpin =>
      'Installed manifests, latest public manifests or unpin';

  @override
  String get appendDlcEntriesWithoutDuplicatingExistingRecords =>
      'Append DLC entries without duplicating existing records';

  @override
  String get downloadCover => 'Download cover';

  @override
  String get saveToTheApplicationCoverCache =>
      'Save to the application cover cache';

  @override
  String get gameTools => 'Game tools';

  @override
  String get searchDownloadAndBindTrainers =>
      'Search, download and bind trainers';

  @override
  String get findOnlineFixesAndDownloadFiles =>
      'Find online fixes and download files';

  @override
  String get openTool => 'Open tool';

  @override
  String get maintenance => 'Maintenance';

  @override
  String get diagnostics => 'Diagnostics';

  @override
  String get steamPathClientAndDataDirectories =>
      'Steam path, client and data directories';

  @override
  String get openLogFolder => 'Open log folder';

  @override
  String get logFolder => 'Log folder';

  @override
  String get openBackupFolder => 'Open backup folder';

  @override
  String get backupFolder => 'Backup folder';

  @override
  String get openFlsteamlua => 'Open FlSteamLua';

  @override
  String get quit => 'Quit';

  @override
  String get collapseSidebar => 'Collapse sidebar';

  @override
  String get expandSidebar => 'Expand sidebar';

  @override
  String get contentSources => 'Content sources';

  @override
  String get allSources => 'All';

  @override
  String get luaSources => 'Lua';

  @override
  String get manifestSources => 'Manifests';

  @override
  String get enabledSources => 'Enabled';

  @override
  String get failedSources => 'Needs attention';

  @override
  String get subscriptionSource => 'Key subscription';

  @override
  String get scriptSource => 'JS script';

  @override
  String get localSource => 'Local';

  @override
  String get manifestIds => 'Manifest IDs';

  @override
  String get manifestFiles => 'Manifest files';

  @override
  String get addContentSource => 'Add content source';

  @override
  String get addSubscriptionSource => 'Add key subscription';

  @override
  String get importScriptSource => 'Import JS content source';

  @override
  String get importLocalContent => 'Import local content';

  @override
  String get editSource => 'Edit';

  @override
  String get editScript => 'Edit script';

  @override
  String get configureSource => 'Configure source';

  @override
  String get validateScript => 'Validate script';

  @override
  String get restoreBuiltInScript => 'Restore built-in script';

  @override
  String get openScriptFolder => 'Open script folder';

  @override
  String get scriptSaved => 'Script saved';

  @override
  String get scriptIsValid => 'Script syntax and metadata are valid';

  @override
  String get theseScriptChangesHaveNotBeenSaved =>
      'These script changes have not been saved.';

  @override
  String get testSource => 'Test';

  @override
  String get updateSource => 'Update';

  @override
  String get enableSource => 'Enable';

  @override
  String get disableSource => 'Disable';

  @override
  String get deleteSource => 'Delete';

  @override
  String get deleteSourceConfirm =>
      'Delete this content source and its local configuration?';

  @override
  String get sourceConfigurationRequired => 'Setup required';

  @override
  String get sourceConfigured => 'Configured';

  @override
  String get sourceNotTested => 'Configured; not tested yet';

  @override
  String get sourceNeverUpdated => 'Not updated';

  @override
  String get noContentSources => 'No content sources yet';

  @override
  String get contentImport => 'Add to Lua library';

  @override
  String get luaContentSource => 'Lua content source';

  @override
  String get manifestContentSource => 'Manifest source (optional)';

  @override
  String get noManifestSource =>
      'None; let Steam or the kernel retrieve manifests';

  @override
  String get previewContent => 'Preview content';

  @override
  String get importContent => 'Import';

  @override
  String get contentImportComplete => 'Import complete';

  @override
  String get contentImportReplace => 'Replace existing files and back up';

  @override
  String get configureContentSources => 'Manage content sources';

  @override
  String get sourceName => 'Name';

  @override
  String get depotKeysUrl => 'Depot keys JSON URL';

  @override
  String get appTokensUrl => 'App tokens JSON URL';

  @override
  String get addressSourceMode => 'Address source';

  @override
  String get useFixedLinks => 'Fixed links';

  @override
  String get useDynamicScript => 'Script';

  @override
  String get dynamicSubscriptionSource => 'Dynamic address script';

  @override
  String get editDynamicScript => 'Edit dynamic script';

  @override
  String get dynamicSubscriptionScriptConfigured => 'Configured';

  @override
  String get dynamicSubscriptionScriptNotConfigured => 'Not configured';

  @override
  String get dynamicSubscriptionScriptDescription =>
      'Runs custom JavaScript before every update. Define async function download(ctx) and return depotKeysUrl and tokenKeysUrl.';

  @override
  String get sourceUpdateInterval => 'Update interval (hours)';

  @override
  String get sourceEnabled => 'Enable this content source';

  @override
  String get requiredField => 'Required';

  @override
  String get invalidUrl => 'Enter an HTTP or HTTPS URL';

  @override
  String get invalidUpdateInterval => 'Enter a whole number from 0 to 8760.';

  @override
  String get sourceTestSucceeded => 'Test succeeded';

  @override
  String get sourceUpdateComplete => 'Update complete';

  @override
  String get includeDlc => 'Include DLC';

  @override
  String get pinManifestVersions => 'Pin manifest versions';

  @override
  String get refreshContentMetadata => 'Refresh depot metadata online';

  @override
  String get contentImportNoLuaSource =>
      'Add or enable a content source that provides Lua first';

  @override
  String get originalCoverUrl => 'Original cover URL';

  @override
  String get steamStoreApi => 'Steam Store API';

  @override
  String get heyboxApi => 'Heybox API';

  @override
  String get akamaiMain => 'Akamai main';

  @override
  String get akamaiBackup => 'Akamai backup';

  @override
  String get cloudflareCdn => 'Cloudflare CDN';

  @override
  String get akamaiPortrait => 'Akamai portrait';

  @override
  String get contentImportNoLocalLua =>
      'No Lua configuration with a valid addappid was found. Manifest files alone cannot add a game.';

  @override
  String get contentImportPerGame =>
      'Each game is imported independently. Failed games are listed without undoing successfully imported games.';

  @override
  String get settings => 'Settings';

  @override
  String get tools2 => 'Tools';

  @override
  String get downloadManageTrainers => 'Download & manage trainers';

  @override
  String get addLuaFromAContentSource => 'Add Lua from a content source';

  @override
  String get accountExtraction => 'Account & extraction';

  @override
  String get patchesLicenses => 'Patches & licenses';

  @override
  String get manageAchievements2 => 'Manage achievements';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get showPanel => 'Show panel';

  @override
  String get hidePanel => 'Hide panel';

  @override
  String get accountExtraction2 => 'Account & extraction';

  @override
  String get steamAccount => 'Steam account';

  @override
  String get accountManagement => 'Account management';

  @override
  String get steamAccounts => 'Steam accounts';

  @override
  String get addSteamAccount => 'Add Steam account';

  @override
  String get addSteamAccountDescription =>
      'Open Steam\'s own sign-in flow. FlSteamLua never asks for your Steam password.';

  @override
  String get currentSteamAccount => 'Current';

  @override
  String get switchSteamAccount => 'Switch account';

  @override
  String get steamWillRestartToSwitchAccount =>
      'Steam will restart and switch to this account.';

  @override
  String get steamWillOpenItsOwnLogin =>
      'Steam will open its own sign-in flow. Sign in there, then return and refresh the account list.';

  @override
  String get noSteamAccounts => 'No Steam accounts found';

  @override
  String get noSteamAccountsDescription =>
      'Start Steam and sign in, then refresh this page.';

  @override
  String get accountManagerHint =>
      'Switching accounts restarts Steam. Account credentials stay inside Steam.';

  @override
  String get chooseAFolder => 'Choose a folder';

  @override
  String get chooseTheSteamInstallationFolderContainingSteamExe =>
      'Choose the Steam installation folder containing steam.exe.';

  @override
  String get theLuaFolderDoesNotExistChooseAnExistingFolder =>
      'The Lua folder does not exist. Choose an existing folder.';

  @override
  String get refreshGameLibrary => 'Refresh game library';

  @override
  String get pathsSavedAndGameLibraryRefreshed =>
      'Paths saved and game library refreshed.';

  @override
  String get useOwnerRepositoryForExampleYournameFlsteamlua =>
      'Use owner/repository, for example yourname/FlSteamLua.';

  @override
  String get theFlsteamluaReleaseRepositoryIsNotConfigured =>
      'The FlSteamLua release repository is not configured.';

  @override
  String get youAreUsingTheLatestPublishedVersion =>
      'You are using the latest published version.';

  @override
  String get noReleaseNotesWereProvided => 'No release notes were provided.';

  @override
  String get later => 'Later';

  @override
  String get releasePage => 'Release page';

  @override
  String get downloadUpdate => 'Download update';

  @override
  String get downloadApplicationUpdate => 'Download application update';

  @override
  String updateDownloaded(String path) {
    return 'Update downloaded: $path';
  }

  @override
  String get updateReadyTitle => 'Update ready';

  @override
  String get updateReadyDescription =>
      'The download was verified. Close FlSteamLua on the next step and run the installer now?';

  @override
  String get installUpdateNow => 'Install now';

  @override
  String get openFolder2 => 'Open folder';

  @override
  String get makeYourGameCompanionFeelAtHome =>
      'Make your game companion feel at home.';

  @override
  String get steamAndGameFiles => 'Steam and game files';

  @override
  String get steamInstallationFolder => 'Steam installation folder';

  @override
  String get theFolderContainingSteamExe => 'The folder containing steam.exe';

  @override
  String get luaFolder => 'Lua folder';

  @override
  String get saveAndRefreshLibrary => 'Save and refresh library';

  @override
  String get appearanceAndInteraction => 'Appearance and interaction';

  @override
  String get theme => 'Theme';

  @override
  String get followTheSystemOrChooseALightOrDarkAppearance =>
      'Follow the system or choose a light or dark appearance.';

  @override
  String get system => 'System';

  @override
  String get light => 'Light';

  @override
  String get dark => 'Dark';

  @override
  String get displayLanguage => 'Display language';

  @override
  String get appliesImmediatelyWithoutRestarting =>
      'Applies immediately without restarting.';

  @override
  String get expandedSidebar => 'Expanded sidebar';

  @override
  String get showDestinationLabelsAlongsideIcons =>
      'Show destination labels alongside icons.';

  @override
  String get keepRunningInTheTray => 'Keep running in the tray';

  @override
  String get keepBackgroundTasksRunningQuitFromTheTrayMenu =>
      'Keep background tasks running; quit from the tray menu.';

  @override
  String get closeSteamToContinue => 'Close Steam to continue';

  @override
  String get closeSteamToContinueDescription =>
      'This change updates Steam files. Steam and its game processes must be closed before the change can continue.';

  @override
  String get closeAndContinue => 'Close and continue';

  @override
  String get steamClient => 'Steam client';

  @override
  String get steamClientRunning => 'Running';

  @override
  String get steamClientNotRunning => 'Not running';

  @override
  String get steamClientChecking => 'Checking...';

  @override
  String get steamUpdateControl => 'Steam update control';

  @override
  String get steamUpdateControlDescription =>
      'Manage Steam client update behavior globally.';

  @override
  String get disableSteamUpdateCheck => 'Disable Steam update checks';

  @override
  String get disableSteamForcedUpdate => 'Disable forced Steam updates';

  @override
  String get notEnabled => 'Not enabled';

  @override
  String get startSteam => 'Start Steam';

  @override
  String get stopSteam => 'Close Steam';

  @override
  String get restartSteam => 'Restart Steam';

  @override
  String get automaticRefreshUpdateChecksFriendPresenceStartupAndOfflineMode =>
      'Automatic refresh, update checks, startup and offline mode.';

  @override
  String get downloadsKernelAndAccount => 'Downloads, kernel and account';

  @override
  String
  get manageSubscriptionsScriptsAndTheirLuaManifestIdAndManifestFileCapabilities =>
      'Manage subscriptions, scripts and their Lua, manifest ID and manifest file capabilities.';

  @override
  String get kernelManager => 'Kernel manager';

  @override
  String get downloadImportOrSwitchKernelsAndRestoreBackups =>
      'Download, import or switch kernels and restore backups.';

  @override
  String get steamAccountAndExtraction => 'Steam account and extraction';

  @override
  String get signInVerifySteamGuardAndExtractLicensedContent =>
      'Sign in, verify Steam Guard and extract licensed content.';

  @override
  String get chooseCoverAndGithubDownloadSourcesAndTestTheirLatency =>
      'Choose cover and GitHub download sources and test their latency.';

  @override
  String get applicationUpdates => 'Application updates';

  @override
  String get flsteamluaReleaseRepository => 'FlSteamLua release repository';

  @override
  String get useTheReleaseRepositoryForThisFlutterApplication =>
      'Use the release repository for this Flutter application.';

  @override
  String get saveRepository => 'Save repository';

  @override
  String get checkForUpdates => 'Check for updates';

  @override
  String viewNewVersion(String value1) {
    return 'View new version $value1';
  }

  @override
  String get aboutFlsteamlua => 'About FlSteamLua';

  @override
  String get anOpenSourceDesktopCompanionForYourLibraryAchievementsAndSaves =>
      'An open-source desktop companion for your library, achievements and saves.';

  @override
  String
  get uiComponentsAndMotionAreAdaptedFromFlclashFeaturesAreBasedOnFluentSteamLuaAndReimplem =>
      'UI components and motion are adapted from FlClash. Features are based on Fluent-Steam-Lua and reimplemented in Flutter and Dart.';

  @override
  String get openSourceLicenses => 'Open-source licenses';

  @override
  String get browseFolders => 'Browse folders';

  @override
  String get stopGame2 => 'Stop game';

  @override
  String get updateSubscriptionCaches => 'Update subscription caches';

  @override
  String get refreshLibrary => 'Refresh library';

  @override
  String enabled3(String enabledLua) {
    return '$enabledLua enabled';
  }

  @override
  String get manageLua => 'Manage Lua';

  @override
  String get steamLibrary => 'Steam library';

  @override
  String running2(String runningCount) {
    return '$runningCount running';
  }

  @override
  String get steamIsNotConnected => 'Steam is not connected';

  @override
  String get openLibrary => 'Open library';

  @override
  String get kernel => 'Kernel';

  @override
  String get couldNotReadKernel => 'Could not read kernel';

  @override
  String get detectingKernel => 'Detecting kernel';

  @override
  String get notInstalled => 'Not installed';

  @override
  String get manageKernel => 'Manage kernel';

  @override
  String enabled4(String enabledSources) {
    return '$enabledSources enabled';
  }

  @override
  String get someSourcesNeedConfigurationOrTesting =>
      'Some sources need configuration or testing';

  @override
  String get manageSources => 'Manage sources';

  @override
  String get updateCaches => 'Update caches';

  @override
  String get running3 => 'Running';

  @override
  String get viewTasks => 'View tasks';

  @override
  String get activeTasks => 'Active tasks';

  @override
  String get continuePlaying => 'Continue playing';

  @override
  String get allGames => 'All games';

  @override
  String get cancelling2 => 'Cancelling';

  @override
  String get cancelTask => 'Cancel task';

  @override
  String get enterAValidAppid3 => 'Enter a valid AppID.';

  @override
  String dlcAnalysis2(String appId) {
    return 'DLC management: $appId';
  }

  @override
  String get dlcDepotStructure => 'DLC depot structure';

  @override
  String get allDlcStructures => 'All structures';

  @override
  String get confirmDlcAdditions => 'Confirm DLC additions';

  @override
  String
  get theExistingLuaWillBeBackedUpOnlyTheSelectedLinesBelowAreAppendedExistingScriptsKeysAn =>
      'The existing Lua will be backed up. Only the selected lines below are appended; existing scripts, keys and manifest pins are preserved. This does not establish Steam account ownership.';

  @override
  String get backUpAndAppend => 'Back up and append';

  @override
  String saveDlcSuggestions(String appId) {
    return 'Save DLC suggestions: $appId';
  }

  @override
  String appendedLinesAnalyzeAgainToVerifyTheCurrentConfiguration(
    String count,
  ) {
    return 'Appended $count lines. Analyze again to verify the current configuration.';
  }

  @override
  String get queryFailedUnknown => 'Query failed / unknown';

  @override
  String get noIndependentDepot => 'No independent depot';

  @override
  String get singleDepot => 'Single depot';

  @override
  String get multipleDepots => 'Multiple depots';

  @override
  String get inTheMainGame => 'In the main game';

  @override
  String
  get compareSteamDepotMetadataWithTheCurrentLuaAndTheContentSourceSelectedForThisAnalysisP =>
      'Compare Steam depot metadata with the current Lua and the content source selected for this analysis. Preview the DLC configuration before appending.';

  @override
  String get contentSourceOptional => 'Content source (optional)';

  @override
  String get doNotUseAContentSourceCache => 'Do not use a content source cache';

  @override
  String get contentSourceSubscriptionOptional =>
      'Content-source subscription (optional)';

  @override
  String get doNotUseASubscriptionCache => 'Do not use a subscription cache';

  @override
  String get existingLuaFile => 'Existing Lua file';

  @override
  String get leaveEmptyToSearchTheConfiguredLuaFolderOrSelectADisabledLuaFile =>
      'Leave empty to search the configured Lua folder, or select a disabled Lua file.';

  @override
  String get chooseLua => 'Choose Lua';

  @override
  String get analyzeDlc => 'Refresh DLC';

  @override
  String get previewDlcChanges => 'Preview Lua changes';

  @override
  String mainDepotsDlcReferencedByLua(String mainDepotCount, String value2) {
    return '$mainDepotCount main depots · $value2 DLC referenced by Lua.';
  }

  @override
  String get allLayouts => 'All layouts';

  @override
  String get steamReturnedNoDlcForThisGame =>
      'Steam returned no DLC for this game.';

  @override
  String get referenced => 'referenced';

  @override
  String get notConfigured => 'not configured';

  @override
  String luaSuggestedLines(String value1, String suggestionsCount) {
    return 'Lua $value1 · $suggestionsCount suggested lines';
  }

  @override
  String missingKeysSkipped(String join) {
    return 'Missing keys, skipped: $join';
  }

  @override
  String get selectedAdditions => 'Selected additions';

  @override
  String get noLinesSelected => 'No lines selected.';

  @override
  String get copySuggestions => 'Copy suggestions';

  @override
  String get previewAndAppendToLua => 'Preview and append to Lua';

  @override
  String get free => 'Free';

  @override
  String get pinWindow => 'Pin window';

  @override
  String get unpinWindow => 'Unpin window';

  @override
  String get minimizeWindow => 'Minimize';

  @override
  String get maximizeWindow => 'Maximize';

  @override
  String get restoreWindow => 'Restore';

  @override
  String get closeWindow => 'Close';

  @override
  String get layout => 'Layout';

  @override
  String get comfortable => 'Comfortable';

  @override
  String get standard => 'Standard';

  @override
  String get compact => 'Compact';

  @override
  String get themeMode => 'Theme mode';

  @override
  String get themeColor => 'Theme color';

  @override
  String get pureBlackMode => 'Pure black mode';

  @override
  String get pureBlack => 'Pure black';

  @override
  String get colorStyle => 'Palette style';

  @override
  String get vivid => 'Vivid';

  @override
  String get tinted => 'Tinted';

  @override
  String get soft => 'Soft';

  @override
  String get monochrome => 'Monochrome';

  @override
  String get navigationBarStyle => 'Sidebar style';

  @override
  String get floating => 'Floating';

  @override
  String get docked => 'Docked';

  @override
  String get tabAnimation => 'Page transition';

  @override
  String get slide => 'Slide';

  @override
  String get fade => 'Fade';

  @override
  String get liquidGlass => 'Liquid glass';

  @override
  String get none => 'None';

  @override
  String get ultra => 'Ultra';

  @override
  String get sidebar => 'Sidebar';

  @override
  String get backgroundBlur => 'Background blur';

  @override
  String get sidebarBlurDesc => 'Blur the desktop behind a floating sidebar.';

  @override
  String get fontFamily => 'Font';

  @override
  String get defaultText => 'Default';

  @override
  String get textScale => 'Text scale';

  @override
  String get followSystem => 'Follow system';

  @override
  String get custom => 'Custom';

  @override
  String get textScalePreview => 'Text in the app will use this size.';

  @override
  String get customColor => 'Custom color';

  @override
  String get reset => 'Reset';

  @override
  String get resetTip => 'Restore the default FlClash-style appearance?';

  @override
  String get backgroundStyle => 'Background style';

  @override
  String get grid => 'Grid';

  @override
  String get spectrum => 'Spectrum';

  @override
  String get sliders => 'Sliders';

  @override
  String get hue => 'Hue';

  @override
  String get saturation => 'Saturation';

  @override
  String get brightness => 'Brightness';

  @override
  String get hex => 'Hex';

  @override
  String get color => 'Color';

  @override
  String get edit => 'Edit';

  @override
  String get installedFonts => 'Installed fonts';

  @override
  String get deleteColorTip => 'Delete this custom color?';

  @override
  String get general => 'General';

  @override
  String get other => 'Other';

  @override
  String get add => 'Add';

  @override
  String get auto => 'Auto';

  @override
  String get tip => 'Tip';

  @override
  String get basicInfo => 'Basic information';

  @override
  String get cloudConnection => 'Connection';

  @override
  String get credentials => 'Credentials';

  @override
  String get advanced => 'Advanced';

  @override
  String get url => 'URL';

  @override
  String get endpoint => 'Endpoint';

  @override
  String get region => 'Region';

  @override
  String get bucket => 'Bucket';

  @override
  String get accountId => 'Account ID';

  @override
  String get accessKeyId => 'Access key ID';

  @override
  String get secretAccessKey => 'Secret access key';

  @override
  String get keyPrefix => 'Key prefix';

  @override
  String get extraHeaders => 'Extra headers';

  @override
  String get timeoutSeconds => 'Timeout (seconds)';

  @override
  String get optional => 'Optional';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String sourceDefinitionNotFound(Object sourceId) {
    return 'Source definition not found: $sourceId';
  }

  @override
  String get kernelOverview => 'Kernel overview';

  @override
  String get kernelStateHealthy => 'Ready';

  @override
  String get kernelStateDisabled => 'Disabled';

  @override
  String get kernelStateMissingEntry => 'Injection entry missing';

  @override
  String get kernelStateConflict => 'Injection entry conflict';

  @override
  String get kernelStateNotInstalled => 'Not installed';

  @override
  String get kernelVersion => 'Version';

  @override
  String kernelUpdateAvailable(Object version) {
    return 'Version $version is available';
  }

  @override
  String get kernelUpToDate => 'Up to date';

  @override
  String get checkKernelUpdate => 'Check for kernel updates';

  @override
  String get installOrUpdateKernel => 'Install, update or repair kernel';

  @override
  String get installAndRuntime => 'Install and runtime';

  @override
  String get repositorySubscription => 'Repository subscription';

  @override
  String get localKernelPackage => 'Local kernel package';

  @override
  String get kernelRepository => 'Kernel repository';

  @override
  String get kernelRepositoryHint =>
      'owner/repository or a GitHub repository URL';

  @override
  String get repositoryMainline => 'Mainline repository';

  @override
  String get repositoryFork => 'Fork';

  @override
  String get defaultBranch => 'Default branch';

  @override
  String get lastPush => 'Last push';

  @override
  String get kernelLocalNoUpdates =>
      'Local kernel packages do not check for updates';

  @override
  String get releaseAnnouncement => 'Release notes';

  @override
  String get manifestSettings => 'Manifest request codes';

  @override
  String get manifestProvider => 'Manifest provider';

  @override
  String get manifestModeBuiltIn => 'Built-in provider';

  @override
  String get manifestModeCustom => 'Custom server (through this app)';

  @override
  String get manifestModeLocalProxy => 'Local proxy';

  @override
  String get manifestUrlTemplate => 'Manifest URL template';

  @override
  String get manifestHeader => 'Request header';

  @override
  String get manifestFormat => 'Response format';

  @override
  String get manifestFailover => 'Fail over between providers';

  @override
  String get manifestRequestCodes => 'Manifest request codes';

  @override
  String get noManifestCodeSources =>
      'No enabled content source can provide manifest request codes';

  @override
  String get selectAtLeastOneManifestCodeSource =>
      'Select at least one manifest request-code source';

  @override
  String get manifestLocalProxyDescription =>
      'Resolve the current depot/GID through the selected scripts while this app stays running. The core may still use a built-in source if scripts fail.';

  @override
  String get manifestCustomHint =>
      'Include a gid or manifestId placeholder; appId and depotId are optional. Keep this app running; the core can fall back to a built-in source.';

  @override
  String get steamClientDataChannel => 'Steam client data channel';

  @override
  String get channelRepository => 'Data repository';

  @override
  String get channelName => 'Git branch';

  @override
  String get channelFormat => 'Repository format';

  @override
  String get channelFormatBranch => 'Separate pattern / ipc branches';

  @override
  String get channelFormatDirectory =>
      'Pattern / ipc directories in one branch';

  @override
  String get defaultRepository => 'Default';

  @override
  String get customRepository => 'Custom repository';

  @override
  String get localTemporaryBuild => 'Local emergency build';

  @override
  String get localTemporaryBuildDescription =>
      'Scan the current Steam files using bundled signatures and write temporary metadata only when matches are complete. Unknown builds may not be supported.';

  @override
  String get localBuildTitle => 'Local emergency build';

  @override
  String get localBuildIdleDescription =>
      'Read the installed Steam DLLs and generate temporary signature files for this exact Steam build.';

  @override
  String get localBuildSteamDlls => 'Steam DLLs';

  @override
  String localBuildDllLocated(String name, String size, String path) {
    return '$name · $size · $path';
  }

  @override
  String localBuildHashComputed(String name, String sha) {
    return '$name SHA256 · $sha';
  }

  @override
  String localBuildPatternScan(String component) {
    return 'Resolving $component hooks';
  }

  @override
  String localBuildHookResolved(String name, String rva, String bytes) {
    return '$name → $rva · $bytes byte signature';
  }

  @override
  String localBuildHookMissing(String name) {
    return '$name · no unique match';
  }

  @override
  String localBuildComponentWritten(
    String component,
    String resolved,
    String total,
  ) {
    return '$component · $resolved/$total written';
  }

  @override
  String localBuildComponentRejected(
    String component,
    String resolved,
    String total,
  ) {
    return '$component · $resolved/$total; existing file was not overwritten';
  }

  @override
  String localBuildIpcWrapper(String name, String rva) {
    return '$name · wrapper $rva';
  }

  @override
  String localBuildIpcVtable(String name, String rva) {
    return '$name · vtable $rva';
  }

  @override
  String localBuildCompleted(String written, String total) {
    return '$written/$total files written';
  }

  @override
  String get localBuildStart => 'Start build';

  @override
  String get localBuildRestart => 'Build again';

  @override
  String get localBuildLog => 'Build log';

  @override
  String get localBuildCloseSteam =>
      'Close Steam before starting the local build.';

  @override
  String get kernelEntryDwmapiDescription =>
      'Best compatibility and the recommended daily entry';

  @override
  String get kernelEntryVersionDescription =>
      'Useful when a first-load isolation entry is required';

  @override
  String get kernelActions => 'Kernel actions';

  @override
  String get kernelResidualScan => 'Scan kernel residuals';

  @override
  String get kernelResidualScanDescription =>
      'Read-only scan of known kernel files and folders; clean only after confirmation';

  @override
  String get kernelUpdateCheckOnStartup =>
      'Check for kernel updates at startup';

  @override
  String get kernelUpdateCheckOnStartupDescription =>
      'Show when the installed kernel has a newer official release';

  @override
  String get kernelLatest => 'Latest';

  @override
  String get kernelScanTitle => 'Kernel residuals';

  @override
  String kernelScanSummary(Object cleanable, Object count, Object size) {
    return '$count items found, $cleanable cleanable, $size';
  }

  @override
  String get kernelResidualOpenSteamTool => 'OpenSteamTool';

  @override
  String get kernelResidualOpenSteamToolDescription =>
      'OpenSteamTool core files, configuration, or cached data';

  @override
  String get kernelResidualSteamTools => 'SteamTools';

  @override
  String get kernelResidualSteamToolsDescription =>
      'SteamTools injection DLLs or plugin data';

  @override
  String get kernelResidualTbBiao => 'TB / BIAO';

  @override
  String get kernelResidualTbBiaoDescription =>
      'TB/BIAO or GreenLuma injection files';

  @override
  String get kernelResidualSteamConfig => 'Steam configuration';

  @override
  String get kernelResidualSteamConfigDescription =>
      'Steam settings that may disable updates or change startup behavior';

  @override
  String get kernelResidualInfo => 'Info';

  @override
  String get kernelResidualWarning => 'Warning';

  @override
  String get kernelResidualHigh => 'High risk';

  @override
  String get kernelResidualCanClean => 'Cleanable';

  @override
  String get kernelResidualReportOnly => 'Report only';

  @override
  String get kernelResidualDirectory => 'Folder';

  @override
  String get kernelResidualFile => 'File';

  @override
  String get kernelResidualBackupAndClean => 'Back up and clean';

  @override
  String get kernelResidualRescan => 'Rescan';

  @override
  String get kernelResidualNoResults => 'No known kernel residuals were found';

  @override
  String get kernelResidualSelectCleanable => 'Select cleanable items';

  @override
  String kernelResidualCleanupCompleted(Object count) {
    return 'Backed up and removed $count residual items';
  }

  @override
  String kernelResidualCleanupPartial(Object deleted, Object failed) {
    return 'Removed $deleted; $failed failed';
  }

  @override
  String get kernelTomlPreviewTitle => 'Fetch Steam signatures';

  @override
  String get kernelBuildId => 'Build ID';

  @override
  String get kernelClientSha => 'steamclient64 SHA256';

  @override
  String get kernelUiSha => 'steamui SHA256';

  @override
  String get kernelTomlFiles => 'Signatures to fetch';

  @override
  String get kernelStartFetch => 'Start fetching';

  @override
  String get kernelTomlResults => 'Signature results';

  @override
  String get kernelTomlReady => 'Fetched';

  @override
  String get kernelTomlNoUpstream => 'Not published upstream';

  @override
  String get kernelTomlFailed => 'Failed';

  @override
  String get kernelNoUpdate => 'No update is available';

  @override
  String get injectionEntry => 'Injection entry';

  @override
  String get selectAnOutputFolder => 'Choose an output folder.';

  @override
  String get chooseFilesToConvert => 'Choose at least one file to convert.';

  @override
  String get noSupportedFilesFound =>
      'No supported Lua, VDF or ACF files were found.';

  @override
  String convertedFileCount(String count) {
    return 'Converted $count files.';
  }

  @override
  String get conversionOptions => 'Conversion options';

  @override
  String fileCount(String count) {
    return '$count files selected';
  }

  @override
  String get noFilesSelected => 'No files selected';

  @override
  String get chooseLuaVdfOrAcfFiles =>
      'Choose Lua, VDF or ACF files. Existing output files are never overwritten.';

  @override
  String get chooseFiles => 'Choose files';

  @override
  String get notSelected => 'Not selected';

  @override
  String get monitorRunning => 'Monitoring Steam content requests';

  @override
  String get monitorStopped => 'Manifest monitor is stopped';

  @override
  String get activityLog => 'Activity log';

  @override
  String depotEntryCount(String count) {
    return '$count depot entries';
  }

  @override
  String get pinInstalledDescription =>
      'Use the manifest IDs already recorded by the installed Steam app.';

  @override
  String get latestPublicDescription =>
      'Read the latest public manifest IDs from SteamCMD metadata.';

  @override
  String get unpinDescription =>
      'Comment out manifest pins while retaining them for later recovery.';

  @override
  String get depotEntries => 'Depot entries';

  @override
  String get pinned => 'Pinned';

  @override
  String get notPinned => 'Not pinned';

  @override
  String get noDepotEntries => 'No depot entries were found in this Lua file.';

  @override
  String get manifestPinFooter =>
      'Changes are written to the game\'s Lua file after creating a backup.';

  @override
  String get enterValidDlcAppIds => 'Enter one or more valid DLC AppIDs.';

  @override
  String addedDlcCount(String count) {
    return 'Added $count DLC entries.';
  }

  @override
  String get removeDlc => 'Remove DLC entry';

  @override
  String removedDlcEntry(String appId) {
    return 'Removed AppID $appId.';
  }

  @override
  String get luaEntries => 'Lua entries';

  @override
  String diagnosticsSummary(String passed, String total) {
    return '$passed of $total checks passed';
  }

  @override
  String get missing => 'Missing';

  @override
  String get noDiagnosticsFound => 'No diagnostic checks are available.';

  @override
  String get diagnosticsFooter =>
      'Diagnostics only read the configured paths and do not modify Steam files.';

  @override
  String get applicationFolders => 'Application folders';

  @override
  String get applicationFoldersFooter =>
      'Logs and backups stay inside the application data directory. Opening a folder does not modify its contents.';

  @override
  String get openLogsAndBackups => 'Open log and backup folders';

  @override
  String get dlcAnalysisDescription =>
      'Manage DLC records, compare Steam depot metadata with Lua, and preview additions.';

  @override
  String get managePatchesAndLicenses =>
      'Apply patches and manage license configuration.';

  @override
  String get kernelDownloadsAndNetwork => 'Kernel, downloads and network';

  @override
  String get conversionResults => 'Conversion results';

  @override
  String get noMatchingManifestsFound => 'No matching manifests were found.';

  @override
  String get versionLabel => 'Version';

  @override
  String get platformLabel => 'Platform';

  @override
  String get updatedLabel => 'Updated';

  @override
  String get fileSizeLabel => 'Size';

  @override
  String get sourceLabel => 'Source';

  @override
  String get destinationLabel => 'Destination';

  @override
  String get actionsLabel => 'Actions';

  @override
  String get selectAGameToShowGameTools =>
      'Select a game to show its specific tools.';

  @override
  String get lanTransfer => 'LAN transfer';

  @override
  String get lanTransferDescription =>
      'Send an installed game, its Lua and the related manifests directly to another FlSteamLua PC on this network.';

  @override
  String get allowLanTransfers => 'Allow transfers to this device';

  @override
  String get allowLanTransfersDescription =>
      'Run the encrypted receiver while FlSteamLua stays open or in the tray.';

  @override
  String lanTransferTask(String game) {
    return 'Transfer $game';
  }

  @override
  String get lanNearbyDevices => 'Nearby devices';

  @override
  String get lanNearbyDevicesDescription =>
      'Devices appear automatically on the same private network. Unknown devices still need approval before sending files.';

  @override
  String get lanNoDevices => 'No receiving device found';

  @override
  String get lanNoDevicesDescription =>
      'Enable receiving on the other PC, or add its IP address manually.';

  @override
  String get lanAddDevice => 'Add device';

  @override
  String get lanDeviceAddress => 'Device address';

  @override
  String get lanDeviceAddressHint => '192.168.1.20';

  @override
  String get lanConnectDevice => 'Connect';

  @override
  String get lanManualDevice => 'Manual address';

  @override
  String get lanTrusted => 'Trusted';

  @override
  String get lanUntrusted => 'Needs approval';

  @override
  String get lanSendGame => 'Send game';

  @override
  String get lanChooseDevice => 'Receiver';

  @override
  String get lanSendToLan => 'Send over LAN';

  @override
  String get lanReceiveTransfer => 'Receive transfer';

  @override
  String lanIncomingTransferTitle(String game) {
    return 'Receive $game';
  }

  @override
  String lanTransferFromDevice(String device) {
    return 'From $device';
  }

  @override
  String get lanAccept => 'Accept';

  @override
  String get lanReject => 'Reject';

  @override
  String get lanRememberDevice => 'Trust this device and receive automatically';

  @override
  String get lanAcceptAndRemember => 'Accept and trust';

  @override
  String get lanContentToTransfer => 'Content to transfer';

  @override
  String get lanOfficialFiles => 'Official game files';

  @override
  String get lanModifiedFiles => 'Modified game files';

  @override
  String get lanExtraFiles => 'Additional files and mods';

  @override
  String get lanLuaAndManifests => 'Lua and manifests';

  @override
  String get lanDepotManifests => 'Depot manifests';

  @override
  String get lanExtrasWarning =>
      'Additional files may include mods, patches or saves stored inside the game folder. Select only what the receiver needs.';

  @override
  String get lanNoManifestWarning =>
      'No local depot manifest was found. Official files cannot be identified automatically, so every game file requires manual selection.';

  @override
  String get lanNetworkSpeed => 'Network';

  @override
  String get lanDiskWriteSpeed => 'Disk writes';

  @override
  String get lanDownloadProgress => 'Downloading data';

  @override
  String get lanUploadProgress => 'Sending data';

  @override
  String get lanInstallProgress => 'Installing files';

  @override
  String lanNetworkTransferred(String bytes) {
    return 'Transferred over the network: $bytes';
  }

  @override
  String get lanPeakSpeed => 'Peak';

  @override
  String get lanProgress => 'Transferring game data';

  @override
  String get lanRemainingTime => 'Time remaining';

  @override
  String get lanPause => 'Pause transfer';

  @override
  String get lanPaused => 'Paused';

  @override
  String get lanResume => 'Resume transfer';

  @override
  String get lanRetryTransfer => 'Retry transfer';

  @override
  String get lanCancelTransfer => 'Cancel transfer';

  @override
  String get lanWaitingApproval => 'Waiting for the receiver to approve';

  @override
  String get lanWaitingSteam =>
      'Downloaded. Close Steam on the receiving PC to finish installation.';

  @override
  String get lanCompleted => 'Completed';

  @override
  String get lanFailed => 'Failed';

  @override
  String get lanActiveTransfer => 'Active transfer';

  @override
  String get lanRecentTransfers => 'Recent transfers';

  @override
  String get lanHistoryEmpty => 'Completed transfers will appear here.';

  @override
  String get lanDestinationLibrary => 'Destination Steam library';

  @override
  String get lanSteamRestartNotice =>
      'FlSteamLua sees the game immediately. Restart Steam after installation to refresh its installed-game list.';

  @override
  String get lanForgetDevice => 'Forget device';

  @override
  String get lanDeviceFingerprint => 'Device fingerprint';

  @override
  String get lanReceiveDisabled => 'Receiving is off';

  @override
  String get lanReceiveEnabled => 'Ready to receive';

  @override
  String get lanTransferSettings => 'This PC';

  @override
  String get lanNoLibrary => 'No writable Steam library was found.';

  @override
  String get lanDiskUsage => 'Disk activity';

  @override
  String get lanGameFiles => 'Game files';

  @override
  String get lanPreparing => 'Preparing files';

  @override
  String get lanVerifying => 'Verifying files';

  @override
  String get lanCommitting => 'Installing game';

  @override
  String get lanCancelled => 'Cancelled';

  @override
  String get lanSelectDestinationDescription =>
      'Choose a registered Steam library with enough free space.';

  @override
  String get lanNoSelectedFiles => 'No files selected';

  @override
  String get lanRefreshDevices => 'Refresh devices';

  @override
  String get lanChunkProgress => 'Chunk progress';

  @override
  String get lanCachedChunks => 'Cached chunks';

  @override
  String get lanChunkCache => 'Transfer staging';

  @override
  String get lanChunkCacheDescription =>
      'Unfinished game data kept for resuming transfers.';

  @override
  String get lanClearChunkCache => 'Clear transfer staging';

  @override
  String get lanClearChunkCacheConfirmation =>
      'Clear unfinished transfer data? Resuming these transfers will require retransmission.';

  @override
  String get lanChunkCacheCleared => 'Transfer staging cleared.';

  @override
  String get lanManualAddressInvalid =>
      'Enter a valid IPv4 address or host name.';

  @override
  String get more => 'More';

  @override
  String get screenshots => 'Screenshots';

  @override
  String get previewImage => 'Preview image';

  @override
  String get previousImage => 'Previous image';

  @override
  String get nextImage => 'Next image';

  @override
  String get selectAll => 'Select all';

  @override
  String get contentPreview => 'Content preview';

  @override
  String get updateChangelog => 'Changelog';

  @override
  String get versionPinned => 'Version pinned';

  @override
  String get clearDownloadedManifests => 'Clear Steam manifest cache';

  @override
  String clearDownloadedManifestsDescription(String game) {
    return 'Clear every manifest file for \"$game\" from all Steam depotcache locations? Lua files are not changed.';
  }

  @override
  String downloadedManifestsCleared(String count) {
    return 'Cleared $count Steam manifest file(s).';
  }

  @override
  String get noDownloadedManifests =>
      'No manifest files were found for this game in Steam depotcache.';

  @override
  String get luaDirectories => 'Lua directories';

  @override
  String get addLuaDirectory => 'Add Lua directory';

  @override
  String get luaDirectoryAlreadyAdded => 'This directory is already listed.';

  @override
  String get defaultLuaWriteDirectory => 'Default write directory';

  @override
  String get luaDirectoriesSaved =>
      'Lua directories saved to the core configuration and library refreshed.';

  @override
  String get coreLuaDirectory => 'Fixed directory';

  @override
  String get remove => 'Remove';

  @override
  String get configurationEnabled => 'Enabled in configuration';

  @override
  String get cloudPluginCache => 'Plugin local cache';

  @override
  String get cloudFolderRepository => 'Folder repository';

  @override
  String get cloudConfigurationSavedRestart =>
      'Configuration saved. Restart Steam to apply it.';

  @override
  String get cloudConfigurationRestartDescription =>
      'Steam loads this configuration at startup. Enabling it does not confirm that the plugin is loaded or sync has completed.';

  @override
  String get cloudMetadataSync => 'Achievement and playtime sync';

  @override
  String get cloudSyncAchievements => 'Sync achievements and statistics';

  @override
  String get cloudSyncPlaytime => 'Sync playtime';

  @override
  String get cloudRepositoryDescription =>
      'Manage CloudRedirect repositories and caches here. Exports preserve hashed objects and metadata; the plugin inside Steam restores saves through synchronization.';

  @override
  String get manifestConfigurationSaved =>
      'Request-code configuration saved. Restart Steam to apply script changes; custom and local proxy modes require this app to stay running.';

  @override
  String get kernelChannelDescription =>
      'Saving updates both the core automatic source and manual downloads. Existing cached files remain in use; new build fingerprints use this source on the next Steam startup.';

  @override
  String get onlineFixRealAppIdDescription =>
      'On the maintained fork, try keeping the real AppID for black-screen or loading issues. Games requiring the Spacewar AppID should use the option above.';

  @override
  String get luaPresenceDescription =>
      'Controls friend presence for Lua games, without changing Steam-wide privacy. Requires a fork with presence support; the discontinued mainline does not support it.';

  @override
  String get customLuaDirectories => 'Custom directories';

  @override
  String get noCustomLuaDirectories => 'No custom directories';

  @override
  String get luaDirectoriesSort => 'Directory order';

  @override
  String get currentSteamLoginAccount => 'Current Steam account';

  @override
  String get ticketOwnerAccount => 'Ticket owner';

  @override
  String get cachedAuthorizationIdentity =>
      'Cached authorization identity for this game';

  @override
  String get ticketIdentityNotSet => 'Not set';

  @override
  String get ticketAccountUnavailable => 'Not signed in or unavailable';

  @override
  String get applyTicketPreserveIdentity => 'Apply tickets, preserve identity';

  @override
  String syncAuthorizationIdentity(String steamId) {
    return 'Also set authorization identity to $steamId';
  }

  @override
  String get ticketIdentitySaveWarning =>
      'Changing the authorization identity may affect game saves stored in SteamID-specific directories.';

  @override
  String get ticketCachedIdentityWarning =>
      'The cached authorization identity differs from the ticket owner. Preserving it may affect authorization; only starting the game can confirm authorization.';

  @override
  String get ticketIdentityWarningLabel => 'Identity mismatch';

  @override
  String get ticketApplyBackupDescription =>
      'Back up the previous AppTicket, ETicket and SteamID with encryption before applying. By default, only the two tickets are replaced.';

  @override
  String get ticketWrittenVerified => 'Tickets written and verified';

  @override
  String get restorePreApplyCredentials => 'Restore previous credentials';

  @override
  String get ticketRestoreCompleteSet =>
      'Restore both tickets and SteamID from this backup, deleting values that were originally absent. Restore associated Lua files too and save the current credentials in an encrypted backup.';

  @override
  String get ticketCredentialsRestored =>
      'Previous credential set restored and verified';

  @override
  String get ticketLuaCleanup => 'Ticket statements to remove from Lua';

  @override
  String ticketLuaRemovalCount(String count) {
    return 'Found $count old ticket statements';
  }

  @override
  String get ticketLuaCleanupDescription =>
      'Confirming backs up the Lua files and removes these statements before applying, preventing the core from reloading old tickets.';

  @override
  String get ticketStopSteamForLua =>
      'Steam will close after confirmation to prevent Lua hot reload from overwriting credentials. Restart it manually afterwards.';

  @override
  String get ticketPreviewChanged =>
      'Credentials changed after the preview. Review them again.';

  @override
  String get ticketLuaChanged =>
      'Lua changed after the preview or backup. The current file was not overwritten; review it again.';

  @override
  String get ticketInvalidBackup => 'Invalid credential backup.';

  @override
  String get ticketWriteNotVerified =>
      'Credential read-back verification failed; restoration of the previous values was attempted.';

  @override
  String get ticketRollbackIncomplete =>
      'The operation failed and rollback was incomplete. Restore the full credential set and Lua files from the encrypted backup.';

  @override
  String get ticketOperationBusy =>
      'Another credential operation is still running.';

  @override
  String get ticketLuaManualCleanup =>
      'The Lua ticket call is not a removable stand-alone statement. Edit it in the Lua editor before applying.';

  @override
  String get copyAchievementsHint =>
      'Copies local cache files only; unlocked achievements are not transferred.';

  @override
  String lanAutomaticReceiveHint(String path) {
    return 'Future transfers will be accepted into: $path. Use the device menu to forget this device.';
  }

  @override
  String get noInstalledGamesToTransfer => 'No installed games to transfer';

  @override
  String get installGameBeforeTransfer =>
      'Install a game, then refresh the library.';

  @override
  String get noAdditionalFiles => 'No additional files';

  @override
  String sourceNeedsConfiguration(String name) {
    return '$name · Needs configuration';
  }

  @override
  String get configureManifestSource => 'Configure selected manifest source';

  @override
  String sourceTestPassed(String name) {
    return '$name passed the test.';
  }

  @override
  String get fileWillBeBackedUpAndReplaced => 'Will be backed up and replaced';

  @override
  String get fileExistsChooseReplace =>
      'File exists; confirm backup and replacement';

  @override
  String luaImportReady(String game) {
    return 'Lua configuration for “$game” is saved. You can now open Steam to install it.';
  }

  @override
  String get httpsUrlRequired => 'Enter a valid HTTPS URL.';

  @override
  String get subscriptionAutoUpdateScope =>
      'Applies to all subscriptions; each uses its own update interval.';

  @override
  String get subscriptionIntervalDescription =>
      'An interval of 0 means manual updates only. Enable automatic updates above to use the interval.';

  @override
  String get sourceOutputType => 'Content to retrieve';

  @override
  String get sourceArchiveOutput => 'Manifest archive';

  @override
  String get sourceCredentialHint =>
      'Sign in on the source website and obtain this credential from account settings.';

  @override
  String get sourceOutputHint =>
      'Lua retrieves configuration text; the archive option retrieves the source’s manifest package.';

  @override
  String get sourceProviderHint =>
      'Choose the manifest provider used by this service.';

  @override
  String get sourceGameNameHint =>
      'Used only by the source service; leave blank if unnecessary.';

  @override
  String get sourceDepotManifestHint =>
      'Enter Depot ID and Manifest ID together, or leave both blank to request the game package.';

  @override
  String get openSourceWebsite => 'Open source website';

  @override
  String get luaDirectoryRemoved =>
      'Directory removed from configuration. Its files are kept.';

  @override
  String get undo => 'Undo';

  @override
  String get bearerToken => 'Bearer token';

  @override
  String fillRequiredFields(String fields) {
    return 'Complete these required fields: $fields.';
  }

  @override
  String get cloudAddressInvalid =>
      'Enter a complete HTTPS URL, or enable Allow HTTP to use an HTTP URL.';

  @override
  String get cloudTimeoutInvalid => 'Timeout must be from 0 to 300 seconds.';

  @override
  String get connectionFailedRetry =>
      'Could not connect. Check your network and try again.';

  @override
  String get fileOperationFailedHint =>
      'Could not access the files. Check folder permissions, disk space, and whether a file is in use.';

  @override
  String get remoteCredentialsRejected =>
      'Remote access was denied. Check your credentials and folder permissions.';

  @override
  String get remoteLocationMissing =>
      'The remote location was not found. Check the configured address or folder.';

  @override
  String get remoteOperationFailedHint =>
      'The remote operation could not finish. Check the connection or open Details.';

  @override
  String get invalidInputHint =>
      'The content format is invalid. Check the form or imported file.';

  @override
  String get operationFailedDetails =>
      'The operation could not finish. Open Details for the cause.';

  @override
  String get steamLocalSave => 'Steam local saves';

  @override
  String selectBackupProvider(String provider) {
    return 'This backup includes remote data from $provider. Select that storage provider before restoring.';
  }

  @override
  String get steamUpdateChecks => 'Steam update checks';

  @override
  String get steamForcedUpdates => 'Steam forced updates';

  @override
  String get blockedSetting => 'Blocked';

  @override
  String get allowedSetting => 'Allowed';

  @override
  String get confirmApplyTickets => 'Confirm ticket application';

  @override
  String get reviewExtractedTickets => 'Review and apply these tickets';

  @override
  String get extractTrainerBeforeBinding =>
      'Extract this archive first, then select the trainer executable to bind it to a game.';

  @override
  String get testAndUpdateSubscription => 'Test and update key subscription';

  @override
  String get cloudOperationBusy =>
      'Wait for the current save operation to finish.';

  @override
  String get cloudInvalidBackup => 'Invalid backup record.';

  @override
  String get cloudBackupChecksumFailed =>
      'Backup checksum failed. Saves were not overwritten.';

  @override
  String get cloudPinnedBackup => 'Unpin the backup before deleting it.';

  @override
  String get cloudInvalidRetention =>
      'Retention count and size must be nonnegative integers.';

  @override
  String get cloudBackupTargetUnknown =>
      'This backup has no storage identity and cannot be restored remotely.';

  @override
  String get cloudBackupTargetChanged =>
      'Storage location or account has changed. Review the destination.';

  @override
  String get cloudSyncActiveOnly =>
      'Activate this storage before pulling to the plugin cache.';

  @override
  String get cloudSteamMustStop => 'Close Steam and games before continuing.';

  @override
  String get cloudInstallPluginFirst =>
      'Install the CloudRedirect plugin first.';

  @override
  String get cloudSyncMetadataMissing =>
      'Repository sync metadata is missing or invalid.';

  @override
  String get cloudSyncNotVerified =>
      'The core did not confirm synchronization. The pre-operation backup is retained; check the task log.';

  @override
  String get cloudCurrentStorage => 'Current core configuration';

  @override
  String get cloudFolderAbsolute => 'Choose an absolute save-folder path.';

  @override
  String get cloudCredentialsRequired =>
      'Enter credentials for the selected authentication method.';

  @override
  String get cloudUnknownStorage => 'Invalid storage type.';

  @override
  String get cloudAuthorizeFirst => 'Authorize an account in this form first.';

  @override
  String get cloudAccountLookupFailed =>
      'Could not read the authorized account identity.';

  @override
  String get cloudWriteProbeFailed => 'Test-file readback verification failed.';

  @override
  String get cloudStorageNameRequired => 'Enter a storage name.';

  @override
  String get cloudActiveStorageDelete =>
      'Switch the active sync target before removing it.';

  @override
  String get cloudDisableBeforeDisconnect =>
      'Disable redirection before disconnecting the active target.';

  @override
  String get cloudStorages => 'Storage management';

  @override
  String get cloudAddStorage => 'Add storage';

  @override
  String get cloudStorageName => 'Storage name';

  @override
  String get cloudActivate => 'Use for synchronization';

  @override
  String get cloudActiveTarget => 'Sync target';

  @override
  String get cloudBrowse => 'Browse saves';

  @override
  String get cloudBrowsing => 'Browsing';

  @override
  String get cloudDuplicate => 'Duplicate configuration';

  @override
  String get cloudSortStorages => 'Storage order';

  @override
  String get cloudStorageSaved => 'Storage saved';

  @override
  String get cloudStorageRemoved =>
      'Remove local configuration and credentials. Remote files are retained.';

  @override
  String get cloudStorageActivated =>
      'Sync target updated; it takes effect on the next Steam launch.';

  @override
  String get cloudTestRead => 'Test reading';

  @override
  String get cloudTestWrite => 'Test writing and cleanup';

  @override
  String get cloudTestWriteHint =>
      'Creates a temporary test file, verifies it, then deletes it.';

  @override
  String get cloudReadVerified => 'Reading verified';

  @override
  String get cloudWriteVerified => 'Reading and writing verified';

  @override
  String get cloudNotTested => 'Not tested';

  @override
  String get cloudDiscardDraft => 'Discard unsaved changes?';

  @override
  String get cloudPendingRestart => 'Pending Steam restart';

  @override
  String get cloudCoreReady => 'Core files ready';

  @override
  String get cloudCoreMissing => 'Core or loader not ready';

  @override
  String get cloudNotRuntimeVerified => 'Runtime not verified';

  @override
  String get cloudLastChecked => 'Last checked';

  @override
  String get cloudAllAccounts => 'All accounts';

  @override
  String get cloudAccountFilter => 'Account filter';

  @override
  String get cloudLocationFilter => 'Location filter';

  @override
  String get cloudAllLocations => 'All locations';

  @override
  String get cloudDetails => 'Save details';

  @override
  String get cloudLoadFiles => 'View files';

  @override
  String get cloudPull => 'Pull to plugin cache';

  @override
  String get cloudPullHint =>
      'CloudRedirect pulls this game after backing up its cache. Launch the game afterward to verify save loading.';

  @override
  String get cloudSyncVerified =>
      'Core sync completed; cache metadata verified';

  @override
  String get cloudCompare => 'Compare repository manifests';

  @override
  String get cloudLocalOnly => 'Local only';

  @override
  String get cloudRemoteOnly => 'Remote only';

  @override
  String get cloudChangedFiles => 'Different content or metadata';

  @override
  String get cloudManifestEqual => 'Repository manifests match';

  @override
  String get cloudCompareHint =>
      'Compares file manifests; timestamps do not establish sync completion.';

  @override
  String get cloudExportRepository => 'Export repository copy';

  @override
  String get cloudExportHint =>
      'Exports hashed objects and metadata. The destination must be empty.';

  @override
  String get cloudPreOperationBackup => 'Automatic pre-operation backup';

  @override
  String get cloudConfirmOperation => 'Confirm save operation';

  @override
  String get cloudStopAndContinue => 'Close Steam and continue';

  @override
  String get cloudBackupDetails => 'Backup details';

  @override
  String get cloudBackupNote => 'Note';

  @override
  String get cloudBackupPinned => 'Keep pinned';

  @override
  String get cloudVerifyBackup => 'Verify backup';

  @override
  String get cloudBackupVerified => 'Backup verified';

  @override
  String get cloudRetention => 'Clean up backups';

  @override
  String get cloudRetentionCount => 'Backups to keep per game';

  @override
  String get cloudRetentionSize => 'Size limit per game (MiB)';

  @override
  String get cloudRetentionHint =>
      '0 means unlimited. Pinned backups are excluded. Files are deleted only after reviewing the list.';

  @override
  String get cloudNothingToClean => 'No backups to clean up';

  @override
  String get cloudBackupManual => 'Manual backup';

  @override
  String get cloudBackupBeforeDelete => 'Before deletion';

  @override
  String get cloudBackupBeforeRestore => 'Before restore';

  @override
  String get cloudBackupBeforeUpload => 'Before upload';

  @override
  String get cloudBackupBeforeSync => 'Before pull';

  @override
  String get cloudDestination => 'Destination';

  @override
  String get cloudRepositoryCopy => 'Copy to sync target';

  @override
  String get cloudGameAccount => 'Game / account';

  @override
  String get cloudTargetChangedDuringOperation =>
      'The destination changed during the operation. Stopped.';

  @override
  String get cloudExportNotEmpty =>
      'Choose an empty directory. Existing files were not overwritten.';

  @override
  String get cloudNoRestoreTargets => 'The backup has no restore locations.';

  @override
  String get cloudRestartForSettings =>
      'Settings saved. Verify runtime behavior after restarting Steam.';

  @override
  String get cloudLoadFailedRetained =>
      'Refresh failed; previous results retained';

  @override
  String get cloudDisconnectConfirm =>
      'Remove this storage’s local credentials. Remote files are retained.';

  @override
  String get cloudNoFiles => 'No files';

  @override
  String get steamVersionTitle => 'Steam client versions';

  @override
  String get steamVersionDescription =>
      'Browse, verify, install and restore Steam client versions';

  @override
  String get steamVersionBusy =>
      'Wait for the current version operation to finish.';

  @override
  String get steamVersionInvalidCatalog =>
      'The version catalogue is invalid or incomplete.';

  @override
  String get steamVersionManifestMismatch =>
      'The manifest architecture or build does not match the request.';

  @override
  String get steamVersionInvalidFilter =>
      'Use YYYYMMDD dates; the start date must not exceed the end date.';

  @override
  String steamVersionDownloading(String file) {
    return 'Downloading and verifying $file';
  }

  @override
  String steamVersionDownloadProgress(
    String file,
    String received,
    String total,
  ) {
    return '$file · $received/$total bytes';
  }

  @override
  String get steamVersionRangeInvalid =>
      'The server returned an incorrect resume range.';

  @override
  String get steamVersionChecksumFailed =>
      'File size or SHA-256 verification failed.';

  @override
  String steamVersionPackageInvalid(String file) {
    return 'Missing or invalid package: $file';
  }

  @override
  String get steamVersionSameImport =>
      'This directory is already in the version library.';

  @override
  String get steamVersionStaging =>
      'Installing and verifying the version in a temporary directory';

  @override
  String get steamVersionInstallUnverified =>
      'The target installation could not be verified; it was not applied to Steam.';

  @override
  String get steamVersionLinkedPath =>
      'Version files contain an unsupported link.';

  @override
  String steamVersionApplying(String current, String total) {
    return 'Applying client file $current/$total';
  }

  @override
  String get steamVersionTargetRequired =>
      'Choose a Steam directory containing steam.exe, or an empty directory for a new installation.';

  @override
  String get steamVersionInvalidBackup => 'Invalid client backup.';

  @override
  String get steamVersionBackupTargetChanged =>
      'This backup belongs to a different Steam directory.';

  @override
  String get steamVersionLatest => 'Sync official releases';

  @override
  String get steamVersionHistory => 'Update history index';

  @override
  String get steamVersionImport => 'Import downloaded version';

  @override
  String get steamVersionCurrent => 'Current client';

  @override
  String get steamVersionUnknown => 'Version not identified';

  @override
  String get steamVersionTarget => 'Installation directory';

  @override
  String get steamVersionEmpty => 'No cached versions';

  @override
  String get steamVersionOfficial => 'Official CDN';

  @override
  String get steamVersionArchive => 'Wayback archive';

  @override
  String get steamVersionLocal => 'Local import';

  @override
  String get steamVersionPackages => 'Client packages';

  @override
  String get steamVersionReady => 'Downloaded';

  @override
  String steamVersionPartial(String current, String total) {
    return '$current/$total packages downloaded';
  }

  @override
  String get steamVersionDownload => 'Download and verify';

  @override
  String get steamVersionVerify => 'Verify downloads';

  @override
  String get steamVersionInstall => 'Install this version';

  @override
  String get steamVersionInstallHint =>
      'Installs offline in a temporary directory, then backs up and replaces client files with rollback on failure. Games, account settings, Lua and plugins are retained. Update behavior follows Settings → Steam update control.';

  @override
  String get steamVersionInstalled =>
      'Client files applied and version checked. Start Steam to verify runtime behavior.';

  @override
  String get steamVersionDeleteDownload =>
      'Delete local download packages while retaining the catalogue entry and client backups.';

  @override
  String get steamVersionBackups => 'Client backups';

  @override
  String get steamVersionRestoreHint =>
      'Restore client files from before this operation, after backing up the current state.';

  @override
  String get steamVersionArchitecture => 'Client architecture';

  @override
  String get steamVersionStartDate => 'Start date';

  @override
  String get steamVersionEndDate => 'End date';

  @override
  String get steamVersionHistoryLimit => 'Manifest limit';

  @override
  String get steamVersionHistoryHint =>
      'Historical files may be incomplete. Installation requires every package to pass verification.';

  @override
  String get steamVersionRefreshLocal => 'Refresh local status';

  @override
  String get steamVersionStartSteam => 'Start Steam';

  @override
  String get steamVersionDetails => 'Version details';

  @override
  String get steamVersionDownloadedVerified =>
      'All client packages passed verification';

  @override
  String get steamVersionStopSteam => 'Close Steam before installation';

  @override
  String get steamVersionBackupBefore => 'Back up client files before applying';

  @override
  String get steamVersionWaybackSettings => 'Wayback and cache';

  @override
  String get steamVersionWaybackAddress => 'Wayback address';

  @override
  String get steamVersionWaybackHint =>
      'Defaults to web.archive.org. You can enter a custom Wayback address.';

  @override
  String get steamVersionWaybackInvalid =>
      'Enter a complete HTTPS address without credentials or query parameters.';

  @override
  String steamVersionCacheHit(String stamp) {
    return 'Reusing cached historical manifest: $stamp';
  }

  @override
  String steamVersionCacheSaved(String stamp) {
    return 'Historical manifest cached: $stamp';
  }

  @override
  String get steamVersionCacheHint =>
      'The built-in catalogue provides initial choices. Refresh the version library to discover new releases. History indexes are cached for 24 hours; selected manifests are fetched on demand and saved.';

  @override
  String get steamVersionForceHistory => 'Force refresh history index';

  @override
  String get steamVersionWaybackDefault => 'Restore default address';

  @override
  String get steamVersionRefreshCatalog => 'Refresh version library';

  @override
  String get steamVersionBuiltin => 'Built-in catalogue';

  @override
  String get steamVersionManifestPending => 'Manifest not loaded';

  @override
  String get steamVersionLoadManifest => 'Load version manifest';

  @override
  String steamVersionSnapshot(String date) {
    return 'Historical snapshot $date';
  }

  @override
  String get supportAuthor => 'Support the author';

  @override
  String get supportAuthorThanks =>
      'Buy me a coffee. Thank you for supporting FlSteamLua.';

  @override
  String get feedbackGroup => 'Join the feedback group';

  @override
  String get feedbackGroupHint =>
      'Search for this group number in QQ to join and share feedback.';

  @override
  String get copyGroupNumber => 'Copy group number';

  @override
  String get groupNumberCopied => 'Group number copied';

  @override
  String get wechatPay => 'WeChat Pay';

  @override
  String get alipay => 'Alipay';

  @override
  String get availableUpdates => 'Available updates';

  @override
  String applicationUpdateAvailable(String version) {
    return 'FlSteamLua $version is available';
  }

  @override
  String kernelUpdateNotification(String version) {
    return 'Kernel $version is available';
  }

  @override
  String get viewChangelogHistory => 'View changelog history';
}
