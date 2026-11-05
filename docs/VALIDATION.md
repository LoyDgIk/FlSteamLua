# 验证记录

日期：2026-11-02。目标：Windows 10/11 x64。

## 环境

- 本机 Windows x64、Flutter 3.44.4、Dart 3.12.2、Visual Studio 2022 C++、Inno Setup 6。
- Dart SDK 从本机同版本完整备份恢复；损坏的下载包未用于构建，原 SDK 目录保留。
- 本机 WMI 查询超时影响 Dart 遥测初始化。验证与发布命令使用 `--suppress-analytics`；未修改或重启系统 WMI 服务。
- Flutter 测试使用 `--concurrency=1`，QuickJS 测试加载 Windows Release 构建的 `flutter_qjs_next_plugin.dll`。

## 自动化与构建

2026-11-06 v0.1.5 发布候选：更新日志统一接入 Markdown 渲染；应用历史日志及
本次发行说明均为中文在前、英文在后。渲染、链接、内核确认和设置页 24 项定向
测试通过（`markdown-tests.log`），Windows 换行解析用例随后纳入发行测试。
发行测试集在隔离目录 `build/ui-fix-check` 执行，345 项通过，原生引擎握手因
当时未构建被跳过；构建后用本次产物执行握手测试通过
（`release-built-engine-handshake.log`）。发行脚本已调整为先构建 Go 引擎，
再运行 Flutter 测试，避免 CI 重复跳过该检查。

全项目静态分析、Flutter Windows Release、Go 全包测试和 vet、Dart worker、
C++ bridge 与云同步 worker 构建均通过。安装器、ZIP、对应源码包及 SHA-256
文件已生成并核对组件与哈希；源码包补入 l10n.yaml。完整测试首次遇到一次
Windows 云导出目录重命名拒绝访问，未修改代码的单项复跑及完整发行测试集
随后通过，未据此增加业务重试。最终测试日志 `release-0.1.5-tests-final.log`，
原生检查 `release-0.1.5-go-test.log`、`release-0.1.5-go-vet.log`，构建/打包
`release-0.1.5-build.log`、`release-0.1.5-package.log`，均位于
`.git/references/audit-20261105/`。实际游戏授权、云同步和两机 LAN 验收边界不变。

2026-11-06 快速开始：引导与设置共 20 项定向测试通过
（`quick-start-final-tests.log`）。覆盖首次进入先显示引导、跳过状态跨应用实例
持久化、未完成时再次显示、设置中重开/返回、中文切换英文、深浅主题/配色/
侧栏样式即时生效、Steam/Lua/内核真实配置页面接线、步骤切换固定导航区，以及
760×560 窗口、150% 文字和减少动画设置下的布局。已有导航与侧栏性能 12 项
用例在 `quick-start-tests.log` 中通过；同批早期的引导时序和 About 定位失败
已由上述最终测试覆盖并通过。

`quick-start-final-analyze.log` 的全项目 `dart analyze --fatal-infos` 无问题。
`quick-start-windows-build.log` 的 Windows Release 构建通过；构建在
`build/ui-fix-check` 源码快照中进行，输入哈希见 `quick-start-build-inputs.json`。
日志均位于 `.git/references/audit-20261105/`。没有启动实际客户端或截图验收，
未执行真实 Steam 配置修改或核心安装。

2026-11-06 Steam 版本库收尾：39 项相关用例通过。`steam-history-final-tests.log`
记录 38 项通过和设置页 About 入口未先滚动到可见区的 1 项失败；该定位修复后的
单项复跑见 `steam-history-settings-recheck.log`。`steam-history-analyze-final.log`
全项目静态分析通过。`steam-history-windows-build-final.log` 的 Windows Release
构建成功（约 63 秒），更新原 `build/windows/x64/runner/Release` 目录。
测试覆盖离线历史目录显示、版本详情按需获取、gzip 清单、
在线发现超出内置清单的新版、历史索引缓存/强制刷新、同版本快照合并、定制
Wayback 只请求指定站点、单页面滚动空状态、安装/回滚保留独立更新配置等。

内置目录最终为 59 项。参考程序的两项快照返回了其他版本，已剔除；其余请求中
38 次清单读取成功，部分请求遭遇暂时网络中断。内置目录不是全部二进制可下载
的承诺；选择版本时仍检查清单 build/架构，安装前检查全部包的大小和 SHA-256。
官方最新和归档索引可在线发现新条目；刷新不再只获取两个最新包。

Wayback 默认值为官方 `https://web.archive.org`，仅保留自定义 HTTPS 地址。
先前的内置镜像和自动归档站点回退已删除，对应旧回退测试不再代表当前行为。
自动更新控制只在既有设置页维护，版本安装和恢复不修改 Steam.cfg。
未运行真实 Steam 引导器升级/降级或用户目录替换；安装使用注入 runner 和临时
目录验证，HTTP 服务器使用真实 loopback 请求。没有执行新的视觉检查。

2026-11-06 加载布局与失败提示：页面级不定进度统一使用
`CommonScaffold.isLoading` 覆盖层，编辑、提取、票据、Goldberg、成就、偏好、
账号、校验和库页不再临时插入加载行。回归先复现编辑区域下移 10 像素、内核
检查失败后操作条目下移 52 像素，以及更新错误导致最后一行被标记为分组起始行
而丢失底部圆角。修复后验证加载出现/消失时矩形和滚动偏移不变、错误卡片位于
分组外且相隔至少 12 像素、卡片使用正常可读颜色。

受影响的 55 项独立用例分批通过；早期批次中的旧文案、导航入口和惰性列表定位
断言已修正，失败用例均在后续定向复跑中通过。日志：`loading-layout-fixed.log`、
`loading-affected-tests.log`、`loading-final-regression.log`、
`loading-patch-page-test.log`（以每个用例最后一次执行为准）。
`loading-complete-analyze.log` 的全项目 `dart analyze --fatal-infos` 无问题。
`loading-final-windows-build.log` 的 Windows Release 构建成功；源码快照位于
`build/ui-fix-check`，构建没有覆盖原运行目录。本轮没有启动客户端做视觉检查。
以上日志和构建输入哈希在 `.git/references/audit-20261105/`。

2026-11-06 云存档账号头像：工具栏复用侧栏的 `SteamAvatar` 和本地头像缓存，
账号选择展示昵称、账号 ID 与头像。页面测试验证筛选切换对应账号头像、切换时
不重复查询头像路径，以及原有对齐/草稿/详情流程（`cloud-avatar-page-final-test.log`）。
侧栏与导航的 12 项定向测试通过（`cloud-avatar-tests.log`，其中云页图片夹具问题
已在上述单项复测修正）；最后的静态分析通过（`cloud-avatar-analyze.log`）。


2026-11-05 云存档管理重构及布局修正：云存档、交互流程和国际化共 78 项相关测试
通过。`cloud-final-tests.log` 记录 77 项通过及 1 项测试定位器歧义；该测试已改为
定位实际分组行，`cloud-page-final-test.log` 和后续 `cloud-layout-test.log` 均通过。
最后的 `dart analyze --fatal-infos` 无问题（`cloud-layout-analyze.log`）。

覆盖多套同提供方配置及 DPAPI 文件隔离、保存/激活/浏览分离、草稿读写测试、
按需文件清单、刷新失败保留列表、S3 前缀逐对象删除、上传失败回滚、按存储身份
恢复、管理式恢复前快照、SHA-256 校验、备注与固定保留、清理预览，以及核心
返回成功但缓存哈希不符时回滚。真实核心同步调用使用注入 runner 和临时目录，
没有执行真实 Steam 云同步。Windows WinHTTP 协议测试只使用本地服务。

界面测试覆盖表单错误保留、取消未保存草稿、行点击进入详情、备份目标展示，
一次确认关闭 Steam 并继续操作；布局回归验证状态区文字起点一致、账号筛选
保留在工具栏且不再插入横栏改变游戏列表位置。没有进行新的视觉检查或截图验收。


2026-11-05 侧栏展开/缩放与数据管理布局：侧栏、导航状态、设置和面板的 30 项
定向测试通过（`sidebar-tests.log`），当时全项目静态分析通过
（`sidebar-analyze.log`）。夹具中，隐藏页面在展开时的布局次数由 17 次降为 0，
窗口缩放时由 14 次降为 0，单次展开的头像路径查询由 17 次降为 1；保存侧栏状态
前后的明暗 ThemeData 保持同一实例。这些是组件测试的工作量计数，不是 Release
帧率或真人操作流畅度验收。

数据管理回归在修复前测得占用条宽度为 0（可用内容宽度 1032），数值列相差
54 像素。已补全占用条宽度约束和各行固定操作区，并添加宽/窄窗口几何断言。
随后将游玩时长/最近游玩改为只读 Steam 的账号历史，删除客户端自行计时及
落盘。库服务、账号历史选择、未知/零时长、进程观察、修改器联动、详情、库页、
数据管理、侧栏、导航与面板共 68 项定向测试通过
（`playtime-ui-final-tests.log`）。只读真实 Steam 的 LibraryService 探针得到
AppID 1962700 的 `1247` 分钟（`20.8` 小时），最近游玩为 2026-11-03，且未创建
客户端时长记录（`playtime-real-read.log`）。

共享工作区的云存档代码并行编辑曾阻断整项目分析与编译，记录在
`data-sidebar-final-tests.log`、`data-sidebar-final-analyze.log` 和
`playtime-ui-final-analyze.log`。这些阻断已消除，后续全项目分析与包含本轮改动的
隔离 Release 构建通过，见上面的 2026-11-06 记录。
上述日志位于 `.git/references/audit-20261105/`。本轮没有继续视觉检查，亦未执行
Steam 重启、游戏分支切换或真实游戏下载操作。

2026-11-05 局域网 `/5` 修复与传输卡片：原生 `go test -race -count=1
-timeout=120s -v ./...` 的 51 项顶层测试通过，`go vet ./...` 通过。覆盖差量内容
校验和重定位、路径/junction 边界、暂停/取消/断线、引擎重启续传、等待批准时停止、
暂存清理、真实磁盘/安装进度回传。局域网与数据管理 21 项 Flutter 定向测试通过。
`dart analyze --fatal-infos` 和 Windows Release 构建通过。卡片深浅主题、宽窄窗口
以真实 Flutter 渲染的测试夹具检查；隔离启动 Release 客户端确认接收关闭时没有
Go 子进程。未操作用户已运行的客户端。

相同本机 TLS 回环夹具中，4096 个 16 KiB 文件的新安装由 16.67 秒缩短到 4.28 秒
（4.0 → 15.7 MB/s），新目录整体提交阶段约 0.014 秒。1 GiB 大文件测得约
133–181 MB/s；这是同机 D: 缓存参与的单次数据通路结果，不是两机网速或 Steam
A/B。日志和卡片预览保存在 `build/diagnostics/lan-transfer-20261105/`。

2026-11-05 核心契约修正、Lua 多目录和票据身份策略：`dart analyze --fatal-infos`
通过；票据事务、身份选择与恢复侧栏、Lua 多目录、库导入、设置、DLC、相关局域网
配置和国际化共 118 项定向测试通过；收尾的内核状态、面板与票据侧栏 14 项测试
通过。`flutter build windows --release --no-pub` 成功生成 Release 客户端。

票据测试覆盖：不存在/相同/不同缓存身份时默认不写 SteamID、显式同步、每一项
凭据写入后失败回滚、整组恢复及恢复失败回滚、Lua 语句清理与字节恢复、预览过期
拒绝、真实 Windows DPAPI 加密备份跨服务实例恢复。注册表与 Steam 启停使用注入
夹具，未修改真实 Steam 凭据。Lua 排序侧栏的取消和确认已通过交互测试；按用户要求
停止后未继续视觉检查。当前构建不代表真实游戏授权握手或云端同步已经验收。

本轮日志在 `.git/references/audit-20261105/`：`ticket-final-tests.log`、
`final-state-ui-tests.log`、`complete-analyze.log`、`final-windows-build.log`。
额外 Dart Decimate 包装器仍因 `ModuleNotFoundError: No module named 'scripts'`
无法启动，不计为通过。

最终发布验证进行中。结果以本次发布日志为准，不能将此前构建或定向测试视为最终全套通过。

2026-11-04 局域网传输 Go 引擎迁移：`dart analyze --fatal-infos`、`go test ./...`、
`go vet ./...` 和 Flutter 全套 `431` 项测试通过；`test/lan_transfer` 覆盖 JSON-RPC
生命周期、服务事件映射、任务重入和速度组件；Go 回环测试覆盖 TLS 上传、双 chunk
重建、已有 chunk 差量和发送端消失。PBZ 本机计划实测约 `0.32 s`，生成
`145,953` 个 chunk，初始 offer 不携带 chunk 列表。
Shell、库页、工具服务与国际化 25 项定向测试通过；
`flutter build windows --release` 成功生成
`build/windows/x64/runner/Release/fl_steam_lua.exe`。

2026-11-04 数据管理、云存档与独立授权工具：数据目录配置/迁移/清理、云存档备份
侧边栏搜索、D加密授权独立入口、提取页授权跳转和库页拖入 `tickets.txt` 定向测试
通过。游戏文件校验新增跨 Steam 库清单查找；仓库清单缺失时不再直接失败，而是返回
明确标记的未校验文件盘点，避免把缺少清单的 depot 文件误判为非游戏文件。

可复现入口：`scripts/build-release.ps1`。脚本依次执行依赖恢复、静态分析、Windows Release 构建、全套测试、独立 Dart worker 和原生桥构建，再生成发行物。

主要证据位于本机 `build/validation-*.log` 与 `build/smoke`。这些运行产物不纳入源码包。

## 覆盖范围

- 临时 Steam/VDF/ACF/Lua 目录：AppID 合并、安装/Lua/拥有状态区分、导入、收藏、启停、备份与恢复。
- 局域网传输：双向 TLS、二进制帧、manifest 计划、已有 chunk 位图、分块重建、
  差量复用、发送端消失和临时 Steam 库 ACF 写入已由 Go/Flutter 定向测试覆盖。
- 临时内核包：路径与包校验、切换、单注入入口、失败回滚、卸载及备份恢复。
- 任务与页面：后台任务继续运行、取消和错误、独立导航栈、工具与设置返回、游戏上下文。
- 组件：中英文、明暗主题、紧凑布局、150% DPR、Ctrl+1/2、减少动画及主题交叉淡变。
- 进程：真实 Win32 进程快照读取，以及注入的外部游戏启动/退出、路径匹配、修改器生命周期测试。
- CloudRedirect 配置与凭证格式、目录迁移、备份校验、云端 HTTP/OAuth/S3/WebDAV 协议夹具。
- Windows 本地 HTTP 服务与真实 WinHTTP FFI：DAV 方法、二进制正文、认证头优先级、不发送隐式当前用户凭证、不跟随重定向。
- QuickJS：异步 Promise HTTP、POST、取消与超时，四个内置源的宿主契约。
- 密钥订阅、缓存激活、元数据缓存、离线生成、DLC 分析与过期预览拒绝。
- 补丁事务、Goldberg 配置、票据格式/加密/注册表恢复夹具、网络偏好与后台设置。

## 真实资源与尚未完成的验收

- 此前实际匿名 Steam 协议探测获取了 AppID 440 的 PICS 信息（10 个 depot、6 个 DLC）；此结果只证明当时的匿名查询路径，不代表账号或私有内容验收。
- 尚未使用指定真实账号验证密码登录、Steam Guard、会话恢复、私有 depot/manifest、成就写回或授权票据应用。
- 尚未使用指定云端资源验证 Google Drive/OneDrive OAuth、S3/R2/WebDAV 上传恢复、域 NTLM/Kerberos 或真实 CloudRedirect DLL 注入加载。
- 两台真实 Windows 电脑之间的局域网发现、TLS 块传输、断网续传和 Steam 重启后的实际库显示仍需现场低频验收。
- 安装、启动、修改器、补丁、内核和恢复测试使用临时目录、注入接口或本地服务；未对用户真实 Steam/游戏/存档执行修改。
- 尚未在没有 .NET 运行时的干净 Windows 10/11 机器上验收，也未完成跨机器的显示缩放与安装/卸载验证。
- Steamless 的 CC BY-NC-ND 4.0 解包器未移植或分发；通用补丁/Goldberg 不等同于 SteamStub 脱壳。
- 发行物未做代码签名。

## 外部检查与上游

- 额外 Dart Decimate 检查包装器因 `ModuleNotFoundError: No module named 'scripts'` 未能启动；此检查不计为通过。本项目的 Flutter 原生分析与测试结果单独记录。
- 功能和 UI 采用版本见 `UPSTREAMS.md`。收尾阶段远程查询曾遇到连接重置和 GitHub API 限流，未据此声称重新核实了最新上游提交。
- 原 Fluent-Steam-Lua 目录及其既有未提交修改保留；未执行提交、推送或覆盖原目录。
