# 功能对照

基线：2026-11-01 本地 Fluent-Steam-Lua `aeec310a536506304bdd16420bbe1601595abad3`，包括该目录原有未提交的内核管理增强。原目录独立保留。

“已实现”表示有 Dart 业务及可达入口。是否通过实际测试、是否完成真实账号验收，分别以 `VALIDATION.md` 为准。

| 入口 | 已实现范围 | 主要验证目录 |
| --- | --- | --- |
| 面板主页 | Lua/Steam 库直达、内核启停、内容源状态与更新、工具入口、真实任务进度和取消、运行中与最近游戏启停 | `test/app` |
| 库 | 默认 Lua / Steam 双 Tab、拖拽预览入库、封面与名称、多选和批量启停/删除、编辑/导出、右键存档等管理、视图排序与状态保留 | `test/library` |
| 商店 | 搜索、分类、分页、详情、DLC、添加到库；购买/安装交给 Steam | `test/store` |
| 游戏详情 | 真实库状态、启动、Lua/DLC、成就与云存档跳转；管理菜单保留 AppID | `test/app/detail_test.dart` |
| 成就 | 独立 Dart worker、命名管道与 C ABI；成就/统计读取、待保存修改、提交后读回确认、票据提取 | `test/achievements`、`test/platform` |
| Steam 客户端版本 | 内置历史目录与在线新增发现、架构筛选、自定义 Wayback 地址、按需清单缓存、断点续传及校验、暂存安装、客户端快照恢复；更新控制沿用设置页 | `test/steam_versions` |
| 云存档 | CloudRedirect 配置/部署、多套独立存储、表单内 OAuth/读写测试、账号头像筛选与游戏详情、备份备注/固定/校验/清理、操作前快照和目标身份校验、核心单游戏拉取；迁移目录保留原存档 | `test/cloud` |
| WebDAV | Basic/Auto/Digest/Bearer/None/NTLM/Negotiate；显式 HTTP/不安全 TLS 选项 | `test/cloud/remote` |
| 内核管理 | 发行版与本地 ZIP 仓库、下载/导入/切换、入口选择、启停、备份/恢复、卸载及残留清理 | `test/kernel` |
| 内容源 | 统一订阅/JS 列表、Lua/清单 ID/文件能力、配置/测试/更新/启停/删除、按计划组合、预览/备份/事务提交与回滚、本地导入 | `test/content_sources`、`test/manifests` |
| 账号管理 | 读取 `loginusers.vdf` 与 `avatarcache`、左下角账号切换、切号重启 Steam、添加账号调起 Steam 自身登录 | `test/app`、`test/library` |
| 提取工具 | 从本机 `local.vdf` 恢复 Steam 会话、Lua/清单提取；页面提示必须真实拥有 | `test/steam_protocol`、`test/achievements` |
| D加密授权 | 独立工具入口、AppTicket/ETicket 提取、`tickets.txt` 导入与库页拖拽跳转、DPAPI 加密备份、校验后写入 Steam 注册表；页面提示必须真实拥有 | `test/patching`、`test/tools`、`test/app` |
| 密钥缓存 | 订阅增删改、更新/启停/间隔、按来源隔离的 DPAPI 缓存和应用元数据、离线 Lua/DLC/版本固定生成 | `test/key_cache` |
| DLC 管理 | FlClash 表单与分组条目、统一内容源注册表中的订阅密钥缓存、DLC 仓库结构分类、Lua 对照、缺密钥提示、批量选择、侧边栏预览、备份及追加 | `test/dlc_analysis`、`test/content_sources` |
| 常用工具 | Lua/VDF 转换、目录批处理、版本固定/解除、手工 DLC、封面、清单监听、目录与诊断工具 | `test/tools` |
| 修改器 | FLiNG 默认目录/搜索/完整目录/归档、详情与下载管理、绑定增删改和启停；应用内或外部已识别游戏进程触发联动和退出清理 | `test/tools/online`、`test/app/trainer_lifecycle_test.dart` |
| 联机工具 | OnlineFix 480 说明、检索、详情、详情内直接下载、目录层级返回、任务进度和取消、分游戏下载及使用说明 | `test/tools/online` |
| 局域网传输 | 按需启动 Go 引擎、UDP 发现/手动 IP、双向 TLS、可信设备、内容校验与差量重建、16 个在途块、重启续传、ACF/Lua/manifest 入库、独立页面与主题传输卡片 | `test/lan_transfer`、Go `internal/engine` |
| 补丁 | 补丁设置、清单文件校验（跨 Steam 库查找清单，缺清单时降级为未校验文件盘点）、非清单文件建议、网络补丁下载/解压、Goldberg 部署及配置 | `test/patching` |
| 网络 | 封面 CDN/接口选择与测速、公开 GitHub 下载镜像与测速、失败回退 | `test/network` |
| 设置 | 路径、内核、统一内容源、主题、ARB 国际化、更新、托盘、自动刷新、开机启动、好友广播、离线模式、许可 | `test/preferences`、`test/app/settings_test.dart` |
| 桌面与发布 | 单实例、托盘、应用专用更新仓库、独立 worker/native/VC runtime 打包、安装包与 ZIP | `test/desktop`、`scripts/build-release.ps1` |

## 明确边界

- 不导入旧应用设置、缓存和历史数据；此限制不影响新应用自身的存档目录迁移。
- 旧同步 JS 接口不兼容，现有脚本采用 `download(ctx)` / 可选 `test(ctx)` 与 Promise HTTP。
- Steamless 原解包器使用 CC BY-NC-ND 4.0，未移植或分发。补丁与 Goldberg 功能不等同于 SteamStub 脱壳。
- 修改器旧模型中的 `AutoKeys` 在本地旧实现也未被实际消费；本项目不声称提供未落地的按键激活能力。
- 进程识别基于完整路径，不猜测不可读取的受保护进程。游玩时长和最近游玩时间只读取 Steam 账号记录，客户端不再自行计时。
- 真实账号登录、Guard、私有 depot、成就修改、云端 OAuth/上传恢复、域 NTLM/Kerberos 和 CloudRedirect 加载，需要指定测试账号/游戏/远端资源完成验收。
- 局域网传输不调用 Steam 进程、Steam 账号接口或 Steam 私有 LAN 协议；写入 ACF 只刷新“已安装记录”，不改变授权。两台真实 Windows 电脑的中断续传和 Steam 重启识别仍需现场验收。
