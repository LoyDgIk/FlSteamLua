# 验证记录

日期：2026-11-02。目标：Windows 10/11 x64。

## 环境

- 本机 Windows x64、Flutter 3.44.4、Dart 3.12.2、Visual Studio 2022 C++、Inno Setup 6。
- Dart SDK 从本机同版本完整备份恢复；损坏的下载包未用于构建，原 SDK 目录保留。
- 本机 WMI 查询超时影响 Dart 遥测初始化。验证与发布命令使用 `--suppress-analytics`；未修改或重启系统 WMI 服务。
- Flutter 测试使用 `--concurrency=1`，QuickJS 测试加载 Windows Release 构建的 `flutter_qjs_next_plugin.dll`。

## 自动化与构建

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
- 两台真实 Windows 电脑之间的局域网发现、四连接块传输、断网续传和 Steam 重启后的实际库显示仍需现场低频验收。
- 安装、启动、修改器、补丁、内核和恢复测试使用临时目录、注入接口或本地服务；未对用户真实 Steam/游戏/存档执行修改。
- 尚未在没有 .NET 运行时的干净 Windows 10/11 机器上验收，也未完成跨机器的显示缩放与安装/卸载验证。
- Steamless 的 CC BY-NC-ND 4.0 解包器未移植或分发；通用补丁/Goldberg 不等同于 SteamStub 脱壳。
- 发行物未做代码签名。

## 外部检查与上游

- 额外 Dart Decimate 检查包装器因 `ModuleNotFoundError: No module named 'scripts'` 未能启动；此检查不计为通过。本项目的 Flutter 原生分析与测试结果单独记录。
- 功能和 UI 采用版本见 `UPSTREAMS.md`。收尾阶段远程查询曾遇到连接重置和 GitHub API 限流，未据此声称重新核实了最新上游提交。
- 原 Fluent-Steam-Lua 目录及其既有未提交修改保留；未执行提交、推送或覆盖原目录。
