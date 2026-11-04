# FlSteamLua

面向 Windows 10/11 x64 的 Steam 桌面工具，使用 Flutter 编写界面、Dart 实现业务，
局域网传输由独立 Go 原生引擎执行。
主导航为 **面板主页、库、商店、成就、云存档**。库内默认展示 Lua 库，第二个 Tab 为 Steam 游戏库。高级操作从游戏详情的“管理”、左下角“工具”和“设置”进入。

## 功能

- 自动识别 Steam 安装路径，按 AppID 合并本机安装记录与 Lua，支持搜索、收藏、导入、启动和 Lua 启停。安装、Lua 配置和账号拥有状态相互独立。
- Steam 商店搜索、分类、详情与 DLC；统一内容源管理订阅、JS 与本地导入，入库必选 Lua 来源、可选清单来源，预览后备份提交。购买及游戏本体安装交给 Steam。
- 独立 Dart 工作进程和 Windows 原生接口处理成就、统计及授权票据，修改先预览再保存并读回确认。
- 本地云存档重定向、备份和恢复，Google Drive、OneDrive、S3/R2、WebDAV 远端存储；WebDAV 支持 Basic、Digest、Bearer、NTLM、Negotiate。目录切换保留原存档。
- QuickJS 内容源、显式 Lua/清单 ID/清单文件能力、Steam 登录与资料提取、独立订阅缓存和离线 Lua 生成、DLC 仓库分析。订阅没有全局激活状态，每次操作明确指定来源。
- 内核包下载/导入/切换/备份恢复；Lua/VDF 转换、版本固定、修改器绑定、OnlineFix、通用补丁与 Goldberg 配置。
- 全局任务、独立页面栈、明暗主题、ARB 国际化、键盘导航、托盘和单实例。已识别或绑定的游戏进程可从 Steam/快捷方式启动并触发修改器联动。
- 局域网传输使用独立 `lan_transfer_engine.exe`：Go 负责设备发现、双向 TLS、manifest/chunk 计划、16 路调度、差量位图、断点恢复和安装；Dart 只负责界面与用户确认。

## 运行

需要 Flutter 3.44.4 / Dart 3.12.2、Go 1.25 或兼容工具链，以及 Visual Studio 2022 的 Desktop development with C++ 组件和 Windows SDK。

```powershell
flutter pub get
flutter run -d windows
```

应用数据保存在 `%LOCALAPPDATA%\FlSteamLua`。首次启动直接读取当前 Steam 安装、账户和游戏库；不迁移旧应用配置或历史记录。敏感缓存、会话和凭证使用当前 Windows 用户的 DPAPI 加密。

成就和票据功能需要同目录下的 `steam_worker.exe`、`steam_bridge.dll`；局域网传输需要 `lan_transfer_engine.exe`。发行脚本会构建并打包三者。开发时可先执行发行构建，或参照 `scripts/build-release.ps1` 的 Go、worker 与 native 构建命令。应用不调用原 WPF 程序，不需要 .NET 后台。

## 检查与打包

```powershell
flutter analyze
flutter build windows --release
$env:FLUTTER_QJS_NEXT_LIBRARY = (Resolve-Path 'build\windows\x64\runner\Release\flutter_qjs_next_plugin.dll').Path
flutter test --no-pub --concurrency=1
```

QuickJS 原生测试需要先构建 Windows 插件。全套测试串行运行，以免同时启动多个 Flutter 测试虚拟机占用过多内存。

安装 Inno Setup 6 后执行：

```powershell
.\scripts\build-release.ps1
```

脚本执行分析、Release 构建、Flutter/Go 测试、Go 传输引擎、独立工作进程和原生桥构建，随后在 `dist` 生成 ZIP 解压版、安装包、对应源码压缩包和 SHA256 文件。安装包未进行代码签名。发布前应同时提供对应源码及许可文件。

## 验证范围

功能映射见 `docs/FEATURE_PARITY.md`，本次实际执行结果见 `docs/VALIDATION.md`。隔离 HTTP、临时目录和组件测试不能替代真实 Steam 账号、游戏和云端验收；未使用用户账号或远端数据执行修改操作。

- 离线 Lua 生成需要事先显式缓存应用的仓库元数据；生成步骤本身不联网。
- 游戏进程以完整可执行文件路径匹配；不能读取的受保护进程不会猜测为运行。
- Steamless 原解包器使用 CC BY-NC-ND 4.0，未移植或打包；通用补丁和 Goldberg 部署不等同于 SteamStub 脱壳。
- 应用更新仅使用设置中明确指定的 FlSteamLua 发布仓库，不下载原 WPF 应用替代更新。

## 开源许可与上游

FlSteamLua 使用 GPL-3.0。FlClash 界面组件及动效参考固定提交 `7fd417fb9a9a277c6a9339a8ac87f907df7c25f7`；功能依据本地 Fluent-Steam-Lua `aeec310a536506304bdd16420bbe1601595abad3` 和原工作区已有增强，以 Dart 重写。

原项目目录保持独立。以后按功能差异移植上游更新，不直接合并 C# 文件。采用版本、组件映射和修改说明见 `docs/UPSTREAMS.md`；完整声明见 `THIRD-PARTY-NOTICES.md` 和 `assets/licenses`，应用内入口为“设置 → 关于 → 开源许可”。
