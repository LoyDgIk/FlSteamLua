# Changelog

各版本先列出中文说明，再列出英文说明。发布说明取自对应的版本章节。
Each release lists Chinese notes first, followed by English.

## [Unreleased]

## [0.1.6] - 2026-11-06

### 中文

#### 修复

- 修正从应用内启动更新时，安装器结束应用进程树而把自己一并关闭的问题。现在只结束应用及明确列出的工作进程，保留正在运行的安装器。
- 安装前同时关闭云同步工作进程，避免更新时文件仍被占用；新增隔离的 Windows 父子进程回归测试。

#### 新增

- 关于页整合应用更新检查与完整历史更新日志；版本说明统一在侧栏阅读，不再占用设置页布局。
- App 与内核在自动检查发现新版本时会显示全局提示，并在侧栏提供“可用更新”入口，避免只在首页或设置中才能看见。
- 关于页增加 QQ 反馈群与支持作者入口，主页和库页工具栏提供咖啡图标快捷入口；微信与支付宝支持码在统一侧栏中展示。
- 重新设计应用图标，统一应用、窗口、任务栏、托盘与安装器的品牌资源，并提供适配小尺寸的多分辨率 ICO。
- 发布全新的 [应用介绍页](https://LoyDgIk.github.io/FlSteamLua/)，包含实际客户端截图、交互式功能展示和可暂停的动效，由 GitHub Pages 自动部署。

### English

#### Fixed

- Fixed the installer closing itself when an update was launched from the app. Setup now stops only the application and explicitly listed workers, preserving the installer process.
- Added the cloud-sync worker to installation cleanup and a Windows regression test with isolated parent/child processes.

#### Added

- Consolidated app update checks and the complete changelog history into About; release notes now open in side sheets without consuming page layout.
- Automatic checks for the app and kernel now show a global notice and a persistent Available updates entry in the sidebar.
- Added QQ feedback group and author support entries to About, plus coffee shortcut buttons in the Home and Library toolbars with the supplied WeChat and Alipay codes in a shared side sheet.
- Redesigned the app icon across the application, window, taskbar, tray and installer, with multiple ICO resolutions for small sizes.
- Published a new [application website](https://LoyDgIk.github.io/FlSteamLua/) with actual client screenshots, interactive feature exhibits and pausable motion, deployed through GitHub Pages.

## [0.1.5] - 2026-11-06

### 中文

#### 新增

- **快速开始引导**：首次进入可选择语言、主题、配色与侧栏样式，再配置 Steam、Lua、内核和内容来源；支持跳过，设置中可再次打开。
- **Lua 多目录**：对接内核 `lua.paths`，固定目录置顶，自定义目录集中在设置中管理；通过排序侧栏调整顺序，第一项作为默认写入目录。
- **Steam 版本库**：提供历史版本目录、在线发现、清单按需获取、安装前校验和备份恢复；版本操作保留独立的自动更新设置。
- **云存档管理**：支持多套存储配置、草稿连接测试、账号筛选与头像、位置详情，以及带备注、固定保留和恢复前快照的备份管理。

#### 改进

- 应用更新日志、在线版本说明和内核安装/切换说明统一渲染 Markdown，支持标题、列表、代码、表格和可点击链接。
- 票据默认仅写入 `AppTicket`、`ETicket`，保留已有授权身份；明确区分登录账号、票据账号和缓存身份，只有用户显式选择时才同步 SteamID。
- 每次应用票据前以 DPAPI 加密备份整组凭据；失败时回滚，支持完整恢复，并在确认后备份、清理 Lua 中可能覆盖新票据的旧语句。
- 游玩时长和最近游玩时间直接读取 Steam 账号记录，客户端停止自行计时；缺失记录与实际零时长分别显示。
- 局域网传输改进差量校验、断点恢复、暂停/取消、接收确认和小文件安装，传输卡片显示实际网络与磁盘进度。
- 完善内容来源配置、清单请求上下文与内核请求码配置，统一设置与工具中的相关入口。

#### 修复

- 修正默认 Lua 路径与核心加载目录不一致、插件开关写入示例配置、云缓存与远端仓库混淆等问题。
- 修正侧栏展开和窗口缩放时隐藏页面重复布局、无关设置触发整窗主题过渡，以及每帧重复查询头像的问题。
- 保留顶部加载条，并消除加载期间正文位移；修正失败提示与条目分组的圆角、间距和文字颜色。
- 修正数据管理占用条宽度和数值对齐、云存档筛选布局、部分对话框和导航交互。

### English

#### Added

- **Quick start** guides first-time users through language, appearance, Steam, Lua, core and content-source setup. It can be skipped and reopened from Settings.
- **Multiple Lua directories** follow the core's `lua.paths`. The fixed directory appears first; custom paths are managed in Settings and reordered in a side sheet, with the first custom path used for new files.
- **Steam version library** adds historical releases, online discovery, on-demand manifests, verified installation and backup recovery while preserving update-control settings.
- **Cloud-save management** adds multiple storage profiles, draft connection tests, account filtering and avatars, location details, and backups with notes, retention pins and pre-restore snapshots.

#### Changed

- Bundled changelogs, application release notes and kernel installation/switch notes render Markdown headings, lists, code, tables and links.
- Ticket application updates `AppTicket` and `ETicket` while preserving the existing authorization identity by default. Login, ticket and cached identities are shown separately; SteamID changes require an explicit choice.
- Ticket operations save complete DPAPI-encrypted credential backups, roll back failures, support full recovery, and back up/remove conflicting Lua ticket calls after confirmation.
- Playtime and last-played dates come directly from Steam account records. The client no longer accumulates its own time and distinguishes missing data from zero minutes.
- LAN transfer improves delta verification, resume, pause/cancel, receiver approval and small-file installation, with actual network and disk progress on transfer cards.
- Content-source configuration, manifest request context and kernel request-code settings are connected consistently across settings and tools.

#### Fixed

- Corrected Lua loading paths, writes to example rather than active plugin configuration, and confusion between cloud caches and remote repositories.
- Removed hidden-page relayout during sidebar/window resizing, unrelated full-window theme transitions and per-frame avatar lookups.
- Kept loading indicators while eliminating content movement, and corrected failure-card grouping, spacing, corners and text colors.
- Corrected storage-usage bars, numeric alignment, cloud-filter layout and several dialog/navigation interactions.

## [0.1.4] - 2026-11-04

### 中文

- 修正游戏管理中的清单缓存清理：覆盖所选游戏各 depot 在所有 Steam 库中的 `depotcache` 和 `steamapps\depotcache`。

### English

#### Fixed

- Game management now clears all manifest files for the selected game's depots
  from every Steam library's `depotcache` and `steamapps\depotcache`.

## [0.1.3] - 2026-11-04

### 中文

- Lua 库卡片显示清单版本固定状态。
- 游戏管理支持清理所选 AppID 下载的清单包，不改动 Steam depotcache 或 Lua 配置。
- 游戏详情不再显示账号拥有状态。

### English

#### Added

- Lua library cards show when a manifest version is pinned.
- Game management can clear downloaded manifest packages for the selected
  AppID without changing Steam depotcache or Lua configuration.

#### Changed

- Game detail pages no longer show account ownership status.

## [0.1.2] - 2026-11-04

### 中文

- Windows 安装器支持简体中文和英文，默认优先显示简体中文。
- 安装器在替换文件前关闭正在运行的应用、工作进程和局域网传输引擎。

### English

#### Changed

- The Windows installer now offers Simplified Chinese and English, with
  Simplified Chinese selected first.
- Setup force-closes a running FlSteamLua application, worker and LAN transfer
  engine before replacing installed files.

## [0.1.1] - 2026-11-04

### 中文

- 应用更新页新增当前版本更新日志。
- DLC 刷新移到工具栏和空状态，移除冗余操作区与 Lua 拥有状态说明。
- 发布验证采用定向测试集；可通过 `build-release.ps1 -FullTests` 执行全套测试。
- 修正 Windows 短路径导致修改器无法停止或解除绑定的问题。
- 更新来源固定为 `LoyDgIk/FlSteamLua`，不再展示多余的仓库设置。

### English

#### Added

- The application update page now displays the current release changelog.

#### Changed

- DLC refresh is available from the top toolbar and the empty state; the
  redundant full-width action area has been removed.
- Release validation now runs a focused high-value test set. Use
  `build-release.ps1 -FullTests` when the complete suite is required.

#### Fixed

- Removed the redundant Lua ownership caption from DLC analysis results.
- Windows short-path aliases no longer prevent a running trainer from stopping
  or its binding from being removed.
- The update source remains fixed to `LoyDgIk/FlSteamLua` without exposing a
  redundant repository row.

## [0.1.0] - 2026-11-04

### 中文

- 首个 Windows Flutter 桌面版本，提供 Steam 库、Lua、成就、云存档、商店和游戏工具。
- 引入基于 FlClash 的共享界面、侧栏、分组列表、搜索、主题和动画。
- 统一订阅、JavaScript、Lua、清单和本地导入的内容来源管理。
- 支持 OpenSteamTool 内核管理、注入入口、备份恢复与残留清理。
- 提供 TLS 局域网传输、差量分块、断点恢复、清单校验和 Steam 库安装。
- 新增票据提取与导入、DPAPI 备份、DLC、校验、补丁、修改器、联机辅助和数据管理。
- GitHub 更新下载增加校验，并接入自动构建发布流程。
- 修正跨库清单查找、加载进度显示和云存档目录打开行为。

### English

#### Added

- Windows Flutter desktop app for Steam libraries, Lua management, achievements,
  cloud saves, store browsing and game tools.
- FlClash-based shared UI framework, side sheets, grouped lists, search,
  transitions and theme controls.
- Unified content-source architecture for subscriptions, JavaScript sources,
  Lua, manifests and local imports.
- Native OpenSteamTool kernel management, package repository, local packages,
  injection entries, snapshots and residual cleanup.
- Go LAN transfer engine with TLS, discovery, delta chunks, resumable staging,
  manifest verification and Steam library installation.
- D encryption authorization tool with ticket extraction, `tickets.txt` import,
  DPAPI backups and explicit registry application.
- DLC management, game file verification, patch tools, trainers, online fixes,
  cloud-save backups and data/cache management.
- Checksum-verified GitHub release updates and this automated release workflow.

#### Changed

- Replaced legacy Material and native dialogs with the shared FlClash-style
  presentation layer.
- All visible strings use generated ARB localization.
- Cloud saves use a single searchable save list while backup history is grouped
  by game in a side sheet.

#### Fixed

- Game verification searches all Steam libraries and falls back to an explicit
  unverified inventory when exact depot manifests are unavailable.
- Indeterminate progress bars show a full track with a moving sweep.
- Cloud-save folders open through a detached Explorer process.
