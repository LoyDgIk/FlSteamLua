// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get languageName => '中文';

  @override
  String get quickStart => '快速开始';

  @override
  String get quickStartSkip => '跳过引导';

  @override
  String get quickStartBack => '上一步';

  @override
  String get quickStartNext => '下一步';

  @override
  String get quickStartEnter => '进入应用';

  @override
  String get quickStartAppearance => '语言与外观';

  @override
  String get quickStartFolders => 'Steam 与 Lua';

  @override
  String get quickStartPrepare => '准备使用';

  @override
  String get quickStartAppearanceTitle => '从你喜欢的样子开始';

  @override
  String get quickStartAppearanceHint => '选择语言、配色和侧栏样式，调整会即时生效。';

  @override
  String get quickStartFoldersTitle => '连接你的游戏库';

  @override
  String get quickStartFoldersHint => '选择 Steam 安装目录，并确认新 Lua 文件的保存位置。';

  @override
  String get quickStartPrepareTitle => '按需配置，即可出发';

  @override
  String get quickStartPrepareHint => '按需要配置内核与内容来源。之后随时可以从设置重新打开快速开始。';

  @override
  String get quickStartMoreAppearance => '更多外观设置';

  @override
  String get quickStartNetworkHint => '代理与下载镜像';

  @override
  String quickStartSources(int count) {
    return '已启用 $count 个已配置来源';
  }

  @override
  String quickStartStep(int current, int total) {
    return '$current / $total';
  }

  @override
  String get updateKeySubscriptions => '更新密钥订阅';

  @override
  String launch(String value1) {
    return '启动 $value1';
  }

  @override
  String stop(String value1) {
    return '关闭 $value1';
  }

  @override
  String get deleteLuaRecord => '删除 Lua 记录？';

  @override
  String
  get onlyThisLuaFileIsRemovedTheGameStaysInstalledAndABackupIsSavedFirst =>
      '只删除此 Lua 文件，不会卸载游戏。删除前会保存备份。';

  @override
  String get cancel => '取消';

  @override
  String get deleteRecord => '删除记录';

  @override
  String get deleteLuaRecord2 => '删除 Lua 记录';

  @override
  String get unfavorite => '取消收藏';

  @override
  String get favorite => '收藏';

  @override
  String get manage => '管理';

  @override
  String get manageSaves => '管理存档';

  @override
  String get manageAchievements => '管理成就';

  @override
  String get trainers => '修改器';

  @override
  String get onlineFixes => '联机补丁';

  @override
  String get dlcAnalysis => 'DLC 管理';

  @override
  String get keySubscriptionsOfflineLua => '获取 Lua / 清单';

  @override
  String get gameToolsAndVersionManagement => '游戏工具与版本管理';

  @override
  String get installOrRestorePatches => '补丁安装与还原';

  @override
  String get extractAccountGameData => '提取账号游戏资料';

  @override
  String get running => '运行中';

  @override
  String get installed => '已安装';

  @override
  String get luaConfigured => '已配置 Lua';

  @override
  String get luaDisabled => 'Lua 已停用';

  @override
  String get accountOwnsThisGame => '账号拥有';

  @override
  String get notOwnedByAccount => '账号未拥有';

  @override
  String get ownershipUnknown => '拥有状态未知';

  @override
  String get stopGame => '关闭游戏';

  @override
  String get play => '开始游玩';

  @override
  String get installWithSteam => '在 Steam 中安装';

  @override
  String get getLuaManifests => '获取 Lua / 清单';

  @override
  String get addToLibrary => '添加到 Lua 库';

  @override
  String get openGameFolder => '打开游戏目录';

  @override
  String get playtime => '游玩时长';

  @override
  String playtimeHours(String hours) {
    return '$hours 小时';
  }

  @override
  String minutes(String playtimeMinutes) {
    return '$playtimeMinutes 分钟';
  }

  @override
  String get lastPlayed => '最近游玩';

  @override
  String get notRecorded => '尚无记录';

  @override
  String get diskSpace => '占用空间';

  @override
  String get storePrice => '商店价格';

  @override
  String get achievements => '成就';

  @override
  String get viewAndManageGameAchievements => '查看与管理游戏成就';

  @override
  String get cloudSaves => '云存档';

  @override
  String get backUpSyncAndRestoreProgress => '查看存档位置与备份记录';

  @override
  String get gameManagement => '游戏管理';

  @override
  String get trainersMultiplayerAndMore => '修改器、联机与更多工具';

  @override
  String get luaRecord => 'Lua 记录';

  @override
  String get enabledTakesEffectAfterRestartingSteam => '已启用，核心可自动重新加载';

  @override
  String get disabledFileIsPreserved => '已停用，保留文件';

  @override
  String get changeLuaState => '切换 Lua 状态';

  @override
  String get aboutThisGame => '关于这款游戏';

  @override
  String get steamStore => 'Steam 商店';

  @override
  String get storeDetailsAreUnavailableLocalGameActionsRemainAvailable =>
      '暂时无法获取商店资料，本地游戏操作仍可使用。';

  @override
  String get retry => '重试';

  @override
  String get developer => '开发商';

  @override
  String get released => '发行日期';

  @override
  String get selectDlcManifestsToRetrieveThisDoesNotPurchaseOrInstallDlc =>
      '选择要获取的 DLC 清单；不会自动购买或安装。';

  @override
  String get loadDlcNames => '加载 DLC 名称';

  @override
  String get clearSelection => '清空选择';

  @override
  String getSelected(String selectedDlcCount) {
    return '获取所选 ($selectedDlcCount)';
  }

  @override
  String get importLuaAndManifests => '导入 Lua 与清单';

  @override
  String get importResults => '导入结果';

  @override
  String completedSkippedFailed(
    String writtenCount,
    String skippedCount,
    String errorsCount,
  ) {
    return '完成 $writtenCount · 跳过 $skippedCount · 失败 $errorsCount';
  }

  @override
  String get completed => '已完成';

  @override
  String get existingFilesLeftUnchanged => '文件已存在，未覆盖';

  @override
  String get errors => '失败详情';

  @override
  String get close => '关闭';

  @override
  String get backUpAndReimportWithOverwrite => '备份并覆盖重新导入';

  @override
  String get fetchGameNamesAndCovers => '获取游戏名称与封面';

  @override
  String get chooseALuaAndManifestFolder => '选择 Lua 与清单目录';

  @override
  String get exportLuaToFolder => '导出 Lua 到目录';

  @override
  String get exportLua => '导出 Lua';

  @override
  String get exportResults => '导出结果';

  @override
  String get enableSelectedLua => '批量启用 Lua';

  @override
  String get disableSelectedLua => '批量禁用 Lua';

  @override
  String get deleteLua => '删除 Lua';

  @override
  String deleteLuaFiles(String targetsCount) {
    return '删除 $targetsCount 个 Lua 文件？';
  }

  @override
  String luaFilesAreBackedUpBeforeDeletionSteamGamesAndSavesAreKept(
    String value1,
  ) {
    return '删除前会备份 Lua；Steam 游戏和存档不受影响。\n\n$value1';
  }

  @override
  String get backUpAndDelete => '备份并删除';

  @override
  String get gameDetails => '游戏详情';

  @override
  String get editLua => '编辑 Lua';

  @override
  String get disableLua => '禁用 Lua';

  @override
  String get enableLua => '启用 Lua';

  @override
  String get openLuaFolder => '打开 Lua 目录';

  @override
  String get pinLatestPublicVersion => '固定最新公开版本';

  @override
  String get pinInstalledVersion => '固定当前已安装版本';

  @override
  String get unpinVersion => '解除版本固定';

  @override
  String get dlcManagementAndAnalysis => 'DLC 管理与分析';

  @override
  String get manageGameSaves => '管理游戏存档';

  @override
  String get editAchievements => '编辑游戏成就';

  @override
  String get manageGamePatches => '管理游戏补丁';

  @override
  String get copyAppid => '复制 AppID';

  @override
  String get updateManifestPins => '更新版本固定';

  @override
  String get launchGame => '启动游戏';

  @override
  String manage2(String value1) {
    return '管理 $value1';
  }

  @override
  String min(String playtimeMinutes) {
    return '$playtimeMinutes 分钟';
  }

  @override
  String get luaEnabled => 'Lua 已启用';

  @override
  String get luaDisabled2 => 'Lua 已禁用';

  @override
  String get game => '游戏';

  @override
  String get status => '状态';

  @override
  String get luaFile => 'Lua 文件';

  @override
  String selected(String selectedCount, String gamesCount) {
    return '已选择 $selectedCount / $gamesCount';
  }

  @override
  String get selectAllFiltered => '全选筛选结果';

  @override
  String get clearSelection2 => '清除选择';

  @override
  String get enableSelected => '批量启用';

  @override
  String get disableSelected => '批量禁用';

  @override
  String get export => '导出';

  @override
  String get library => '库';

  @override
  String get manageLuaConfigurationsAndInstalledGames => '管理 Lua 配置，也管理已安装的游戏。';

  @override
  String get import => '导入';

  @override
  String get importFilesOrArchives => '导入文件或压缩包';

  @override
  String get importFolder => '导入目录';

  @override
  String get luaLibrary => 'Lua 库';

  @override
  String get steamGames => 'Steam 游戏库';

  @override
  String get searchGameNamesOrAppid => '搜索游戏名称或 AppID';

  @override
  String get rescan => '重新扫描';

  @override
  String get view => '视图';

  @override
  String get gridView => '卡片视图';

  @override
  String get listView => '列表视图';

  @override
  String get tableView => '表格视图';

  @override
  String get sort => '排序';

  @override
  String get filter => '筛选';

  @override
  String get nameAscending => '名称升序';

  @override
  String get nameDescending => '名称降序';

  @override
  String get recentlyPlayed => '最近游玩';

  @override
  String get libraryActions => '库操作';

  @override
  String get refreshGameInformation => '刷新游戏信息';

  @override
  String get disableSteamOfflineMode => '关闭 Steam 离线模式';

  @override
  String get enableSteamOfflineMode => '开启 Steam 离线模式';

  @override
  String get all => '全部';

  @override
  String get enabled => '已启用';

  @override
  String get disabled => '已禁用';

  @override
  String get favorites => '收藏';

  @override
  String get done => '完成';

  @override
  String get select => '批量管理';

  @override
  String informationCouldNotBeLoadedForGamesLocalRecordsAreKept(
    String metadataErrorsCount,
  ) {
    return '$metadataErrorsCount 款游戏的信息获取失败，已保留本地记录。';
  }

  @override
  String get libraryDetails => '库提示';

  @override
  String get details => '详情';

  @override
  String get descriptionLabel => '描述';

  @override
  String get connectYourSteamLibrary => '连接你的 Steam 游戏库';

  @override
  String
  get chooseYourSteamInstallationToReadLuaConfigurationsAndInstalledGames =>
      '选择 Steam 安装目录，读取 Lua 配置和已安装游戏。';

  @override
  String get chooseSteamFolder => '选择 Steam 目录';

  @override
  String get noMatchingLuaConfigurations => '没有符合条件的 Lua';

  @override
  String get noMatchingInstalledGames => '没有符合条件的已安装游戏';

  @override
  String get noSearchResults => '没有匹配结果';

  @override
  String get dropLuaFilesManifestsOrArchivesHereOrChangeTheFilter =>
      '将 Lua、清单或压缩包拖到这里导入，也可以更换筛选条件。';

  @override
  String
  get installedGamesAreReadFromSteamAppmanifestFilesLuaConfigurationsAreInTheFirstTab =>
      '读取 Steam appmanifest 安装记录；Lua 配置位于第一个标签页。';

  @override
  String get importLua => '导入 Lua';

  @override
  String get chooseASteamFolderFirst => '先选择 Steam 目录';

  @override
  String get dropToImportLuaManifestsOrArchives => '松开以导入 Lua、清单或压缩包';

  @override
  String get owned => '账号拥有';

  @override
  String get tasks => '任务';

  @override
  String get clearCompleted => '清除已结束任务';

  @override
  String get allClear => '没有正在处理的任务';

  @override
  String get downloadsImportsAndBackupsWillAppearHere => '下载、导入和备份的进度会显示在这里。';

  @override
  String get cancelling => '正在取消…';

  @override
  String get showLogs => '查看日志';

  @override
  String get start => '启动';

  @override
  String get stop2 => '关闭';

  @override
  String linkedTrainer(String Stop, String appId) {
    return '$Stop关联修改器 · $appId';
  }

  @override
  String get discardPendingChanges => '放弃待保存的修改？';

  @override
  String
  get reloadingOrSwitchingGamesDiscardsUnsavedAchievementAndStatisticChanges =>
      '重新读取或切换游戏会清除尚未保存的成就和统计修改。';

  @override
  String get keepEditing => '继续编辑';

  @override
  String get discardAndContinue => '放弃并继续';

  @override
  String chooseAGameToManageAchievementsAndStatisticsGames(
    String allGamesCount,
  ) {
    return '选择游戏，管理成就与统计。共 $allGamesCount 款游戏';
  }

  @override
  String get searchGamesOrAppid => '搜索游戏或 AppID';

  @override
  String get appidAscending => 'AppID 升序';

  @override
  String get appidDescending => 'AppID 降序';

  @override
  String continueEditing(String value1) {
    return '继续编辑 $value1';
  }

  @override
  String get pendingChanges => '项待保存';

  @override
  String get yourLibraryHasNoGamesYet => '游戏库中还没有游戏';

  @override
  String get noMatchingGames => '没有匹配的游戏';

  @override
  String saveChanges(String count) {
    return '保存 $count 项修改';
  }

  @override
  String get unlock => '解锁';

  @override
  String get lock => '锁定';

  @override
  String get saveToSteam => '提交到 Steam';

  @override
  String get savedAndConfirmedByReadingBackFromSteam =>
      '修改已保存，并从 Steam 重新读取确认。';

  @override
  String get integerValue => '整数值';

  @override
  String get value => '数值';

  @override
  String get enterAValidValueInRange => '请输入范围内的有效数值';

  @override
  String get stageChange => '加入待保存';

  @override
  String get chooseAGame => '选择游戏';

  @override
  String get reload => '重新读取';

  @override
  String get unlocked => '已解锁';

  @override
  String get couldNotLoadAchievements => '未能读取成就';

  @override
  String get startSteamSignInThenSelectReload => '请启动 Steam 并登录，再点击“重新读取”。';

  @override
  String get statistics => '统计';

  @override
  String get searchAchievements => '搜索成就';

  @override
  String get unlocked2 => '已解锁';

  @override
  String get locked => '未解锁';

  @override
  String get pending => '待保存';

  @override
  String get unlockAll => '全部解锁';

  @override
  String get lockAll => '全部锁定';

  @override
  String get invert => '反选';

  @override
  String get noMatchingAchievements => '没有匹配的成就';

  @override
  String get thisAchievementIsManagedByTheGameServer => '此成就由游戏服务器管理';

  @override
  String get hiddenAchievement => '隐藏成就';

  @override
  String get searchStatisticNameOrId => '搜索统计名称或 ID';

  @override
  String get noReadableLocalStatisticsForThisGame => '该游戏没有可读取的本地统计';

  @override
  String get noMatchingStatistics => '没有匹配的统计';

  @override
  String get editStatistic => '修改统计';

  @override
  String changesPending(String value1) {
    return '$value1 项修改待保存';
  }

  @override
  String get changesAreSubmittedToSteamWhenSaved => '修改会在保存后提交到 Steam';

  @override
  String get discard => '放弃修改';

  @override
  String get saveChanges2 => '保存修改';

  @override
  String get loadCloudSaves => '读取云存档';

  @override
  String get completed2 => '操作完成';

  @override
  String get localFolder => '本地目录';

  @override
  String get configureLocalRedirectionAndRemoteStorageSeparately =>
      '本地重定向与远端备份分别配置，随时查看实际状态。';

  @override
  String get refresh => '刷新';

  @override
  String get refreshCloudSaves => '刷新云存档';

  @override
  String get localSaveRedirection => '存档重定向';

  @override
  String get enabledRestartSteamAfterChanges => '配置已启用；修改后需重启 Steam';

  @override
  String get disabledEnablingDownloadsAndVerifiesTheCloudredirectDll =>
      '已关闭；启用时下载并校验 CloudRedirect DLL';

  @override
  String get enableSaveRedirection => '启用存档重定向';

  @override
  String
  get downloadCloudredirectAndUpdateSteamFilesAndKernelConfigurationRestartSteamAfterwards =>
      '将下载 CloudRedirect 原生库并写入 Steam 目录和内核配置。完成后请重启 Steam。';

  @override
  String get configureRedirection => '设置存档重定向';

  @override
  String get localSaveFolder => '文件夹提供方目录';

  @override
  String get remoteStorage => '远端存储';

  @override
  String get configured => '已配置';

  @override
  String get remoteSyncIsNotConfigured => '未配置远端存储';

  @override
  String get configure => '配置';

  @override
  String get testCloudConnection => '测试云端连接';

  @override
  String get testConnection => '测试连接';

  @override
  String get connectCloudAccount => '连接云端账户';

  @override
  String get authorize => '登录授权';

  @override
  String get disconnectAccount => '断开远端账户';

  @override
  String get removeLocalCredentialsRemoteSavesRemain => '删除本机登录凭据，不删除远端存档。';

  @override
  String get disconnectAccount2 => '断开账户';

  @override
  String get disconnect => '断开连接';

  @override
  String get gameSaves => '游戏存档';

  @override
  String get backups => '备份记录';

  @override
  String get dataManagement => '数据管理';

  @override
  String get storageUsage => '存储占用';

  @override
  String get storageLocations => '存储位置';

  @override
  String get storageLocationsDescription =>
      '缓存、备份、下载和日志目录可以独立设置；Lua 目录仍由 Steam 与游戏文件设置管理。';

  @override
  String get appCache => '缓存';

  @override
  String get logs => '日志';

  @override
  String get appData => '应用数据';

  @override
  String get lanTransferCache => '传输暂存';

  @override
  String get cleanup => '清理';

  @override
  String get clearCache => '清理缓存';

  @override
  String get clearCacheDescription => '移除封面、元数据缓存、密钥缓存和局域网传输分块。';

  @override
  String get clearCacheConfirmation => '清理所有缓存文件？备份、下载、设置和存档不会被删除。';

  @override
  String get clearingCache => '正在清理缓存文件';

  @override
  String get cacheCleared => '缓存已清理';

  @override
  String get scanningStorage => '正在计算存储占用';

  @override
  String get changeStorageFolder => '更改目录';

  @override
  String get chooseStorageFolder => '选择存储目录';

  @override
  String get storageChangeBlockedByTasks => '请等待正在运行的任务结束后再更改存储目录。';

  @override
  String get chooseSeparateStorageFolder => '请选择不与当前存储目录互相包含的文件夹。';

  @override
  String get chooseEmptyStorageFolder => '请选择空的目标文件夹。';

  @override
  String moveStorageData(String name) {
    return '移动$name数据';
  }

  @override
  String get moveStorageDataDescription => '现有文件会先复制到新目录，成功后再从旧目录删除。';

  @override
  String get preparingStorageFolder => '正在准备存储目录';

  @override
  String get storageFolderUpdated => '存储目录已更新';

  @override
  String get restoreDefault => '恢复默认目录';

  @override
  String get noRedirectedSavesFound => '尚未发现重定向存档';

  @override
  String
  get chooseAFolderOrConnectRemoteStoragePlayAGameWithRedirectionEnabledToCreateSaves =>
      '先配置目录或连接远端。启用重定向后，运行游戏产生的存档会显示在这里。';

  @override
  String get remote => '远端';

  @override
  String get local => '本地';

  @override
  String get files => '个文件';

  @override
  String get openFolder => '打开目录';

  @override
  String get backUpThisGame => '备份所选存档位置';

  @override
  String get downloadToFolder => '导出原始仓库';

  @override
  String get uploadToRemote => '复制文件夹仓库到远端';

  @override
  String get previewDeletion => '删除预览';

  @override
  String get confirm => '确认';

  @override
  String get chooseSaveFolder => '选择新的存档目录';

  @override
  String get changeSaveFolder => '更换存档目录';

  @override
  String
  get closeSteamAndAllGamesThenChooseAnEmptyFolderCurrentSavesWillBeCopiedToTheNewFolderAnd =>
      '请先退出 Steam 和所有游戏，并选择空目录。当前目录中的存档将复制到新目录，原文件保留；不会覆盖目标目录中的已有文件。完成后请重启 Steam。';

  @override
  String get setSaveFolder => '设置存档目录';

  @override
  String get backUpSaves => '备份存档';

  @override
  String get downloadSaves => '导出存档仓库';

  @override
  String get uploadSaves => '复制存档仓库';

  @override
  String get remoteFilesWithTheSameNamesWillBeReplacedCloseTheGameFirst =>
      '同名远端文件会被覆盖，请确认游戏已退出。';

  @override
  String get prepareDeletionPreview => '读取删除预览';

  @override
  String get deleteThisGameSSaves => '删除所选账号与位置的存档';

  @override
  String get aCompleteBackupIsCreatedBeforeDeleting => '将先备份以下所选位置，再删除：';

  @override
  String get backupLocation => '备份位置';

  @override
  String get saveBackups => '备份记录';

  @override
  String get noBackupsYet => '尚无备份';

  @override
  String get restoreBackup => '恢复备份';

  @override
  String
  get restoreToTheCurrentConfiguredLocationsExistingLocalSavesArePreservedInAPreRestoreBack =>
      '恢复到当前配置的位置。本地现有文件会先保留到恢复前备份，远端同名文件会被覆盖。请先退出游戏。';

  @override
  String get restoreSaves => '恢复存档';

  @override
  String get restore => '恢复';

  @override
  String get configureStorage => '配置存储';

  @override
  String get provider => '存储类型';

  @override
  String get saveThenChooseAuthorizeToSignInUsingYourBrowser =>
      '保存后点击“登录授权”，在系统浏览器完成登录。';

  @override
  String get authentication => '认证方式';

  @override
  String
  get usesTheWindowsCredentialsEnteredBelowDomainUsernameOrUsernameDomain =>
      '使用下方填写的 Windows 账号和密码，可填写 域\\用户名 或 用户名@域。';

  @override
  String get allowHttpCredentialsAndSavesAreSentWithoutEncryption =>
      '允许 HTTP（凭据和存档不加密传输）';

  @override
  String get skipTlsCertificateValidationUnsafeTrustedSelfHostedServersOnly =>
      '跳过 TLS 证书验证（不安全，仅用于受信任的自建服务）';

  @override
  String get signRequestPayload => '签名请求正文';

  @override
  String get save => '保存';

  @override
  String get saveCloudConfiguration => '保存云端配置';

  @override
  String get operationCompleted => '操作完成';

  @override
  String get operationCancelled => '操作已取消';

  @override
  String get continueLabel => '继续';

  @override
  String get importKernelPackage => '导入内核包';

  @override
  String get switchKernel => '切换内核';

  @override
  String currentKernelFilesWillBeBackedUpBeforeInstallingCloseSteamFirst(
    String displayName,
  ) {
    return '将备份当前内核文件，然后安装 $displayName。请先退出 Steam。';
  }

  @override
  String get noInstalledKernelFilesFound => '未发现已安装的内核文件。';

  @override
  String get uninstallKernel => '卸载内核';

  @override
  String get onlyTheseFilesWillBeRemovedAfterSavingABackupCloseSteamFirst =>
      '仅移除以下文件，移除前会保存备份。请先退出 Steam。';

  @override
  String get noOtherKernelFilesFound => '未发现其他内核残留。';

  @override
  String get cleanOtherKernels => '清理其他内核';

  @override
  String
  get selectFilesToRemoveTheyWillBeBackedUpLuaFoldersAndSteamCfgArePreserved =>
      '选择要移除的文件。会先备份，不会删除 Lua 目录或 steam.cfg。';

  @override
  String get backUpAndRemove => '备份并移除';

  @override
  String get kernelManagement => '内核管理';

  @override
  String get coreAndPlugins => '内核与核心插件';

  @override
  String get downloadsAndNetwork => '下载与网络';

  @override
  String get cloudRedirectPlugin => 'CloudRedirect 云存档插件';

  @override
  String get pluginManagement => '插件管理';

  @override
  String get installOrUpdatePlugin => '安装或更新插件';

  @override
  String get cloudRedirectPluginDescription =>
      '由 OpenSteamTool 在 Steam 进程内加载，为入库游戏重定向云存档。';

  @override
  String get kernelIntegration => '内核集成';

  @override
  String get openSteamtoolCore => 'OpenSteamTool 内核';

  @override
  String get actions => '操作';

  @override
  String get path => '路径';

  @override
  String get removeCloudRedirectPlugin => '卸载 CloudRedirect 插件';

  @override
  String get removeCloudRedirectPluginDescription =>
      '停用内核集成，备份并从 Steam 目录移除 CloudRedirect DLL。';

  @override
  String
  get officialAndLocalKernelPackagesAreCachedForOfflineSwitchingCloseSteamBeforeChangingIts =>
      '官方版本和自备内核统一保存在本地仓库，可离线切换。修改 Steam 文件前请先退出 Steam。';

  @override
  String get currentKernel => '当前内核';

  @override
  String get unknownVersion => '版本未知';

  @override
  String get noKernelInstalled => '尚未安装内核';

  @override
  String get disabled2 => '已停用';

  @override
  String get selectYourSteamFolderInSettingsFirst => '请先在设置中选择 Steam 目录。';

  @override
  String get bothInjectionEntriesAreActiveSelectOneEntry =>
      '检测到两个入口同时激活，请重新选择一个入口。';

  @override
  String get enableKernel => '启用内核';

  @override
  String get disableKernel => '停用内核';

  @override
  String get kernelFilesWillBeRenamedAfterSavingABackupCloseSteamFirst =>
      '将调整内核文件名。请先退出 Steam，现状会自动备份。';

  @override
  String get disable => '停用';

  @override
  String get enable => '启用';

  @override
  String get entryDwmapi => '入口：dwmapi';

  @override
  String get entryVersion => '入口：version';

  @override
  String get changeInjectionEntry => '更换注入入口';

  @override
  String get onlyTheSelectedEntryWillRemainActiveCloseSteamFirst =>
      '将只保留所选入口处于激活状态。请先退出 Steam。';

  @override
  String get fetchSteamSignatures => '获取 Steam 签名';

  @override
  String get uninstall => '卸载';

  @override
  String get availablePackages => '可用内核包';

  @override
  String get importZip => '导入 ZIP';

  @override
  String get refreshKernelReleases => '刷新内核版本';

  @override
  String get refreshToLoadOfficialReleasesOrImportALocalKernelZip =>
      '点击刷新获取官方版本，或导入自备 ZIP 内核包。';

  @override
  String get active => '当前';

  @override
  String get local2 => '本地包';

  @override
  String get official => '官方包';

  @override
  String get cached => '已缓存';

  @override
  String get notDownloaded => '未下载';

  @override
  String get downloadOnly => '仅下载';

  @override
  String get downloadKernel => '下载内核';

  @override
  String get switchLabel => '切换';

  @override
  String get deleteCache => '删除缓存';

  @override
  String deleteTheCachedPackageBackupsArePreserved(String displayName) {
    return '删除 $displayName 的本地缓存？切换备份会保留。';
  }

  @override
  String get switchAndRecoveryBackups => '切换与恢复备份';

  @override
  String get aRecoverableSnapshotIsSavedBeforeSwitchingOrUninstalling =>
      '切换或卸载前会自动保存可恢复的快照。';

  @override
  String get restoreKernelBackup => '恢复内核备份';

  @override
  String
  get restoreTheseFilesAndRemoveKernelFilesAbsentFromThisSnapshotCloseSteamFirst =>
      '将恢复这些文件，并移除快照中不存在的内核文件。请先退出 Steam。';

  @override
  String get repository => '本地仓库';

  @override
  String get luaSavedTheOriginalWasBackedUp => 'Lua 已保存，原文件已备份。';

  @override
  String get discardUnsavedChanges => '放弃未保存的修改？';

  @override
  String get theseChangesHaveNotBeenSavedToTheLuaFile => 'Lua 文件尚未写入这些修改。';

  @override
  String get enabled2 => '启用';

  @override
  String get commented => '注释';

  @override
  String manifestPinsSaveToApply(String changed, String commented) {
    return '已$commented $changed 行版本固定，保存后生效。';
  }

  @override
  String get enablePins => '启用版本固定';

  @override
  String get disablePins => '解除版本固定';

  @override
  String ctrlSToSaveOriginalBackedUpBeforeSavingLines(String value1) {
    return 'Ctrl+S 保存 · 保存前自动备份 · $value1 行';
  }

  @override
  String get directGithub => 'GitHub 直连';

  @override
  String get testCoverSources => '测试封面来源';

  @override
  String get testGithubDownloadSources => '测试 GitHub 下载来源';

  @override
  String get testCancelled => '测试已取消';

  @override
  String get networkAndDownloadSources => '网络与下载来源';

  @override
  String
  get chooseCoverAndPublicDownloadSourcesForYourConnectionTestsShowCurrentResultsWithoutCha =>
      '按当前网络选择封面和公开下载来源。测速只显示本次结果，不会自动更改偏好。';

  @override
  String get gameCovers => '游戏封面';

  @override
  String get preferredSource => '首选来源';

  @override
  String
  get byDefaultUseTheOfficialImageUrlFromGameDetailsThisPreferenceAffectsArtworkOnlyNotStea =>
      '默认使用游戏详情返回的官方图片地址。封面来源只影响图片，不影响 Steam 登录、商店接口或内容下载。';

  @override
  String get githubDownloads => 'GitHub 下载';

  @override
  String get preferredPublicDownloadSource => '首选公开下载来源';

  @override
  String get customGithubMirror => '自定义 GitHub 镜像';

  @override
  String get githubMirrorHint => 'https://mirror.example.com';

  @override
  String get directDefault => '直连（默认）';

  @override
  String
  get mirrorsApplyOnlyToAnonymousPublicGithubFileDownloadsSignInApiTokenAndCredentialBearin =>
      '镜像仅用于匿名的 GitHub 公开文件下载。登录、API、令牌和带凭证的请求始终直连。选择镜像意味着由该服务处理这些公开下载请求。';

  @override
  String get testPublicDownloadSources => '测试公开下载来源';

  @override
  String
  get testingSourcesViewOrCancelTheOperationInGlobalTasksNavigationKeepsItRunning =>
      '测试正在进行，可在全局任务中查看或取消。切换页面不会中断测试。';

  @override
  String get failed => '失败';

  @override
  String get gameManagement2 => '游戏管理工具';

  @override
  String get patchSettings => '补丁工具';

  @override
  String get patchSettingsDescription => '校验游戏文件、管理 Goldberg 并下载网络补丁。';

  @override
  String get patchTools => '补丁工具';

  @override
  String get patchToolsDescription =>
      '不提供通用补丁包安装。可以按 Steam 清单校验游戏文件，或使用网络补丁下载页。';

  @override
  String get gameFileVerification => '游戏文件校验';

  @override
  String get gameFileVerificationDescription => '按 Steam 记录的清单比对已安装文件。';

  @override
  String get gamePatchDownload => '游戏补丁下载';

  @override
  String get gamePatchDownloadDescription => '下载并解压网络补丁包，不自动安装到游戏。';

  @override
  String get goldbergEmulator => 'Goldberg 模拟器';

  @override
  String get goldbergSettings => 'Goldberg 设置';

  @override
  String get goldbergDescription => '为此游戏下载、部署并配置 Goldberg 模拟器。';

  @override
  String get goldbergSettingsFooter => '仅提供标准化的 Goldberg 部署；其他补丁包保持手动处理。';

  @override
  String get authorizationTicketDescription => '导入并校验票据，默认保留现有授权身份。';

  @override
  String get matchingLua => '对应 Lua';

  @override
  String get matchingLuaFound => '已找到此游戏对应的 Lua 文件。';

  @override
  String get matchingLuaMissing => '未找到对应 Lua 文件，仍可继续应用票据。';

  @override
  String get ticketActions => '授权操作';

  @override
  String get networkSource => '网络来源';

  @override
  String get selectedPatch => '已选择';

  @override
  String get loadPatches => '加载补丁表';

  @override
  String patchSourceLoaded(String count) {
    return '已加载 $count 个补丁选项。';
  }

  @override
  String get choosePatchType => '请先选择补丁类型。';

  @override
  String get patchType => '补丁类型';

  @override
  String get noPatchesAvailable => '暂无可用补丁';

  @override
  String get noPatchesAvailableDescription => '当前网络补丁表中没有此游戏的记录。';

  @override
  String get gamePatchDownloadFooter => '补丁压缩包会解压到应用下载目录，不会复制到游戏目录。';

  @override
  String downloadingPatch(String label) {
    return '正在下载 $label';
  }

  @override
  String get downloadPatch => '下载补丁';

  @override
  String patchDownloadComplete(String files, String size, String path) {
    return '已下载 $files 个文件（$size）到 $path。';
  }

  @override
  String patchDownloadFailed(String error) {
    return '补丁下载失败：$error';
  }

  @override
  String get patchExtracted => '补丁已解压';

  @override
  String virtualMachinePatch(String buildId) {
    return '虚拟机（BuildID: $buildId）';
  }

  @override
  String get v38Patch => 'V38 补丁';

  @override
  String get onlinePatch => '联机补丁（fix）';

  @override
  String get offlinePatch => '离线补丁（crack）';

  @override
  String get vbsPatch => 'VBS 补丁';

  @override
  String get searchFiles => '搜索文件';

  @override
  String get verifyGameFiles => '校验游戏文件';

  @override
  String get verificationTarget => '校验目标';

  @override
  String get gameDirectoryUnavailable => '游戏目录不可用。';

  @override
  String get verificationEmptyDescription =>
      '校验依据 appmanifest 和本地 depotcache 清单。异常文件仅作为建议，不会自动删除。';

  @override
  String get startVerification => '开始校验';

  @override
  String get filesMatchManifests => '文件与已安装清单一致';

  @override
  String filesNeedAttention(String count) {
    return '$count 个文件需要注意';
  }

  @override
  String verifiedCount(String count) {
    return '一致 $count';
  }

  @override
  String missingCount(String count) {
    return '缺失 $count';
  }

  @override
  String changedCount(String count) {
    return '已修改 $count';
  }

  @override
  String unexpectedCount(String count) {
    return '非清单 $count';
  }

  @override
  String unverifiedCount(String count) {
    return '未校验 $count';
  }

  @override
  String manifestSummary(String depots, String manifests) {
    return '共 $depots 个仓库 · 已解析 $manifests 个清单';
  }

  @override
  String get manifestNotes => '清单说明';

  @override
  String get manifestVerificationWarning =>
      '加密清单需要游戏 Lua 文件中的仓库密钥；无法比对的文件会在此说明。';

  @override
  String get manifestInventoryOnly => '缺少清单数据，当前仅显示游戏文件清单';

  @override
  String get manifestPartialSummary => '已校验部分仓库，未匹配文件需要手动确认';

  @override
  String get allFiles => '全部文件';

  @override
  String get issuesOnly => '问题文件';

  @override
  String get unexpectedFiles => '非清单文件';

  @override
  String get noMatchingFiles => '没有匹配的文件';

  @override
  String get verificationResults => '校验结果';

  @override
  String get unexpectedFilesHint => '非清单文件仅为建议，修改或删除前请自行确认。';

  @override
  String get unverifiedFilesHint => '缺少可读清单的仓库文件无法判断是否为非游戏文件。';

  @override
  String get verified => '一致';

  @override
  String get changed => '已修改';

  @override
  String get unexpected => '非清单';

  @override
  String get unverified => '未校验';

  @override
  String expectedSize(String size) {
    return '预期 $size 字节';
  }

  @override
  String actualSize(String size) {
    return '实际 $size 字节';
  }

  @override
  String get emulatorNotDownloaded => '尚未缓存 Goldberg 发行版。';

  @override
  String currentEmulatorVersion(String version) {
    return '当前缓存版本：$version';
  }

  @override
  String get goldbergDeployDescription =>
      '用缓存的 Goldberg 构建替换此游戏中已有的 Steam API DLL。';

  @override
  String get connectionAndIdentity => '连接与身份';

  @override
  String get steamId => 'SteamID';

  @override
  String get dlcIds => 'DLC ID';

  @override
  String get depotIds => '仓库 ID';

  @override
  String get steamInterfaces => 'Steam 接口';

  @override
  String get steamInput => 'Steam Input';

  @override
  String get contentConfiguration => '内容配置';

  @override
  String get behavior => '行为';

  @override
  String get configurationActions => '配置操作';

  @override
  String get jsonDefinitions => 'JSON 定义';

  @override
  String get luaExtraction => 'Lua 提取';

  @override
  String get luaExtractionDescription =>
      '查询目标 Steam App，获取账号已授权的仓库密钥，生成 Lua 文件并可选下载清单。账号必须真实拥有该游戏。';

  @override
  String get denuvoTicketExtraction => 'D 加密票据提取';

  @override
  String get denuvoTicketExtractionDescription =>
      '从本机已登录的 Steam 用户提取 AppTicket 和 ETicket。账号必须真实拥有该游戏。';

  @override
  String get steamLoginRequired => '请先登录 Steam 再提取 Lua 内容。';

  @override
  String get useLocalSteamLogin => '使用本机 Steam 登录';

  @override
  String get useLocalSteamLoginDescription =>
      '从 local.vdf 读取本机已登录的 Steam 账号，无需重新输入密码。';

  @override
  String get localSteamLoginUnavailable =>
      '未找到可用的本机 Steam 登录。请启动并登录 Steam，或使用下方手动登录。';

  @override
  String get realOwnershipRequiredNotice =>
      '必须真实拥有：仅对你本人已购买的游戏使用提取功能。本应用不校验购买记录。';

  @override
  String get notSignedIn => '未登录';

  @override
  String get luaLoginDescription => '提取时会尝试使用本机 Steam 会话，也可打开账号页登录。';

  @override
  String get appIdForExtraction => '游戏 AppID';

  @override
  String get outputDirectory => '输出目录';

  @override
  String get useDefaultOutputDirectory => '使用应用下载目录';

  @override
  String get extractionTarget => '提取目标';

  @override
  String get extractionOptions => '提取选项';

  @override
  String get copyAchievements => '附带本地成就缓存';

  @override
  String get extractionResult => '提取结果';

  @override
  String extractingLua(String appId) {
    return '正在提取 AppID $appId 的 Lua';
  }

  @override
  String get extractLua => '提取 Lua';

  @override
  String luaExtractionComplete(String keys, String manifests) {
    return 'Lua 提取完成 · $keys 个仓库密钥 · $manifests 个清单';
  }

  @override
  String get ownershipRequired => '当前 Steam 账号并未真实拥有此游戏。';

  @override
  String get steamMustBeRunningAndSignedIn => '请先启动 Steam，并登录真实拥有该游戏的账号。';

  @override
  String get outputDirectoryDoesNotExist => '输出目录不存在。';

  @override
  String get ticketExtractionFileHeader => '由 FlSteamLua 提取，请在票据过期前使用。';

  @override
  String ticketExtractionComplete(String path) {
    return '票据已写入 $path';
  }

  @override
  String get ticketExtractionOptions => '票据选项';

  @override
  String get extractDenuvoTicket => '提取票据';

  @override
  String get openAuthorizationPage => '打开授权页面';

  @override
  String get patchesRestore => '补丁与还原';

  @override
  String get tickets => '授权资料';

  @override
  String get gameDirectory => '游戏目录';

  @override
  String get selectGameDirectory => '选择游戏目录';

  @override
  String get choose => '选择';

  @override
  String get patchInstallation => '补丁安装';

  @override
  String
  get previewFilesBeforeInstallationOriginalsAreBackedUpAndLaterChangesAreCheckedBeforeRest =>
      '先预览文件，覆盖前自动备份。还原时检查补丁安装后被修改的文件。';

  @override
  String get choosePatchArchive => '选择补丁包';

  @override
  String get inspectExecutable => '检查可执行文件';

  @override
  String
  get downloadTheUpstreamWindowsReleaseOnDemandDeploymentReplacesExistingSteamApiDllsAndCre =>
      '按需下载上游 Windows 发行版。部署只替换已存在的 Steam API DLL，并生成可还原备份；配置在下一个标签页。';

  @override
  String get downloadUpdateEmulator => '下载/更新模拟器';

  @override
  String get deployGoldberg => '部署 Goldberg';

  @override
  String
  get replaceSteamApiDllsInThisGameDirectoryOriginalFilesWillBeSavedInApplicationBackups =>
      '将替换游戏目录中的 Steam API DLL，原文件保存在应用备份目录。继续？';

  @override
  String get deployToThisGame => '部署到此游戏';

  @override
  String get patchBackups => '补丁备份';

  @override
  String get noPatchBackupsForThisGame => '此游戏暂无补丁备份。';

  @override
  String get restored => '已还原';

  @override
  String get available => '可还原';

  @override
  String get restore2 => '还原';

  @override
  String get inspectPatchArchive => '检查补丁包';

  @override
  String get thisArchiveContainsManifestsOnlyImportItFromTheLibrary =>
      '该压缩包仅含清单，请使用库的导入功能。';

  @override
  String get installPatch => '安装补丁';

  @override
  String get restorePatchBackup => '还原补丁备份';

  @override
  String get restorePatch => '还原补丁';

  @override
  String get fileHasChanged => '文件已发生变化';

  @override
  String
  get theseFilesWereModifiedAfterPatchInstallationReplaceThemWithTheOriginalBackupsAnyway =>
      '这些文件在安装补丁后被修改。仍然使用安装前备份覆盖？';

  @override
  String get inspectPeExecutable => '检查 PE 文件';

  @override
  String
  get aBindSectionWasFoundAutomaticUnpackingIsNotIncludedTheOriginalSteamlessCodeDeclaresCc =>
      '检测到 .bind 节。自动脱壳当前未提供：原 Steamless 源码声明 CC BY-NC-ND 4.0，不能直接改作并随本 GPL 项目分发。未修改此文件。';

  @override
  String get noBindSectionFoundThisDoesNotIdentifyOtherProtectionTypes =>
      '未检测到 .bind 节；此结果不判断其他保护类型。';

  @override
  String get downloadGoldberg => '下载 Goldberg';

  @override
  String get downloadEmulator => '下载模拟器';

  @override
  String get emulatorConfiguration => '模拟器配置';

  @override
  String
  get unknownIniKeysArePreservedInputIsValidatedAndConfigurationFilesAreBackedUpBeforeSavin =>
      '保留原 INI 中未识别的键。保存前验证输入，并备份配置文件。';

  @override
  String get accountName => '账号名';

  @override
  String get applicationTicketBase64 => '应用票据（Base64）';

  @override
  String get languageCode => '语言代码';

  @override
  String get listenPort => '监听端口';

  @override
  String get localSavePath => '本地存档路径';

  @override
  String get supportedLanguages => '支持的语言';

  @override
  String get customBroadcasts => '自定义广播地址';

  @override
  String get disableNetworking => '关闭网络';

  @override
  String get offlineMode => '离线模式';

  @override
  String get allDlc => '全部 DLC';

  @override
  String get emulatedCloudSaves => '模拟云存档目录';

  @override
  String get createCloudDirectory => '自动创建云目录';

  @override
  String get experimentalOverlay => '实验性 Overlay';

  @override
  String get saveGoldbergConfiguration => '保存 Goldberg 配置';

  @override
  String get saveConfiguration => '保存配置';

  @override
  String get achievementsStatsItemsJson => '成就/统计/物品 JSON';

  @override
  String get exportZip => '导出 ZIP';

  @override
  String get importConfigurationZip => '导入配置 ZIP';

  @override
  String get reload2 => '重新载入';

  @override
  String get editJsonDefinitions => '编辑 JSON 定义';

  @override
  String get applyToDraft => '应用到编辑副本';

  @override
  String get exportConfiguration => '导出配置';

  @override
  String get exportGoldbergConfiguration => '导出 Goldberg 配置';

  @override
  String get importConfiguration => '导入配置';

  @override
  String get existingConfigurationWillBeBackedUpBeforeReplacementContinue =>
      '覆盖已有配置前将生成备份。继续？';

  @override
  String get importGoldbergConfiguration => '导入 Goldberg 配置';

  @override
  String get authorizationTickets => '票据管理';

  @override
  String get authorization => '授权';

  @override
  String get denuvoAuthorization => 'D 加密票据管理';

  @override
  String get denuvoAuthorizationDescription =>
      '提取、备份并管理 AppTicket 与 ETicket，授权身份由用户明确选择。';

  @override
  String
  get importedTicketsTxtFilesAreCheckedForAppidAndPayloadLengthsLocalBackupsUseCurrentUserW =>
      '导入 tickets.txt 后校验 AppID 和票据长度。本地备份使用当前 Windows 用户的 DPAPI 加密；只有点击写入时才修改 Steam 注册表。';

  @override
  String get importTicketsTxt => '导入 tickets.txt';

  @override
  String get importOneTicketFileAtATime => '请一次只导入一个 tickets.txt 文件。';

  @override
  String get applyToSteam => '写入 Steam';

  @override
  String get saveTicketBackup => '保存加密票据备份';

  @override
  String get encryptedBackup => '加密备份';

  @override
  String get exportPlaintextFile => '导出明文文件';

  @override
  String get encryptedBackups => '加密备份';

  @override
  String get noSavedTickets => '尚未保存授权资料。';

  @override
  String get loadTicket => '读取授权资料';

  @override
  String get load => '读取';

  @override
  String get deleteEncryptedBackup => '删除加密备份';

  @override
  String get deleteTicketBackup => '删除授权备份';

  @override
  String get validateTicketFile => '校验授权资料';

  @override
  String get applySteamTicket => '应用票据';

  @override
  String get thisReplacesExistingAppticketAndEticketValuesForThisGame =>
      '将备份并替换此游戏的两张票据，默认保留缓存授权身份。';

  @override
  String get applyTicket => '写入票据';

  @override
  String get exportPlaintextTicket => '导出明文授权';

  @override
  String get exportTicket => '导出授权资料';

  @override
  String get configureTheReleaseRepositoryForThisFlutterApplicationFirst =>
      '请先设置此 Flutter 应用的发布仓库。';

  @override
  String get checkApplicationUpdates => '检查应用更新';

  @override
  String get setStartupRegistration => '设置开机启动';

  @override
  String get setSteamOfflineMode => '设置 Steam 离线模式';

  @override
  String get selectTheSteamFolderFirst => '请先选择 Steam 安装目录。';

  @override
  String get setFriendPresence => '设置好友广播';

  @override
  String get backgroundAndSteamPreferences => '后台与 Steam 偏好';

  @override
  String get readSteamAndStartupState => '重新读取 Steam 与启动状态';

  @override
  String get automaticTasks => '自动任务';

  @override
  String get refreshTheLibraryAutomatically => '自动刷新游戏库';

  @override
  String
  get watchManifestsAndLuaFilesAndScanAtTheSelectedIntervalRefreshManuallyFromTheLibraryWhe =>
      '观察清单与 Lua 变化，并按间隔检查。关闭后可在游戏库手动刷新。';

  @override
  String get refreshInterval => '刷新间隔';

  @override
  String seconds(String seconds) {
    return '$seconds 秒';
  }

  @override
  String get checkForApplicationUpdatesAutomatically => '自动检查应用更新';

  @override
  String
  get checkAtStartupAndEvery24HoursUsingTheConfiguredFlutterApplicationReleaseRepository =>
      '启动时和每 24 小时检查一次，仅使用设置中填写的 Flutter 应用发布仓库。';

  @override
  String get updateKeySubscriptionsAutomatically => '自动更新密钥订阅';

  @override
  String
  get whenEnabledCheckEnabledSubscriptionsHourlyAndDownloadUpdatesWhenTheirSourceIntervalIs =>
      '开启后每小时检查已启用订阅的到期时间，并按来源间隔联网更新。';

  @override
  String newVersion(String version) {
    return '发现新版本 $version';
  }

  @override
  String get viewReleaseNotesAndDownloadsInSettings => '返回设置查看发布说明与下载。';

  @override
  String get startupAndSteam => '启动与 Steam';

  @override
  String get launchFlsteamluaAtSignIn => '开机启动 FlSteamLua';

  @override
  String get readTheCurrentStateWithTheRefreshButton => '点击右上角刷新按钮读取当前状态。';

  @override
  String get startWhenTheCurrentUserSignsInToWindows => '当前用户登录 Windows 后启动。';

  @override
  String get broadcastPlayStatusToFriends => 'Lua 游戏好友广播';

  @override
  String
  get allowTheKernelToShowPlayStatusToSteamFriendsThroughSpacewarDisableToHideTheseBroadcas =>
      '允许内核以 Spacewar 向 Steam 好友显示游玩状态；关闭后隐藏这类广播。';

  @override
  String get broadcastStateHasNotBeenReadYet => '广播状态尚未读取。';

  @override
  String get steamOfflineMode => 'Steam 离线模式';

  @override
  String
  get setOfflineOptionsForTheMostRecentAccountAppliesOnTheNextSteamLaunchWithoutRestartingS =>
      '设置最近登录账号的离线选项，下次启动 Steam 生效。不会自动关闭或重启 Steam。';

  @override
  String get noRecentSteamAccountWasReadSignInToSteamThenRefreshTheState =>
      '未读取到最近登录账号。请先登录 Steam，再刷新状态。';

  @override
  String lastBackgroundTaskFailure(String backgroundError) {
    return '上次后台任务失败：$backgroundError';
  }

  @override
  String get steamGuardVerification => 'Steam Guard 验证';

  @override
  String get enterTheCodeFromYourEmail => '请输入邮件中的验证码。';

  @override
  String get enterYourSteamMobileAuthenticatorCode => '请输入 Steam 手机令牌验证码。';

  @override
  String get approveThisSignInInTheSteamMobileAppThenContinue =>
      '请在 Steam 手机应用中批准本次登录，然后继续。';

  @override
  String get code => '验证码';

  @override
  String get signInToSteam => '登录 Steam';

  @override
  String get enterAValidAppid => '请输入有效的 AppID';

  @override
  String get selectTheExportFolder => '选择提取文件的保存目录';

  @override
  String extractGame(String id) {
    return '提取游戏 $id';
  }

  @override
  String get depotKeys => '已提取密钥';

  @override
  String get savedManifests => '已保存清单';

  @override
  String get itemsNotCompleted => '以下项目未完成';

  @override
  String get filesSaved => '文件已保存';

  @override
  String get steamAccountExtraction => 'Steam 账号与提取';

  @override
  String
  get connectToSteamToExportManifestsAccessibleToThisAccountYourPasswordIsUsedOnlyForSignIn =>
      '连接 Steam 以获取当前账号可访问的游戏清单。密码仅用于本次登录。';

  @override
  String get connectedToSteam => '已连接 Steam';

  @override
  String get signOut => '退出登录';

  @override
  String get signOutAndForgetSession => '退出并清除登录信息';

  @override
  String get accountName2 => '账号名称';

  @override
  String get password => '密码';

  @override
  String get signIn => '登录';

  @override
  String get restoreSteamSession => '恢复 Steam 会话';

  @override
  String get useSavedSession => '使用已保存的登录信息';

  @override
  String get exportLuaManifests => '提取 Lua 与清单';

  @override
  String get includeAccessibleDlc => '包含可访问的 DLC';

  @override
  String get downloadManifestFiles => '下载清单文件';

  @override
  String get pinCurrentPublicManifestVersions => '固定当前公开清单版本';

  @override
  String get chooseFolderExport => '选择目录并提取';

  @override
  String get store => '商店';

  @override
  String get discoverGamesPurchaseAndInstallThroughSteam =>
      '发现游戏，在 Steam 购买或安装。';

  @override
  String get searchGameTitles => '搜索游戏名称';

  @override
  String get showAdultContent => '显示成人内容';

  @override
  String get hideAdultContent => '隐藏成人内容';

  @override
  String get storeRegion => '商店地区';

  @override
  String get regionChinaMainland => '中国大陆';

  @override
  String get regionHongKong => '中国香港';

  @override
  String get regionTaiwan => '中国台湾';

  @override
  String get regionUnitedStates => '美国';

  @override
  String get regionJapan => '日本';

  @override
  String get regionSouthKorea => '韩国';

  @override
  String get regionSingapore => '新加坡';

  @override
  String get regionUnitedKingdom => '英国';

  @override
  String get regionGermany => '德国';

  @override
  String get regionFrance => '法国';

  @override
  String get regionCanada => '加拿大';

  @override
  String get regionAustralia => '澳大利亚';

  @override
  String get regionBrazil => '巴西';

  @override
  String get regionRussia => '俄罗斯';

  @override
  String get regionArgentina => '阿根廷';

  @override
  String get search => '搜索';

  @override
  String get popular => '热门游戏';

  @override
  String get newReleases => '最新发售';

  @override
  String get specials => '特惠';

  @override
  String get comingSoon => '即将发售';

  @override
  String get noMatchingGames2 => '没有找到相关游戏';

  @override
  String get storeUnavailable => '暂时无法连接商店';

  @override
  String get reload3 => '重新加载';

  @override
  String ofGames(String itemsCount, String total) {
    return '已展示 $itemsCount / $total 款';
  }

  @override
  String get loadMore => '加载更多';

  @override
  String get allResultsLoaded => '已展示所有结果';

  @override
  String get viewStorePrice => '查看商店价格';

  @override
  String get viewFixFiles => '查看补丁';

  @override
  String get fixFiles => '补丁目录';

  @override
  String get downloadOnlineFix => '下载联机补丁';

  @override
  String get downloaded => '已下载';

  @override
  String get archivePasswordOnlineFixMe => '解压密码：online-fix.me';

  @override
  String get copyPassword => '复制密码';

  @override
  String get instructionsOriginalText => '使用说明（原文）';

  @override
  String get showMore => '展开';

  @override
  String get showLess => '收起';

  @override
  String get filesAndInstructionsAreSavedInASeparateFolderForEachGame =>
      '下载文件和使用说明保存在独立的游戏目录。';

  @override
  String get sourcePage => '来源页面';

  @override
  String get parentFolder => '上级目录';

  @override
  String get cancelDownload => '取消下载';

  @override
  String get download => '下载';

  @override
  String get noFixFilesAreAvailableInThisDirectory => '此目录暂无补丁文件。';

  @override
  String get noMatchingOnlineFixes => '没有匹配的联机补丁';

  @override
  String get noOnlineFixesAvailable => '暂时没有可用的联机补丁';

  @override
  String get searchAGameForFixFilesAndInstructions => '搜索游戏，查看补丁与使用说明';

  @override
  String get sourceOnlineFixMe => '来源：online-fix.me';

  @override
  String get fixActions => '补丁操作';

  @override
  String get backToResults => '返回搜索结果';

  @override
  String get searchOnlineFixes => '搜索联机补丁';

  @override
  String get spacewar480Multiplayer => '480 联机';

  @override
  String
  get withAKernelThatSupportsOst480MultiplayerLaunchOptionsMapTheGameToSpacewarBothPlayersM =>
      '使用 OST 内核的 480 联机功能时，通过启动参数将当前游戏映射到 Spacewar。双方均需使用相同的联机方式。';

  @override
  String get setup => '启用步骤';

  @override
  String
  get message1RightClickTheGameInSteamAndOpenProperties2AddTheOptionBelowToLaunchOptions3St =>
      '1. 在 Steam 库中右键游戏，打开“属性”。\n2. 在“启动选项”中填入下面的参数。\n3. 启动游戏。需要恢复时删除该参数。';

  @override
  String get copyLaunchOption => '复制启动参数';

  @override
  String
  get requiresACompatibleKernelAndLobbyBasedGameOnlyOneSuchGameCanRunAtATime =>
      '仅适用于支持该参数的内核和大厅匹配游戏；同一时间只能运行一个此类游戏。';

  @override
  String get downloads => '下载目录';

  @override
  String get spacewar480 => '480 联机';

  @override
  String get previousPage => '上一页';

  @override
  String get nextPage => '下一页';

  @override
  String get goToPage => '跳转到指定页';

  @override
  String get pageNumber => '页码';

  @override
  String pageOutOfRange(int totalPages) {
    return '请输入 1 到 $totalPages 之间的页码';
  }

  @override
  String get downloadTrainer => '下载修改器';

  @override
  String get thisArchiveIsAvailableForDirectDownload => '此归档可直接下载。';

  @override
  String get addGameBinding => '添加游戏绑定';

  @override
  String get editGameBinding => '编辑游戏绑定';

  @override
  String get chooseFromLibrary => '从游戏库选择';

  @override
  String get enterAValidAppid2 => '输入有效 AppID';

  @override
  String get gameName => '游戏名称';

  @override
  String get enterTheGameName => '填写游戏名称';

  @override
  String get gameExecutable => '游戏程序';

  @override
  String get chooseGameExecutable => '选择游戏程序';

  @override
  String get trainerExecutable => '修改器程序';

  @override
  String get chooseTrainerExecutable => '选择修改器程序';

  @override
  String get useADownloadedTrainer => '使用已下载修改器';

  @override
  String get startAndStopWithTheGame => '随游戏启动和结束';

  @override
  String get deleteTrainer => '删除修改器';

  @override
  String get associatedGameBindingsWillAlsoBeRemoved => '相关游戏绑定也会移除。';

  @override
  String get delete => '删除';

  @override
  String get searchGameNames => '搜索游戏名称，支持中文';

  @override
  String get clear => '清空';

  @override
  String get recentUpdates => '最近更新';

  @override
  String get allTrainers => '全部修改器';

  @override
  String get archive => '旧版归档';

  @override
  String get trainers2 => '个修改器';

  @override
  String get loadingFling => '正在读取 FLiNG…';

  @override
  String get noMatchingTrainers => '没有匹配的修改器';

  @override
  String get downloadAgain => '再次下载';

  @override
  String get myTrainers => '我的修改器';

  @override
  String get downloadFolder => '下载目录';

  @override
  String get noDownloadedTrainers => '尚未下载修改器';

  @override
  String get downloadFromBrowseThenOpenArchivesToExtractAndBindAnExecutable =>
      '在“浏览”中下载，压缩包可先打开解压再绑定程序。';

  @override
  String get stop3 => '停止';

  @override
  String get open => '打开';

  @override
  String get manageTrainer => '管理修改器';

  @override
  String get bindToGame => '绑定游戏';

  @override
  String get openContainingFolder => '打开所在目录';

  @override
  String get createDesktopShortcut => '创建桌面快捷方式';

  @override
  String get gameAndTrainerBindings => '游戏与修改器联动';

  @override
  String get addBinding => '添加绑定';

  @override
  String get bindALocalTrainerToAGame => '为游戏绑定一个本地修改器';

  @override
  String get enabledTrainersStartAndStopWithTheDetectedGameProcess =>
      '启用后，修改器随已识别的游戏进程启动与结束。';

  @override
  String get launch2 => '启动';

  @override
  String get editBinding => '编辑绑定';

  @override
  String get removeBinding => '解绑';

  @override
  String get browse => '浏览';

  @override
  String get gameBindings => '游戏绑定';

  @override
  String get operationFailed => '操作未完成';

  @override
  String get chooseOutputFolder => '选择输出目录';

  @override
  String get luaVdfConversion => 'Lua / VDF 转换';

  @override
  String get writesNewFilesWithoutOverwritingLuaToVdfRequiresAnAppid =>
      '输出到新文件；已有文件不会覆盖。Lua 转 VDF 时需要 AppID。';

  @override
  String get appidOptional => 'AppID（可选）';

  @override
  String get includeManifestPinsWhenConvertingVdf => 'VDF 转 Lua 时包含固定版本';

  @override
  String get convert => '转换';

  @override
  String get convertFiles => '转换文件';

  @override
  String get chooseSourceFolder => '选择源目录';

  @override
  String get batchConversion => '批量转换';

  @override
  String get pinGameVersion => '固定游戏版本';

  @override
  String get pinCurrentlyInstalledManifests => '固定当前已安装版本';

  @override
  String get pinLatestPublicManifests => '固定当前公开最新版本';

  @override
  String get unpinKeepCommentedRecords => '解除固定（保留注释记录）';

  @override
  String get updateManifestPins2 => '更新固定版本';

  @override
  String get addDlcAppids => '添加 DLC AppID';

  @override
  String get dlcAppidsSeparatedBySpacesCommasOrNewlines =>
      '输入以空格、逗号或换行分隔的 DLC AppID';

  @override
  String get addToLua => '添加到 Lua';

  @override
  String get addDlc => '添加 DLC';

  @override
  String get environmentDiagnostics => '环境诊断';

  @override
  String get manifestMonitorAndDownloadRepair => '清单监听与下载修复';

  @override
  String
  get watchNewSteamContentLogRequestsAndDownloadManifestsFromCodeProvidersAndSteamCdnIntoDe =>
      '监听 Steam content_log 新请求，并从清单代码源及 Steam CDN 下载到 depotcache。任务在切页后继续。';

  @override
  String get noLogEntriesYet => '尚无监听记录';

  @override
  String get stopMonitoring => '停止监听';

  @override
  String get startMonitoring => '开始监听';

  @override
  String get tools => '工具中心';

  @override
  String get openToolsAsNeededOrStartFromAGameSDetailPage =>
      '按需打开工具，游戏相关操作也可以从游戏详情进入。';

  @override
  String get filesAndManifests => '文件与清单';

  @override
  String get convertLuaVdfAndAcfFilesToASeparateOutputFolder =>
      '单个或多个 Lua、VDF、ACF 文件，转换到独立输出目录';

  @override
  String get convertAFolder => '批量转换目录';

  @override
  String get processAllSupportedFilesInAFolder => '处理目录中的全部可转换文件';

  @override
  String get manifestMonitoring => '清单请求监听';

  @override
  String get fetchMissingManifestsRequestedBySteam => '跟随 Steam 下载请求补充缺失清单';

  @override
  String get manifestVersionPins => '版本固定';

  @override
  String get installedManifestsLatestPublicManifestsOrUnpin =>
      '当前安装版、公开最新版或解除固定';

  @override
  String get appendDlcEntriesWithoutDuplicatingExistingRecords =>
      '追加 DLC 记录，保留已存在的内容';

  @override
  String get downloadCover => '下载封面';

  @override
  String get saveToTheApplicationCoverCache => '保存到应用封面缓存';

  @override
  String get gameTools => '游戏工具';

  @override
  String get searchDownloadAndBindTrainers => '搜索、下载与游戏绑定';

  @override
  String get findOnlineFixesAndDownloadFiles => '检索联机补丁并下载文件';

  @override
  String get openTool => '打开相关工具';

  @override
  String get maintenance => '维护';

  @override
  String get diagnostics => '环境诊断';

  @override
  String get steamPathClientAndDataDirectories => 'Steam 路径、客户端及数据目录';

  @override
  String get openLogFolder => '打开日志目录';

  @override
  String get logFolder => '日志目录';

  @override
  String get openBackupFolder => '打开备份目录';

  @override
  String get backupFolder => '备份目录';

  @override
  String get openFlsteamlua => '打开 FlSteamLua';

  @override
  String get quit => '退出';

  @override
  String get collapseSidebar => '收起侧边栏';

  @override
  String get expandSidebar => '展开侧边栏';

  @override
  String get contentSources => '内容源';

  @override
  String get allSources => '全部';

  @override
  String get luaSources => 'Lua';

  @override
  String get manifestSources => '清单';

  @override
  String get enabledSources => '已启用';

  @override
  String get failedSources => '异常';

  @override
  String get subscriptionSource => '订阅';

  @override
  String get scriptSource => 'JS 脚本';

  @override
  String get localSource => '本地';

  @override
  String get manifestIds => '清单 ID';

  @override
  String get manifestFiles => '清单文件';

  @override
  String get addContentSource => '添加内容源';

  @override
  String get addSubscriptionSource => '添加订阅源';

  @override
  String get importScriptSource => '导入 JS 内容源';

  @override
  String get importLocalContent => '本地导入';

  @override
  String get editSource => '编辑';

  @override
  String get editScript => '编辑脚本';

  @override
  String get configureSource => '配置源';

  @override
  String get validateScript => '校验脚本';

  @override
  String get restoreBuiltInScript => '恢复内置脚本';

  @override
  String get openScriptFolder => '打开脚本目录';

  @override
  String get scriptSaved => '脚本已保存';

  @override
  String get scriptIsValid => '脚本语法与元数据有效';

  @override
  String get theseScriptChangesHaveNotBeenSaved => '脚本修改尚未保存。';

  @override
  String get testSource => '测试';

  @override
  String get updateSource => '更新';

  @override
  String get enableSource => '启用';

  @override
  String get disableSource => '停用';

  @override
  String get deleteSource => '删除';

  @override
  String get deleteSourceConfirm => '删除内容源及其本地配置？';

  @override
  String get sourceConfigurationRequired => '需要配置';

  @override
  String get sourceConfigured => '已配置';

  @override
  String get sourceNotTested => '已配置，尚未测试';

  @override
  String get sourceNeverUpdated => '尚未更新';

  @override
  String get noContentSources => '尚未添加内容源';

  @override
  String get contentImport => '添加到 Lua 库';

  @override
  String get luaContentSource => 'Lua 内容源';

  @override
  String get manifestContentSource => '清单来源（可选）';

  @override
  String get noManifestSource => '不指定，由 Steam 或内核获取';

  @override
  String get previewContent => '预览内容';

  @override
  String get importContent => '确认入库';

  @override
  String get contentImportComplete => '入库完成';

  @override
  String get contentImportReplace => '替换已有文件并备份';

  @override
  String get configureContentSources => '管理内容源';

  @override
  String get sourceName => '名称';

  @override
  String get depotKeysUrl => '仓库密钥 JSON URL';

  @override
  String get appTokensUrl => '访问令牌 JSON URL';

  @override
  String get sourceUpdateInterval => '更新间隔（小时）';

  @override
  String get sourceEnabled => '启用此内容源';

  @override
  String get requiredField => '必填';

  @override
  String get invalidUrl => '请输入 HTTP 或 HTTPS URL';

  @override
  String get invalidUpdateInterval => '请输入 0–8760 之间的整数。';

  @override
  String get sourceTestSucceeded => '测试成功';

  @override
  String get sourceUpdateComplete => '更新完成';

  @override
  String get includeDlc => '包含 DLC';

  @override
  String get pinManifestVersions => '固定清单版本';

  @override
  String get refreshContentMetadata => '在线准备仓库信息';

  @override
  String get contentImportNoLuaSource => '请先添加或启用提供 Lua 的内容源';

  @override
  String get originalCoverUrl => '原始封面地址';

  @override
  String get steamStoreApi => 'Steam 商店接口';

  @override
  String get heyboxApi => '小黑盒接口';

  @override
  String get akamaiMain => 'Akamai 主节点';

  @override
  String get akamaiBackup => 'Akamai 备用';

  @override
  String get cloudflareCdn => 'Cloudflare CDN';

  @override
  String get akamaiPortrait => 'Akamai 竖版大图';

  @override
  String get contentImportNoLocalLua =>
      '未找到包含有效 addappid 的 Lua 配置。仅有清单文件不能新增入库。';

  @override
  String get contentImportPerGame => '每个游戏独立提交。失败项会单独列出，不会撤销已成功入库的其他游戏。';

  @override
  String get settings => '设置';

  @override
  String get tools2 => '工具';

  @override
  String get downloadManageTrainers => '修改器下载与管理';

  @override
  String get addLuaFromAContentSource => '从内容源添加 Lua';

  @override
  String get accountExtraction => '账号与提取';

  @override
  String get patchesLicenses => '补丁与授权管理';

  @override
  String get manageAchievements2 => '成就管理';

  @override
  String get dashboard => '面板主页';

  @override
  String get showPanel => '显示面板';

  @override
  String get hidePanel => '隐藏面板';

  @override
  String get accountExtraction2 => '账号登录与提取';

  @override
  String get steamAccount => 'Steam 账号';

  @override
  String get accountManagement => '账号管理';

  @override
  String get steamAccounts => 'Steam 账号';

  @override
  String get addSteamAccount => '添加 Steam 账号';

  @override
  String get addSteamAccountDescription =>
      '调起 Steam 自己的登录流程；FlSteamLua 不会索取 Steam 密码。';

  @override
  String get currentSteamAccount => '当前账号';

  @override
  String get switchSteamAccount => '切换账号';

  @override
  String get steamWillRestartToSwitchAccount => 'Steam 将重启并切换到该账号。';

  @override
  String get steamWillOpenItsOwnLogin => '将调起 Steam 自己的登录流程，请在那里登录后返回并刷新账号列表。';

  @override
  String get noSteamAccounts => '未找到 Steam 账号';

  @override
  String get noSteamAccountsDescription => '请启动并登录 Steam，然后刷新此页面。';

  @override
  String get accountManagerHint => '切换账号会重启 Steam；账号凭据始终由 Steam 管理。';

  @override
  String get chooseAFolder => '选择文件夹';

  @override
  String get chooseTheSteamInstallationFolderContainingSteamExe =>
      '请选择包含 steam.exe 的 Steam 安装目录。';

  @override
  String get theLuaFolderDoesNotExistChooseAnExistingFolder =>
      'Lua 文件夹不存在，请先选择已有文件夹。';

  @override
  String get refreshGameLibrary => '刷新游戏库';

  @override
  String get pathsSavedAndGameLibraryRefreshed => '路径已保存，游戏库已刷新。';

  @override
  String get useOwnerRepositoryForExampleYournameFlsteamlua =>
      '填写 owner/repository 格式，例如 yourname/FlSteamLua。';

  @override
  String get theFlsteamluaReleaseRepositoryIsNotConfigured =>
      '尚未设置 FlSteamLua 发布仓库。';

  @override
  String get youAreUsingTheLatestPublishedVersion => '当前已是最新发布版本。';

  @override
  String get noReleaseNotesWereProvided => '此版本没有发布说明。';

  @override
  String get later => '稍后';

  @override
  String get releasePage => '发布页面';

  @override
  String get downloadUpdate => '下载更新';

  @override
  String get downloadApplicationUpdate => '下载应用更新';

  @override
  String updateDownloaded(String path) {
    return '更新已下载：$path';
  }

  @override
  String get updateReadyTitle => '更新已准备就绪';

  @override
  String get updateReadyDescription =>
      '更新文件已通过校验。下一步将关闭 FlSteamLua 并立即运行安装程序，是否继续？';

  @override
  String get installUpdateNow => '立即安装';

  @override
  String get openFolder2 => '打开文件夹';

  @override
  String get makeYourGameCompanionFeelAtHome => '让游戏工具按你的习惯工作。';

  @override
  String get steamAndGameFiles => 'Steam 与游戏文件';

  @override
  String get steamInstallationFolder => 'Steam 安装目录';

  @override
  String get theFolderContainingSteamExe => '包含 steam.exe 的文件夹';

  @override
  String get luaFolder => 'Lua 文件夹';

  @override
  String get saveAndRefreshLibrary => '保存并刷新游戏库';

  @override
  String get appearanceAndInteraction => '外观与交互';

  @override
  String get theme => '主题';

  @override
  String get followTheSystemOrChooseALightOrDarkAppearance =>
      '跟随系统，或固定浅色、深色外观。';

  @override
  String get system => '系统';

  @override
  String get light => '浅色';

  @override
  String get dark => '深色';

  @override
  String get displayLanguage => '显示语言';

  @override
  String get appliesImmediatelyWithoutRestarting => '应用界面立即切换，无需重启。';

  @override
  String get expandedSidebar => '展开侧边栏';

  @override
  String get showDestinationLabelsAlongsideIcons => '同时显示功能名称与图标。';

  @override
  String get keepRunningInTheTray => '关闭窗口后留在托盘';

  @override
  String get keepBackgroundTasksRunningQuitFromTheTrayMenu =>
      '后台任务继续运行；从托盘菜单退出。';

  @override
  String get closeSteamToContinue => '需要关闭 Steam';

  @override
  String get closeSteamToContinueDescription =>
      '此更改会写入 Steam 文件。继续前需要关闭 Steam 及其游戏进程。';

  @override
  String get closeAndContinue => '关闭并继续';

  @override
  String get steamClient => 'Steam 客户端';

  @override
  String get steamClientRunning => '运行中';

  @override
  String get steamClientNotRunning => '未运行';

  @override
  String get steamClientChecking => '检测中…';

  @override
  String get steamUpdateControl => 'Steam 更新控制';

  @override
  String get steamUpdateControlDescription => '管理 Steam 客户端的更新行为，全局生效。';

  @override
  String get disableSteamUpdateCheck => '禁用 Steam 检查更新';

  @override
  String get disableSteamForcedUpdate => '禁用 Steam 强制更新';

  @override
  String get notEnabled => '未启用';

  @override
  String get startSteam => '启动 Steam';

  @override
  String get stopSteam => '关闭 Steam';

  @override
  String get restartSteam => '重启 Steam';

  @override
  String get automaticRefreshUpdateChecksFriendPresenceStartupAndOfflineMode =>
      '自动刷新、更新检查、开机启动与离线模式。';

  @override
  String get downloadsKernelAndAccount => '下载、内核与账号';

  @override
  String
  get manageSubscriptionsScriptsAndTheirLuaManifestIdAndManifestFileCapabilities =>
      '管理订阅、JS 脚本及其提供的 Lua、清单 ID 和清单文件。';

  @override
  String get kernelManager => '内核管理';

  @override
  String get downloadImportOrSwitchKernelsAndRestoreBackups =>
      '下载、导入、切换内核，或恢复已有备份。';

  @override
  String get steamAccountAndExtraction => 'Steam 账号与提取';

  @override
  String get signInVerifySteamGuardAndExtractLicensedContent =>
      '登录、Steam Guard 验证与已授权内容提取。';

  @override
  String get chooseCoverAndGithubDownloadSourcesAndTestTheirLatency =>
      '选择封面与 GitHub 下载来源，并测试实际延迟。';

  @override
  String get applicationUpdates => '应用更新';

  @override
  String get flsteamluaReleaseRepository => 'FlSteamLua 发布仓库';

  @override
  String get useTheReleaseRepositoryForThisFlutterApplication =>
      '仅填写此 Flutter 应用的发布仓库。';

  @override
  String get saveRepository => '保存仓库';

  @override
  String get checkForUpdates => '检查更新';

  @override
  String viewNewVersion(String value1) {
    return '查看新版本 $value1';
  }

  @override
  String get aboutFlsteamlua => '关于 FlSteamLua';

  @override
  String get anOpenSourceDesktopCompanionForYourLibraryAchievementsAndSaves =>
      '专注游戏库、成就与存档的开源桌面工具。';

  @override
  String
  get uiComponentsAndMotionAreAdaptedFromFlclashFeaturesAreBasedOnFluentSteamLuaAndReimplem =>
      '界面组件与动效改编自 FlClash；功能基于 Fluent-Steam-Lua，以 Flutter 和 Dart 重新实现。';

  @override
  String get openSourceLicenses => '开源许可';

  @override
  String get browseFolders => '浏览文件夹';

  @override
  String get stopGame2 => '停止游戏';

  @override
  String get updateSubscriptionCaches => '更新订阅缓存';

  @override
  String get refreshLibrary => '刷新游戏库';

  @override
  String enabled3(String enabledLua) {
    return '$enabledLua 个已启用';
  }

  @override
  String get manageLua => '管理 Lua';

  @override
  String get steamLibrary => 'Steam 游戏库';

  @override
  String running2(String runningCount) {
    return '$runningCount 个运行中';
  }

  @override
  String get steamIsNotConnected => '尚未连接 Steam';

  @override
  String get openLibrary => '打开游戏库';

  @override
  String get kernel => '内核';

  @override
  String get couldNotReadKernel => '读取失败';

  @override
  String get detectingKernel => '正在检测';

  @override
  String get notInstalled => '未安装';

  @override
  String get manageKernel => '内核管理';

  @override
  String enabled4(String enabledSources) {
    return '$enabledSources 个已启用';
  }

  @override
  String get someSourcesNeedConfigurationOrTesting => '有来源需要配置或检查';

  @override
  String get manageSources => '管理来源';

  @override
  String get updateCaches => '更新缓存';

  @override
  String get running3 => '正在处理';

  @override
  String get viewTasks => '查看任务';

  @override
  String get activeTasks => '进行中的任务';

  @override
  String get continuePlaying => '继续游戏';

  @override
  String get allGames => '全部游戏';

  @override
  String get cancelling2 => '正在取消';

  @override
  String get cancelTask => '取消任务';

  @override
  String get enterAValidAppid3 => '请输入有效 AppID。';

  @override
  String dlcAnalysis2(String appId) {
    return 'DLC 管理：$appId';
  }

  @override
  String get dlcDepotStructure => 'DLC 仓库结构';

  @override
  String get allDlcStructures => '全部结构';

  @override
  String get confirmDlcAdditions => '确认追加 DLC 配置';

  @override
  String
  get theExistingLuaWillBeBackedUpOnlyTheSelectedLinesBelowAreAppendedExistingScriptsKeysAn =>
      '将备份当前 Lua，并且仅追加以下选中内容。原有脚本、密钥和版本固定记录都会保留。此操作不代表 Steam 账号拥有这些 DLC。';

  @override
  String get backUpAndAppend => '备份并追加';

  @override
  String saveDlcSuggestions(String appId) {
    return '保存 DLC 建议：$appId';
  }

  @override
  String appendedLinesAnalyzeAgainToVerifyTheCurrentConfiguration(
    String count,
  ) {
    return '已追加 $count 行；重新分析可核对结果。';
  }

  @override
  String get queryFailedUnknown => '查询失败 / 未知';

  @override
  String get noIndependentDepot => '无独立仓库';

  @override
  String get singleDepot => '单仓库';

  @override
  String get multipleDepots => '多个子仓库';

  @override
  String get inTheMainGame => '主游戏内仓库';

  @override
  String
  get compareSteamDepotMetadataWithTheCurrentLuaAndTheContentSourceSelectedForThisAnalysisP =>
      '对照 Steam 仓库信息、当前 Lua 和本次选择的内容源。先预览，再决定追加哪些 DLC 配置。';

  @override
  String get contentSourceOptional => '内容源（可选）';

  @override
  String get doNotUseAContentSourceCache => '不使用内容源缓存';

  @override
  String get contentSourceSubscriptionOptional => '内容源订阅（可选）';

  @override
  String get doNotUseASubscriptionCache => '不使用订阅缓存';

  @override
  String get existingLuaFile => '现有 Lua 文件';

  @override
  String get leaveEmptyToSearchTheConfiguredLuaFolderOrSelectADisabledLuaFile =>
      '留空时查找已配置的 Lua 目录；也可以手动选择已停用的 Lua。';

  @override
  String get chooseLua => '选择 Lua';

  @override
  String get analyzeDlc => '刷新 DLC';

  @override
  String get previewDlcChanges => '预览 Lua 变更';

  @override
  String mainDepotsDlcReferencedByLua(String mainDepotCount, String value2) {
    return '主游戏仓库 $mainDepotCount · Lua 中涉及 $value2 个 DLC。';
  }

  @override
  String get allLayouts => '全部类型';

  @override
  String get steamReturnedNoDlcForThisGame => 'Steam 未返回该游戏的 DLC。';

  @override
  String get referenced => '已涉及';

  @override
  String get notConfigured => '未配置';

  @override
  String luaSuggestedLines(String value1, String suggestionsCount) {
    return 'Lua $value1 · 建议 $suggestionsCount 行';
  }

  @override
  String missingKeysSkipped(String join) {
    return '缺少密钥，已跳过：$join';
  }

  @override
  String get selectedAdditions => '选中内容预览';

  @override
  String get noLinesSelected => '没有选中可追加的行。';

  @override
  String get copySuggestions => '复制建议';

  @override
  String get previewAndAppendToLua => '预览并追加到 Lua';

  @override
  String get free => '免费';

  @override
  String get pinWindow => '窗口置顶';

  @override
  String get unpinWindow => '取消窗口置顶';

  @override
  String get minimizeWindow => '最小化';

  @override
  String get maximizeWindow => '最大化';

  @override
  String get restoreWindow => '还原';

  @override
  String get closeWindow => '关闭';

  @override
  String get layout => '布局';

  @override
  String get comfortable => '宽松';

  @override
  String get standard => '标准';

  @override
  String get compact => '紧凑';

  @override
  String get themeMode => '主题模式';

  @override
  String get themeColor => '主题色彩';

  @override
  String get pureBlackMode => '纯黑模式';

  @override
  String get pureBlack => '纯黑';

  @override
  String get colorStyle => '配色风格';

  @override
  String get vivid => '鲜明';

  @override
  String get tinted => '柔和着色';

  @override
  String get soft => '柔和';

  @override
  String get monochrome => '单色';

  @override
  String get navigationBarStyle => '侧栏样式';

  @override
  String get floating => '悬浮';

  @override
  String get docked => '固定';

  @override
  String get tabAnimation => '页面切换';

  @override
  String get slide => '滑动';

  @override
  String get fade => '淡入';

  @override
  String get liquidGlass => '液态玻璃';

  @override
  String get none => '无';

  @override
  String get ultra => '增强';

  @override
  String get sidebar => '侧栏';

  @override
  String get backgroundBlur => '背景模糊';

  @override
  String get sidebarBlurDesc => '悬浮侧栏会模糊窗口后方的内容。';

  @override
  String get fontFamily => '字体';

  @override
  String get defaultText => '默认';

  @override
  String get textScale => '文本缩放';

  @override
  String get followSystem => '跟随系统';

  @override
  String get custom => '自定义';

  @override
  String get textScalePreview => '应用内的文字将按此大小显示。';

  @override
  String get customColor => '自定义颜色';

  @override
  String get reset => '重置';

  @override
  String get resetTip => '恢复默认的 FlClash 风格外观？';

  @override
  String get backgroundStyle => '背景样式';

  @override
  String get grid => '网格';

  @override
  String get spectrum => '光谱';

  @override
  String get sliders => '滑块';

  @override
  String get hue => '色相';

  @override
  String get saturation => '饱和度';

  @override
  String get brightness => '亮度';

  @override
  String get hex => '十六进制';

  @override
  String get color => '颜色';

  @override
  String get edit => '编辑';

  @override
  String get installedFonts => '已安装字体';

  @override
  String get deleteColorTip => '删除这个自定义颜色？';

  @override
  String get general => '通用';

  @override
  String get other => '其他';

  @override
  String get add => '添加';

  @override
  String get auto => '自动';

  @override
  String get tip => '提示';

  @override
  String get basicInfo => '基本信息';

  @override
  String get cloudConnection => '连接';

  @override
  String get credentials => '凭据';

  @override
  String get advanced => '高级';

  @override
  String get url => '地址';

  @override
  String get endpoint => '端点';

  @override
  String get region => '区域';

  @override
  String get bucket => '存储桶';

  @override
  String get accountId => '账户 ID';

  @override
  String get accessKeyId => '访问密钥 ID';

  @override
  String get secretAccessKey => '秘密访问密钥';

  @override
  String get keyPrefix => '键前缀';

  @override
  String get extraHeaders => '额外请求头';

  @override
  String get timeoutSeconds => '超时（秒）';

  @override
  String get optional => '可选';

  @override
  String get showPassword => '显示密码';

  @override
  String get hidePassword => '隐藏密码';

  @override
  String sourceDefinitionNotFound(Object sourceId) {
    return '未找到源定义：$sourceId';
  }

  @override
  String get kernelOverview => '内核概览';

  @override
  String get kernelStateHealthy => '运行正常';

  @override
  String get kernelStateDisabled => '已停用';

  @override
  String get kernelStateMissingEntry => '缺少注入入口';

  @override
  String get kernelStateConflict => '注入入口冲突';

  @override
  String get kernelStateNotInstalled => '未安装';

  @override
  String get kernelVersion => '版本';

  @override
  String kernelUpdateAvailable(Object version) {
    return '发现新版本 $version';
  }

  @override
  String get kernelUpToDate => '已是最新版本';

  @override
  String get checkKernelUpdate => '检查内核更新';

  @override
  String get installOrUpdateKernel => '安装或更新内核';

  @override
  String get installAndRuntime => '安装与运行';

  @override
  String get repositorySubscription => 'GitHub 仓库订阅';

  @override
  String get localKernelPackage => '本地内核包';

  @override
  String get kernelRepository => '内核仓库';

  @override
  String get kernelRepositoryHint => 'owner/repository 或 GitHub 仓库地址';

  @override
  String get repositoryMainline => '主线仓库';

  @override
  String get repositoryFork => '分支仓库';

  @override
  String get defaultBranch => '默认分支';

  @override
  String get lastPush => '最后提交';

  @override
  String get kernelLocalNoUpdates => '本地内核包不检查更新';

  @override
  String get releaseAnnouncement => '更新公告';

  @override
  String get manifestSettings => '清单请求码配置';

  @override
  String get manifestProvider => '清单服务器';

  @override
  String get manifestModeBuiltIn => '内置服务器';

  @override
  String get manifestModeCustom => '自定义服务器（经本应用）';

  @override
  String get manifestModeLocalProxy => '本地代理';

  @override
  String get manifestUrlTemplate => '清单服务器地址';

  @override
  String get manifestHeader => '请求头';

  @override
  String get manifestFormat => '数据格式';

  @override
  String get manifestFailover => '服务器失败时自动回退';

  @override
  String get manifestRequestCodes => '清单请求码';

  @override
  String get noManifestCodeSources => '没有可提供清单请求码的已启用内容源';

  @override
  String get selectAtLeastOneManifestCodeSource => '请至少选择一个清单请求码来源';

  @override
  String get manifestLocalProxyDescription =>
      '从所选脚本源获取当前 DepotID/GID 的请求码，需保持本应用运行。脚本失败时核心仍可尝试内置源。';

  @override
  String get manifestCustomHint =>
      '地址须含 gid 或 manifestId 占位符，可使用 appId、depotId。需保持本应用运行；失败时核心可尝试内置源。';

  @override
  String get steamClientDataChannel => 'Steam 客户端版本数据渠道';

  @override
  String get channelRepository => '数据仓库';

  @override
  String get channelName => 'Git 分支';

  @override
  String get channelFormat => '仓库格式';

  @override
  String get channelFormatBranch => 'pattern / ipc 独立分支';

  @override
  String get channelFormatDirectory => '同一分支下的 pattern / ipc 目录';

  @override
  String get defaultRepository => '默认';

  @override
  String get customRepository => '自定义仓库';

  @override
  String get localTemporaryBuild => '本地临时构建';

  @override
  String get localTemporaryBuildDescription =>
      '使用内置特征扫描当前 Steam 文件，匹配完整时生成临时配置。无法保证适配未知的新版本。';

  @override
  String get localBuildTitle => '本地临时构建';

  @override
  String get localBuildIdleDescription =>
      '读取本机 Steam DLL，为当前 Steam 版本生成临时签名文件。';

  @override
  String get localBuildSteamDlls => 'Steam DLL';

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
    return '正在解析 $component 签名';
  }

  @override
  String localBuildHookResolved(String name, String rva, String bytes) {
    return '$name → $rva · $bytes 字节签名';
  }

  @override
  String localBuildHookMissing(String name) {
    return '$name · 没有唯一匹配';
  }

  @override
  String localBuildComponentWritten(
    String component,
    String resolved,
    String total,
  ) {
    return '$component · 已写入 $resolved/$total';
  }

  @override
  String localBuildComponentRejected(
    String component,
    String resolved,
    String total,
  ) {
    return '$component · $resolved/$total，未覆盖原文件';
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
    return '已写入 $written/$total 个文件';
  }

  @override
  String get localBuildStart => '开始构建';

  @override
  String get localBuildRestart => '重新构建';

  @override
  String get localBuildLog => '构建日志';

  @override
  String get localBuildCloseSteam => '开始本地构建前请先退出 Steam。';

  @override
  String get kernelEntryDwmapiDescription => '兼容性优先，推荐日常使用';

  @override
  String get kernelEntryVersionDescription => '适用于需要首载隔离的场景';

  @override
  String get kernelActions => '内核操作';

  @override
  String get kernelResidualScan => '扫描内核残留';

  @override
  String get kernelResidualScanDescription => '只读扫描已知内核文件和目录，确认后才会备份清理';

  @override
  String get kernelUpdateCheckOnStartup => '启动时检查内核更新';

  @override
  String get kernelUpdateCheckOnStartupDescription => '安装的内核出现新版官方发布时进行提示';

  @override
  String get kernelLatest => '最新';

  @override
  String get kernelScanTitle => '内核残留';

  @override
  String kernelScanSummary(Object cleanable, Object count, Object size) {
    return '发现 $count 项，可清理 $cleanable 项，共 $size';
  }

  @override
  String get kernelResidualOpenSteamTool => 'OpenSteamTool';

  @override
  String get kernelResidualOpenSteamToolDescription =>
      'OpenSteamTool 内核本体、配置或缓存数据';

  @override
  String get kernelResidualSteamTools => 'SteamTools';

  @override
  String get kernelResidualSteamToolsDescription => 'SteamTools 注入 DLL 或插件数据';

  @override
  String get kernelResidualTbBiao => 'TB / BIAO';

  @override
  String get kernelResidualTbBiaoDescription => 'TB / BIAO 或 GreenLuma 注入文件';

  @override
  String get kernelResidualSteamConfig => 'Steam 配置';

  @override
  String get kernelResidualSteamConfigDescription =>
      '可能关闭自动更新或改变 Steam 启动行为的配置';

  @override
  String get kernelResidualInfo => '信息';

  @override
  String get kernelResidualWarning => '警告';

  @override
  String get kernelResidualHigh => '高风险';

  @override
  String get kernelResidualCanClean => '可清理';

  @override
  String get kernelResidualReportOnly => '仅报告';

  @override
  String get kernelResidualDirectory => '目录';

  @override
  String get kernelResidualFile => '文件';

  @override
  String get kernelResidualBackupAndClean => '备份并清理';

  @override
  String get kernelResidualRescan => '重新扫描';

  @override
  String get kernelResidualNoResults => '未发现已知内核残留';

  @override
  String get kernelResidualSelectCleanable => '选择可清理项';

  @override
  String kernelResidualCleanupCompleted(Object count) {
    return '已备份并清理 $count 项残留';
  }

  @override
  String kernelResidualCleanupPartial(Object deleted, Object failed) {
    return '已清理 $deleted 项，失败 $failed 项';
  }

  @override
  String get kernelTomlPreviewTitle => '获取 Steam 签名';

  @override
  String get kernelBuildId => '构建 ID';

  @override
  String get kernelClientSha => 'steamclient64 SHA256';

  @override
  String get kernelUiSha => 'steamui SHA256';

  @override
  String get kernelTomlFiles => '将获取以下签名';

  @override
  String get kernelStartFetch => '开始获取';

  @override
  String get kernelTomlResults => '签名获取结果';

  @override
  String get kernelTomlReady => '已获取';

  @override
  String get kernelTomlNoUpstream => '上游暂无';

  @override
  String get kernelTomlFailed => '获取失败';

  @override
  String get kernelNoUpdate => '没有可用更新';

  @override
  String get injectionEntry => '注入入口';

  @override
  String get selectAnOutputFolder => '请选择输出文件夹。';

  @override
  String get chooseFilesToConvert => '请至少选择一个要转换的文件。';

  @override
  String get noSupportedFilesFound => '没有找到受支持的 Lua、VDF 或 ACF 文件。';

  @override
  String convertedFileCount(String count) {
    return '已转换 $count 个文件。';
  }

  @override
  String get conversionOptions => '转换参数';

  @override
  String fileCount(String count) {
    return '已选择 $count 个文件';
  }

  @override
  String get noFilesSelected => '尚未选择文件';

  @override
  String get chooseLuaVdfOrAcfFiles => '选择 Lua、VDF 或 ACF 文件；已存在的输出文件不会被覆盖。';

  @override
  String get chooseFiles => '选择文件';

  @override
  String get notSelected => '尚未选择';

  @override
  String get monitorRunning => '正在监控 Steam 内容请求';

  @override
  String get monitorStopped => '清单监控已停止';

  @override
  String get activityLog => '活动日志';

  @override
  String depotEntryCount(String count) {
    return '$count 个仓库条目';
  }

  @override
  String get pinInstalledDescription => '使用当前 Steam 清单中已经记录的 Manifest ID。';

  @override
  String get latestPublicDescription => '从 SteamCMD 元数据读取最新的公共 Manifest ID。';

  @override
  String get unpinDescription => '注释 Manifest 固定记录，同时保留内容以便之后恢复。';

  @override
  String get depotEntries => '仓库条目';

  @override
  String get pinned => '已固定';

  @override
  String get notPinned => '未固定';

  @override
  String get noDepotEntries => '当前 Lua 文件中没有仓库条目。';

  @override
  String get manifestPinFooter => '修改前会先备份，再写入游戏的 Lua 文件。';

  @override
  String get enterValidDlcAppIds => '请输入一个或多个有效的 DLC AppID。';

  @override
  String addedDlcCount(String count) {
    return '已添加 $count 个 DLC 条目。';
  }

  @override
  String get removeDlc => '移除 DLC 条目';

  @override
  String removedDlcEntry(String appId) {
    return '已移除 AppID $appId。';
  }

  @override
  String get luaEntries => 'Lua 条目';

  @override
  String diagnosticsSummary(String passed, String total) {
    return '$passed/$total 项检查通过';
  }

  @override
  String get missing => '缺失';

  @override
  String get noDiagnosticsFound => '没有可用的诊断项。';

  @override
  String get diagnosticsFooter => '诊断只读取已配置路径，不会修改 Steam 文件。';

  @override
  String get applicationFolders => '应用目录';

  @override
  String get applicationFoldersFooter => '日志与备份都保存在应用数据目录中；打开目录不会修改其中内容。';

  @override
  String get openLogsAndBackups => '打开日志与备份目录';

  @override
  String get dlcAnalysisDescription =>
      '管理 DLC 条目，对照 Steam 仓库元数据与 Lua 配置并预览追加内容。';

  @override
  String get managePatchesAndLicenses => '应用补丁并管理许可配置。';

  @override
  String get kernelDownloadsAndNetwork => '内核、下载与网络';

  @override
  String get conversionResults => '转换结果';

  @override
  String get noMatchingManifestsFound => '没有找到匹配的 Manifest。';

  @override
  String get versionLabel => '版本';

  @override
  String get platformLabel => '平台';

  @override
  String get updatedLabel => '更新日期';

  @override
  String get fileSizeLabel => '大小';

  @override
  String get sourceLabel => '来源';

  @override
  String get destinationLabel => '目标位置';

  @override
  String get actionsLabel => '操作';

  @override
  String get selectAGameToShowGameTools => '选择游戏后显示对应的专用工具。';

  @override
  String get lanTransfer => '局域网传输';

  @override
  String get lanTransferDescription =>
      '把已安装的游戏、Lua 和相关清单直接发送到同一局域网内的另一台 FlSteamLua 电脑。';

  @override
  String get allowLanTransfers => '允许向此设备传输';

  @override
  String get allowLanTransfersDescription => 'FlSteamLua 打开或驻留托盘时保持加密接收服务运行。';

  @override
  String lanTransferTask(String game) {
    return '传输 $game';
  }

  @override
  String get lanNearbyDevices => '附近设备';

  @override
  String get lanNearbyDevicesDescription =>
      '同一专用网络内的设备会自动出现。未知设备仍需在接收端确认后才能写入文件。';

  @override
  String get lanNoDevices => '没有发现接收设备';

  @override
  String get lanNoDevicesDescription => '在另一台电脑开启接收，或手动添加它的 IP 地址。';

  @override
  String get lanAddDevice => '添加设备';

  @override
  String get lanDeviceAddress => '设备地址';

  @override
  String get lanDeviceAddressHint => '192.168.1.20';

  @override
  String get lanConnectDevice => '连接';

  @override
  String get lanManualDevice => '手动地址';

  @override
  String get lanTrusted => '已信任';

  @override
  String get lanUntrusted => '需要确认';

  @override
  String get lanSendGame => '发送游戏';

  @override
  String get lanChooseDevice => '接收设备';

  @override
  String get lanSendToLan => '局域网发送';

  @override
  String get lanReceiveTransfer => '接收传输';

  @override
  String lanIncomingTransferTitle(String game) {
    return '接收 $game';
  }

  @override
  String lanTransferFromDevice(String device) {
    return '来自 $device';
  }

  @override
  String get lanAccept => '接受';

  @override
  String get lanReject => '拒绝';

  @override
  String get lanRememberDevice => '信任此设备并自动接收';

  @override
  String get lanAcceptAndRemember => '接受并信任';

  @override
  String get lanContentToTransfer => '传输内容';

  @override
  String get lanOfficialFiles => '官方游戏文件';

  @override
  String get lanModifiedFiles => '已修改的游戏文件';

  @override
  String get lanExtraFiles => '附加文件与 Mod';

  @override
  String get lanLuaAndManifests => 'Lua 与清单';

  @override
  String get lanDepotManifests => '仓库清单';

  @override
  String get lanExtrasWarning => '附加文件可能包含 Mod、补丁或游戏目录内的存档，只选择接收方真正需要的文件。';

  @override
  String get lanNoManifestWarning => '没有找到本地仓库清单，无法自动识别官方文件，所有游戏文件都需要手动选择。';

  @override
  String get lanNetworkSpeed => '网络';

  @override
  String get lanDiskWriteSpeed => '磁盘写入';

  @override
  String get lanDownloadProgress => '正在下载数据';

  @override
  String get lanUploadProgress => '正在发送数据';

  @override
  String get lanInstallProgress => '正在安装文件';

  @override
  String lanNetworkTransferred(String bytes) {
    return '实际网络传输：$bytes';
  }

  @override
  String get lanPeakSpeed => '峰值';

  @override
  String get lanProgress => '正在传输游戏数据';

  @override
  String get lanRemainingTime => '预计剩余时间';

  @override
  String get lanPause => '暂停传输';

  @override
  String get lanPaused => '已暂停';

  @override
  String get lanResume => '恢复传输';

  @override
  String get lanRetryTransfer => '重试传输';

  @override
  String get lanCancelTransfer => '取消传输';

  @override
  String get lanWaitingApproval => '等待接收方确认';

  @override
  String get lanWaitingSteam => '下载已完成，请关闭接收端 Steam 后完成入库。';

  @override
  String get lanCompleted => '已完成';

  @override
  String get lanFailed => '失败';

  @override
  String get lanActiveTransfer => '当前传输';

  @override
  String get lanRecentTransfers => '最近传输';

  @override
  String get lanHistoryEmpty => '完成的传输会显示在这里。';

  @override
  String get lanDestinationLibrary => '目标 Steam 库';

  @override
  String get lanSteamRestartNotice => 'FlSteamLua 会立即识别游戏；Steam 需要重启后刷新已安装列表。';

  @override
  String get lanForgetDevice => '忘记设备';

  @override
  String get lanDeviceFingerprint => '设备指纹';

  @override
  String get lanReceiveDisabled => '接收已关闭';

  @override
  String get lanReceiveEnabled => '正在等待接收';

  @override
  String get lanTransferSettings => '此电脑';

  @override
  String get lanNoLibrary => '没有找到可写的 Steam 库。';

  @override
  String get lanDiskUsage => '磁盘活动';

  @override
  String get lanGameFiles => '游戏文件';

  @override
  String get lanPreparing => '正在准备文件';

  @override
  String get lanVerifying => '正在校验文件';

  @override
  String get lanCommitting => '正在安装游戏';

  @override
  String get lanCancelled => '已取消';

  @override
  String get lanSelectDestinationDescription => '选择一个已注册且空间充足的 Steam 库。';

  @override
  String get lanNoSelectedFiles => '没有选择文件';

  @override
  String get lanRefreshDevices => '刷新设备';

  @override
  String get lanChunkProgress => '块进度';

  @override
  String get lanCachedChunks => '缓存命中块';

  @override
  String get lanChunkCache => '传输暂存';

  @override
  String get lanChunkCacheDescription => '保留未完成的游戏传输数据，供断点续传使用。';

  @override
  String get lanClearChunkCache => '清理传输暂存';

  @override
  String get lanClearChunkCacheConfirmation => '清理未完成的传输数据？清理后恢复这些任务需要重新传输。';

  @override
  String get lanChunkCacheCleared => '传输暂存已清理。';

  @override
  String get lanManualAddressInvalid => '请输入有效的 IPv4 地址或主机名。';

  @override
  String get more => '更多';

  @override
  String get screenshots => '游戏截图';

  @override
  String get previewImage => '预览图片';

  @override
  String get previousImage => '上一张';

  @override
  String get nextImage => '下一张';

  @override
  String get selectAll => '全选';

  @override
  String get contentPreview => '内容预览';

  @override
  String get updateChangelog => '更新日志';

  @override
  String get versionPinned => '版本已固定';

  @override
  String get clearDownloadedManifests => '清除 Steam 清单缓存';

  @override
  String clearDownloadedManifestsDescription(String game) {
    return '清除“$game”在各个 Steam 库 depotcache 中的全部相关清单文件？Lua 配置不会被修改。';
  }

  @override
  String downloadedManifestsCleared(String count) {
    return '已清除 $count 个 Steam 清单文件。';
  }

  @override
  String get noDownloadedManifests => 'Steam depotcache 中没有找到此游戏的清单文件。';

  @override
  String get luaDirectories => 'Lua 目录';

  @override
  String get addLuaDirectory => '添加 Lua 目录';

  @override
  String get luaDirectoryAlreadyAdded => '此目录已在列表中。';

  @override
  String get defaultLuaWriteDirectory => '默认写入';

  @override
  String get luaDirectoriesSaved => 'Lua 目录已保存到内核配置，游戏库已刷新。';

  @override
  String get coreLuaDirectory => '固定目录';

  @override
  String get remove => '移除';

  @override
  String get configurationEnabled => '配置已启用';

  @override
  String get cloudPluginCache => '插件本地缓存';

  @override
  String get cloudFolderRepository => '文件夹仓库';

  @override
  String get cloudConfigurationSavedRestart => '配置已保存；请重启 Steam 后使用。';

  @override
  String get cloudConfigurationRestartDescription =>
      '此设置在 Steam 启动时加载。配置已启用不代表插件已加载或同步完成。';

  @override
  String get cloudMetadataSync => '成就与时长同步';

  @override
  String get cloudSyncAchievements => '同步成就与统计';

  @override
  String get cloudSyncPlaytime => '同步游玩时长';

  @override
  String get cloudRepositoryDescription =>
      '这里管理 CloudRedirect 仓库与缓存。导出保留哈希对象及元数据；游戏存档恢复由 Steam 内的插件同步完成。';

  @override
  String get manifestConfigurationSaved =>
      '清单请求码配置已保存。重启 Steam 应用脚本切换；自定义与本地代理模式需保持本应用运行。';

  @override
  String get kernelChannelDescription =>
      '保存同时更新核心自动获取渠道与手动下载来源。已有缓存继续使用，新版本指纹在下次 Steam 启动时使用该渠道。';

  @override
  String get onlineFixRealAppIdDescription =>
      '支线内核可在黑屏或加载异常时尝试保留真实 AppID；需要 Spacewar AppID 的游戏继续使用上方参数。';

  @override
  String get luaPresenceDescription =>
      '控制 Lua 游戏的好友广播，不改变 Steam 全局隐私。需要支持 presence 配置的支线内核；停更主线不支持此项。';

  @override
  String get customLuaDirectories => '自定义目录';

  @override
  String get noCustomLuaDirectories => '暂无自定义目录';

  @override
  String get luaDirectoriesSort => '目录排序';

  @override
  String get currentSteamLoginAccount => '当前 Steam 登录账号';

  @override
  String get ticketOwnerAccount => '票据所属账号';

  @override
  String get cachedAuthorizationIdentity => '此游戏缓存的授权身份';

  @override
  String get ticketIdentityNotSet => '未设置';

  @override
  String get ticketAccountUnavailable => '未登录或暂无法读取';

  @override
  String get applyTicketPreserveIdentity => '应用票据，保留现有身份';

  @override
  String syncAuthorizationIdentity(String steamId) {
    return '同时将授权身份设为 $steamId';
  }

  @override
  String get ticketIdentitySaveWarning => '修改授权身份可能影响按 SteamID 分目录的游戏存档。';

  @override
  String get ticketCachedIdentityWarning =>
      '缓存授权身份与票据所属账号不一致。保留现有身份可能影响授权；是否完成授权需要实际启动游戏验证。';

  @override
  String get ticketIdentityWarningLabel => '身份差异';

  @override
  String get ticketApplyBackupDescription =>
      '应用前加密备份旧 AppTicket、ETicket 和 SteamID。默认只替换两张票据。';

  @override
  String get ticketWrittenVerified => '票据已写入并校验';

  @override
  String get restorePreApplyCredentials => '恢复应用前凭据';

  @override
  String get ticketRestoreCompleteSet =>
      '恢复此备份中的两张票据和 SteamID；原本不存在的值会删除。关联 Lua 也会恢复，当前凭据另存为加密备份。';

  @override
  String get ticketCredentialsRestored => '应用前凭据已整组恢复并校验';

  @override
  String get ticketLuaCleanup => 'Lua 中待移除的票据语句';

  @override
  String ticketLuaRemovalCount(String count) {
    return '发现 $count 条旧票据语句';
  }

  @override
  String get ticketLuaCleanupDescription => '本次确认将先备份 Lua，再移除以上语句，避免核心热加载旧票据。';

  @override
  String get ticketStopSteamForLua => '为避免 Lua 热加载覆盖凭据，确认后将先退出 Steam；完成后可手动重启。';

  @override
  String get ticketPreviewChanged => '凭据已在预览后改变，请重新确认。';

  @override
  String get ticketLuaChanged => 'Lua 已在预览或备份后改变，未覆盖当前文件。请重新检查。';

  @override
  String get ticketInvalidBackup => '凭据备份格式无效。';

  @override
  String get ticketWriteNotVerified => '凭据读回校验失败，已尝试恢复原值。';

  @override
  String get ticketRollbackIncomplete => '操作失败且未能完整回滚，请使用加密备份恢复整组凭据与 Lua。';

  @override
  String get ticketOperationBusy => '另一项凭据操作尚未完成。';

  @override
  String get ticketLuaManualCleanup =>
      'Lua 中票据调用不是可直接移除的独立语句，请先在 Lua 编辑器处理后再应用。';

  @override
  String get copyAchievementsHint => '只复制本地缓存文件，不会迁移已解锁的成就。';

  @override
  String lanAutomaticReceiveHint(String path) {
    return '以后自动接收到：$path。可在设备菜单中忘记此设备。';
  }

  @override
  String get noInstalledGamesToTransfer => '没有可传输的已安装游戏';

  @override
  String get installGameBeforeTransfer => '先安装游戏，再刷新游戏库。';

  @override
  String get noAdditionalFiles => '没有附加文件';

  @override
  String sourceNeedsConfiguration(String name) {
    return '$name · 未配置';
  }

  @override
  String get configureManifestSource => '配置所选清单来源';

  @override
  String sourceTestPassed(String name) {
    return '$name 测试通过。';
  }

  @override
  String get fileWillBeBackedUpAndReplaced => '将备份并替换';

  @override
  String get fileExistsChooseReplace => '文件已存在，请确认是否备份并替换';

  @override
  String luaImportReady(String game) {
    return '已将“$game”的配置写入 Lua 库，可前往 Steam 安装。';
  }

  @override
  String get httpsUrlRequired => '请输入有效的 HTTPS 地址。';

  @override
  String get subscriptionAutoUpdateScope => '对所有订阅生效；开启后按各自间隔更新。';

  @override
  String get subscriptionIntervalDescription => '间隔为 0 时仅手动更新。自动更新需要开启上方开关。';

  @override
  String get sourceOutputType => '获取内容';

  @override
  String get sourceArchiveOutput => '清单压缩包';

  @override
  String get sourceCredentialHint => '前往来源网站登录，在账号设置中获取此凭据。';

  @override
  String get sourceOutputHint => 'Lua 获取配置文本；清单压缩包获取来源提供的文件包。';

  @override
  String get sourceProviderHint => '选择该服务使用的清单来源。';

  @override
  String get sourceGameNameHint => '仅用于来源服务记录，可以留空。';

  @override
  String get sourceDepotManifestHint =>
      'Depot ID 与 Manifest ID 配套填写；留空时尝试按游戏获取。';

  @override
  String get openSourceWebsite => '打开来源网站';

  @override
  String get luaDirectoryRemoved => '已移除目录配置，目录内的文件保留。';

  @override
  String get undo => '撤销';

  @override
  String get bearerToken => '访问令牌';

  @override
  String fillRequiredFields(String fields) {
    return '请填写：$fields。';
  }

  @override
  String get cloudAddressInvalid => '请输入完整的 HTTPS 地址；使用 HTTP 时需开启“允许 HTTP”。';

  @override
  String get cloudTimeoutInvalid => '超时应为 0–300 秒。';

  @override
  String get connectionFailedRetry => '连接未完成，请检查网络后重试。';

  @override
  String get fileOperationFailedHint => '文件操作未完成，请检查目录权限、磁盘空间及文件占用。';

  @override
  String get remoteCredentialsRejected => '远端拒绝访问，请检查账号凭据和目录权限。';

  @override
  String get remoteLocationMissing => '远端位置不存在，请检查配置的地址或目录。';

  @override
  String get remoteOperationFailedHint => '远端操作未完成，请检查连接或查看详情。';

  @override
  String get invalidInputHint => '内容格式不正确，请检查填写项或导入文件。';

  @override
  String get operationFailedDetails => '操作未完成，可查看详情了解原因。';

  @override
  String get steamLocalSave => 'Steam 本地存档';

  @override
  String selectBackupProvider(String provider) {
    return '此备份包含 $provider 的远端数据，请先切换到该存储类型。';
  }

  @override
  String get steamUpdateChecks => 'Steam 更新检查';

  @override
  String get steamForcedUpdates => 'Steam 强制更新';

  @override
  String get blockedSetting => '已阻止';

  @override
  String get allowedSetting => '已允许';

  @override
  String get confirmApplyTickets => '确认应用票据';

  @override
  String get reviewExtractedTickets => '查看并应用此票据';

  @override
  String get extractTrainerBeforeBinding => '压缩包需先解压，再选择修改器程序绑定游戏。';

  @override
  String get testAndUpdateSubscription => '测试并更新订阅';

  @override
  String get cloudOperationBusy => '请等待当前存档操作完成。';

  @override
  String get cloudInvalidBackup => '备份记录无效。';

  @override
  String get cloudBackupChecksumFailed => '备份校验失败，未写入存档。';

  @override
  String get cloudPinnedBackup => '请先取消固定再删除备份。';

  @override
  String get cloudInvalidRetention => '保留数量和容量必须为非负整数。';

  @override
  String get cloudBackupTargetUnknown => '此备份缺少存储身份，不能恢复到远程仓库。';

  @override
  String get cloudBackupTargetChanged => '存储位置或账号已变化，请重新选择并检查目标。';

  @override
  String get cloudSyncActiveOnly => '先将此存储设为同步目标，才能拉取到插件缓存。';

  @override
  String get cloudSteamMustStop => '请关闭 Steam 和游戏后继续。';

  @override
  String get cloudInstallPluginFirst => '请先安装 CloudRedirect 插件。';

  @override
  String get cloudSyncMetadataMissing => '仓库缺少有效的同步元数据。';

  @override
  String get cloudSyncNotVerified => '核心未确认同步完成。已保留操作前备份，请检查任务记录。';

  @override
  String get cloudCurrentStorage => '当前核心配置';

  @override
  String get cloudFolderAbsolute => '请选择绝对路径的存档目录。';

  @override
  String get cloudCredentialsRequired => '请填写所选认证方式需要的凭据。';

  @override
  String get cloudUnknownStorage => '存储类型无效。';

  @override
  String get cloudAuthorizeFirst => '请先在此表单中登录授权。';

  @override
  String get cloudAccountLookupFailed => '无法读取授权账号身份。';

  @override
  String get cloudWriteProbeFailed => '测试文件回读校验失败。';

  @override
  String get cloudStorageNameRequired => '请输入存储名称。';

  @override
  String get cloudActiveStorageDelete => '当前同步目标不能删除，请先切换目标。';

  @override
  String get cloudDisableBeforeDisconnect => '请先停用重定向，再断开当前目标。';

  @override
  String get cloudStorages => '存储管理';

  @override
  String get cloudAddStorage => '添加存储';

  @override
  String get cloudStorageName => '存储名称';

  @override
  String get cloudActivate => '设为同步目标';

  @override
  String get cloudActiveTarget => '同步目标';

  @override
  String get cloudBrowse => '浏览存档';

  @override
  String get cloudBrowsing => '正在浏览';

  @override
  String get cloudDuplicate => '复制配置';

  @override
  String get cloudSortStorages => '存储排序';

  @override
  String get cloudStorageSaved => '存储已保存';

  @override
  String get cloudStorageRemoved => '移除本地配置及凭据，远程文件保留。';

  @override
  String get cloudStorageActivated => '同步目标已更新；下次 Steam 启动时生效。';

  @override
  String get cloudTestRead => '测试读取';

  @override
  String get cloudTestWrite => '测试写入与清理';

  @override
  String get cloudTestWriteHint => '会创建临时测试文件，回读校验后删除。';

  @override
  String get cloudReadVerified => '读取已验证';

  @override
  String get cloudWriteVerified => '读写已验证';

  @override
  String get cloudNotTested => '尚未测试';

  @override
  String get cloudDiscardDraft => '放弃未保存的更改？';

  @override
  String get cloudPendingRestart => '待 Steam 重启';

  @override
  String get cloudCoreReady => '核心文件就绪';

  @override
  String get cloudCoreMissing => '核心或加载入口未就绪';

  @override
  String get cloudNotRuntimeVerified => '尚未验证运行状态';

  @override
  String get cloudLastChecked => '最近检查';

  @override
  String get cloudAllAccounts => '全部账号';

  @override
  String get cloudAccountFilter => '账号筛选';

  @override
  String get cloudLocationFilter => '位置筛选';

  @override
  String get cloudAllLocations => '全部位置';

  @override
  String get cloudDetails => '存档详情';

  @override
  String get cloudLoadFiles => '查看文件清单';

  @override
  String get cloudPull => '拉取到插件缓存';

  @override
  String get cloudPullHint => '由 CloudRedirect 拉取所选游戏；先备份现有缓存。完成后仍需启动游戏验证读取。';

  @override
  String get cloudSyncVerified => '核心同步已完成，缓存元数据已校验';

  @override
  String get cloudCompare => '比较仓库清单';

  @override
  String get cloudLocalOnly => '仅本地';

  @override
  String get cloudRemoteOnly => '仅远程';

  @override
  String get cloudChangedFiles => '内容或元数据不同';

  @override
  String get cloudManifestEqual => '仓库清单一致';

  @override
  String get cloudCompareHint => '按文件清单比较；不以修改时间推断同步完成。';

  @override
  String get cloudExportRepository => '导出仓库副本';

  @override
  String get cloudExportHint => '导出哈希对象与元数据，目标目录必须为空。';

  @override
  String get cloudPreOperationBackup => '操作前自动备份';

  @override
  String get cloudConfirmOperation => '确认存档操作';

  @override
  String get cloudStopAndContinue => '关闭 Steam 并继续';

  @override
  String get cloudBackupDetails => '备份详情';

  @override
  String get cloudBackupNote => '备注';

  @override
  String get cloudBackupPinned => '固定保留';

  @override
  String get cloudVerifyBackup => '校验备份';

  @override
  String get cloudBackupVerified => '备份校验通过';

  @override
  String get cloudRetention => '清理备份';

  @override
  String get cloudRetentionCount => '每游戏保留份数';

  @override
  String get cloudRetentionSize => '每游戏容量上限（MiB）';

  @override
  String get cloudRetentionHint => '0 表示不限；固定备份不参与清理。确认清单后才删除。';

  @override
  String get cloudNothingToClean => '没有待清理的备份';

  @override
  String get cloudBackupManual => '手动备份';

  @override
  String get cloudBackupBeforeDelete => '删除前';

  @override
  String get cloudBackupBeforeRestore => '恢复前';

  @override
  String get cloudBackupBeforeUpload => '上传前';

  @override
  String get cloudBackupBeforeSync => '拉取前';

  @override
  String get cloudDestination => '目标位置';

  @override
  String get cloudRepositoryCopy => '复制到同步目标';

  @override
  String get cloudGameAccount => '游戏 / 账号';

  @override
  String get cloudTargetChangedDuringOperation => '操作期间目标发生变化，已停止。';

  @override
  String get cloudExportNotEmpty => '请选择空目录；现有文件未被覆盖。';

  @override
  String get cloudNoRestoreTargets => '备份没有可恢复的位置。';

  @override
  String get cloudRestartForSettings => '设置已保存，运行状态需在 Steam 重启后确认。';

  @override
  String get cloudLoadFailedRetained => '刷新失败，保留上次列表';

  @override
  String get cloudDisconnectConfirm => '移除此存储的本地授权凭据；远程文件保留。';

  @override
  String get cloudNoFiles => '没有文件';

  @override
  String get steamVersionTitle => 'Steam 版本管理';

  @override
  String get steamVersionDescription => '浏览历史版本、校验下载、安装与回退 Steam 客户端';

  @override
  String get steamVersionBusy => '请等待当前版本操作完成。';

  @override
  String get steamVersionInvalidCatalog => '版本清单无效或不完整。';

  @override
  String get steamVersionManifestMismatch => '清单的架构或版本与请求不符。';

  @override
  String get steamVersionInvalidFilter => '日期使用 YYYYMMDD，起始日期不能晚于结束日期。';

  @override
  String steamVersionDownloading(String file) {
    return '正在下载并校验 $file';
  }

  @override
  String steamVersionDownloadProgress(
    String file,
    String received,
    String total,
  ) {
    return '$file · $received/$total 字节';
  }

  @override
  String get steamVersionRangeInvalid => '服务器返回的续传范围不匹配。';

  @override
  String get steamVersionChecksumFailed => '文件大小或 SHA-256 校验失败。';

  @override
  String steamVersionPackageInvalid(String file) {
    return '包缺失或校验失败：$file';
  }

  @override
  String get steamVersionSameImport => '该目录已在版本下载库中。';

  @override
  String get steamVersionStaging => '正在临时目录安装并核对版本';

  @override
  String get steamVersionInstallUnverified => '未能确认目标版本安装完成；未应用到 Steam。';

  @override
  String get steamVersionLinkedPath => '版本文件中包含不支持的链接。';

  @override
  String steamVersionApplying(String current, String total) {
    return '正在应用客户端文件 $current/$total';
  }

  @override
  String get steamVersionTargetRequired =>
      '请选择含 steam.exe 的 Steam 目录，或用于全新安装的空目录。';

  @override
  String get steamVersionInvalidBackup => '客户端备份无效。';

  @override
  String get steamVersionBackupTargetChanged => '此备份属于其他 Steam 目录。';

  @override
  String get steamVersionLatest => '同步官方最新';

  @override
  String get steamVersionHistory => '更新历史索引';

  @override
  String get steamVersionImport => '导入已下载版本';

  @override
  String get steamVersionCurrent => '当前客户端';

  @override
  String get steamVersionUnknown => '尚未识别版本';

  @override
  String get steamVersionTarget => '安装目录';

  @override
  String get steamVersionEmpty => '没有已缓存的版本';

  @override
  String get steamVersionOfficial => '官方 CDN';

  @override
  String get steamVersionArchive => 'Wayback 存档';

  @override
  String get steamVersionLocal => '本地导入';

  @override
  String get steamVersionPackages => '客户端包';

  @override
  String get steamVersionReady => '已下载';

  @override
  String steamVersionPartial(String current, String total) {
    return '已下载 $current/$total 个包';
  }

  @override
  String get steamVersionDownload => '下载并校验';

  @override
  String get steamVersionVerify => '重新校验下载';

  @override
  String get steamVersionInstall => '安装此版本';

  @override
  String get steamVersionInstallHint =>
      '先在临时目录完成离线安装；替换前备份客户端文件，失败时恢复。游戏、账号配置、Lua 和插件保留。更新行为沿用“设置 → Steam 更新控制”。';

  @override
  String get steamVersionInstalled => '客户端文件已应用并核对版本；请启动 Steam 验证运行。';

  @override
  String get steamVersionDeleteDownload => '删除本地下载包，保留版本目录记录和客户端备份。';

  @override
  String get steamVersionBackups => '客户端备份';

  @override
  String get steamVersionRestoreHint => '恢复该次操作前的客户端文件；先备份当前状态。';

  @override
  String get steamVersionArchitecture => '客户端架构';

  @override
  String get steamVersionStartDate => '起始日期';

  @override
  String get steamVersionEndDate => '结束日期';

  @override
  String get steamVersionHistoryLimit => '最多获取清单数';

  @override
  String get steamVersionHistoryHint => '历史文件可能未被完整存档；只有所有包通过校验后才能安装。';

  @override
  String get steamVersionRefreshLocal => '刷新本机状态';

  @override
  String get steamVersionStartSteam => '启动 Steam';

  @override
  String get steamVersionDetails => '版本详情';

  @override
  String get steamVersionDownloadedVerified => '所有客户端包已通过校验';

  @override
  String get steamVersionStopSteam => '关闭 Steam 后继续安装';

  @override
  String get steamVersionBackupBefore => '操作前自动备份客户端文件';

  @override
  String get steamVersionWaybackSettings => 'Wayback 与缓存';

  @override
  String get steamVersionWaybackAddress => 'Wayback 地址';

  @override
  String get steamVersionWaybackHint =>
      '默认使用 web.archive.org，可填写自定义 Wayback 地址。';

  @override
  String get steamVersionWaybackInvalid => '请输入不含账号信息、查询参数的完整 HTTPS 地址。';

  @override
  String steamVersionCacheHit(String stamp) {
    return '复用历史清单缓存：$stamp';
  }

  @override
  String steamVersionCacheSaved(String stamp) {
    return '历史清单已缓存：$stamp';
  }

  @override
  String get steamVersionCacheHint =>
      '内置目录提供首次可选版本。刷新版本库会发现新增版本；历史索引缓存 24 小时，选中版本的包清单按需获取并保存。';

  @override
  String get steamVersionForceHistory => '强制刷新历史索引';

  @override
  String get steamVersionWaybackDefault => '恢复默认地址';

  @override
  String get steamVersionRefreshCatalog => '刷新版本库';

  @override
  String get steamVersionBuiltin => '内置版本目录';

  @override
  String get steamVersionManifestPending => '待获取清单';

  @override
  String get steamVersionLoadManifest => '获取版本清单';

  @override
  String steamVersionSnapshot(String date) {
    return '历史快照 $date';
  }

  @override
  String get supportAuthor => '支持作者';

  @override
  String get supportAuthorThanks => '请作者喝杯咖啡，感谢你对 FlSteamLua 的支持。';

  @override
  String get feedbackGroup => '加入反馈群';

  @override
  String get feedbackGroupHint => '在 QQ 中搜索此群号，加入交流并反馈问题。';

  @override
  String get copyGroupNumber => '复制群号';

  @override
  String get groupNumberCopied => '群号已复制';

  @override
  String get wechatPay => '微信支付';

  @override
  String get alipay => '支付宝';

  @override
  String get availableUpdates => '可用更新';

  @override
  String applicationUpdateAvailable(String version) {
    return 'FlSteamLua $version 可更新';
  }

  @override
  String kernelUpdateNotification(String version) {
    return '内核 $version 可更新';
  }

  @override
  String get viewChangelogHistory => '查看历史更新日志';
}
