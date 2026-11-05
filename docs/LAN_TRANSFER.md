# 局域网游戏传输

FlSteamLua 的局域网传输由独立 Go 进程 `lan_transfer_engine.exe` 完成。Flutter
只负责页面、设备确认、目标库选择和状态展示；发现、TLS、manifest 解析、chunk
调度、缓存索引、断点恢复和最终安装均不经过 Dart 数据通道。

该协议是 FlSteamLua 自有的内容传输协议，不尝试冒充或兼容 Steam 客户端私有的
局域网内容协议。

## 进程与 IPC

- `lan_transfer_engine.exe` 使用 Windows x64 构建，按数据目录单实例运行。默认在
  打开局域网页面、准备发送或操作传输暂存时启动；只有开启“允许向此设备传输”
  时随应用启动并保持接收。引擎随应用退出，首次并发使用共享同一次启动过程。
- Flutter 通过继承的 stdin/stdout 发送逐行 JSON-RPC；响应携带相同 `id`。
- 异步事件使用 `event/data`，日志只写 stderr。
- Dart 命令包括 `hello`、`configure`、`discovery.start`、`discovery.stop`、
  `peer.probe`、`plan.prepare`、`plan.discard`、`send.start`、
  `offer.accept`、`offer.reject`、`session.pause`、`session.resume`、
  `session.cancel`、`session.list`、`trust.set`、`cache.stats`、`cache.clear` 和 `shutdown`。
- Dart 不保存完整 chunk 列表。计划以 `planId` 留在 Go 引擎中，界面只接收文件
  分类、大小、数量和可选附件摘要。

## 发现与身份

- UDP 发现使用 `239.255.42.99:47821`，同时支持广播和手动 IP。
- TCP 传输使用 `47821`，协议版本为 `flsteamlua-lan/5`。两端均须使用新版引擎；
  v4 的附加块没有内容摘要，旧接收端不能可靠验证复用内容，因此不互通。
- 每台设备生成独立的 ECDSA P-256 身份证书；TLS 最低版本为 1.3。
- 双方都提供客户端证书，连接阶段校验 SHA-256 指纹。文件传输期间只复用该
  TLS 会话，不对每个文件或 chunk 重复执行 RSA 签名。
- 未知设备必须由接收端确认；确认后可记住设备、默认目标库和自动接受设置。

## 二进制协议

每个帧由固定 24 字节帧头和 payload 组成：

- magic `FLST`
- protocol version
- frame type
- flags
- stream ID
- payload length
- CRC32C

控制消息使用 Protobuf wire format，chunk payload 保留原始字节。小块与控制帧合并
成一次写入；大块只合并帧头与索引，避免复制整个块。协议支持
Hello、Offer、Decision、Plan、PlanReady、ChunkData、ChunkAck、Credit、
Finish、Cancel 和 Error。

初始 offer 只包含 AppID、游戏名、总大小、文件/chunk 数量和警告，不包含几十
万个 chunk。接收端接受后才在同一 TLS 连接内传输完整计划和缺失块位图。

## 计划与 chunk

- Go 引擎直接解析 VDF/ACF、Lua 和 Steam `depotcache/*.manifest`。
- manifest 文件名加密时，通过 Windows DPAPI 解出 key cache 后使用 AES-256
  解密文件名。
- 官方文件使用 manifest 中的文件大小和 chunk SHA-1；清单中缺失或尺寸不符的
  官方源文件会在准备阶段报错。manifest 之外的附加文件使用 4 MiB 固定分块，
  块 ID 来自真实内容 SHA-1，同时计算文件 SHA-1。
- 接收端先校验本地块再返回已有位图。同路径、同大小不代表内容相同。恢复时也
  重新校验暂存位图指向的数据；位图不能绕过内容检查。
- 默认允许 16 个 chunk 同时在途，调度器根据完成 ACK 持续补充；单 chunk 上限
  受 16 MiB 帧限制。
- 接收端把 chunk 直接写入同卷 staging 文件的目标偏移，不为整个游戏再保留一份
  chunk cache。校验通过且位置不变的文件原位复用；块移位、跨文件复用和全局
  depotcache 清单会实际写入目标 staging 位置。原位文件在提交前再次核对摘要。
- 发送与接收限制打开的文件句柄。新安装一次移动整个已验证的游戏暂存目录；
  更新已有目录时最多并行处理 4 个独立文件，保留计划外文件。全部成功后才写
  Lua 和 ACF，文件失败时保留暂存内容供再次传输。
- staging 状态位图持久化在
  `steamapps/.flsteamlua/incoming/<bundleId>/state.bits`，断线后再次接受同一
  计划只传输缺失块。

## 完成与恢复

- 所有新接收和复用的 chunk 都校验 SHA-1；manifest 文件自身使用 SHA-256 验证。
  文件路径、Windows 保留名、ADS、块引用覆盖范围和摘要在网络/持久化边界校验；
  所选库下面的 junction/symlink 不参与写入或清理。
- 全部 chunk 到齐后，Go 进程检查 Steam 是否运行。Steam 运行时保持
  `waitingForSteamExit`，不会主动关闭 Steam。
- 提交时把 staging 文件移动到目标库，写入 ACF、Lua 和 depot manifest。Lua 的
  启停状态保留，禁用脚本写到 `Disable`。已有
  目标目录中未在本次计划内的 mod、存档和其他文件不会被删除。
- 发送端读取或写入失败会结束连接；接收端 60 秒收不到传输活动时自动标记失败。
- 暂停或取消会中断连接并等待传输工作退出，暂停和断线保留 staging 与块位图。
  已进入文件提交的任务不再提供中途取消。
- 发送任务的计划、对端和状态保存在引擎数据目录。重启后通过 `session.list`
  恢复任务，由发送端继续；接收端再次确认同一计划，只请求缺失块。
- “传输暂存”统计和清理操作访问实际的 `steamapps/.flsteamlua/incoming`。
  活动或暂停任务须先结束/取消再清理，清理后失去断点数据。

## 界面行为

- 局域网传输是独立页面。退出传输详情页不会停止传输。
- 正在进行的传输可以从任务列表重新打开详情，也可以从局域网传输页面的活动
  传输或历史记录进入。
- 失败的发送任务可重试；自动接受、拒绝或超时的请求不再保留在待接收列表。
- 附加文件默认不选择，可在搜索侧栏逐文件选择；列表按可见项构建。附加文件可能
  包含游戏目录内的存档/配置，不能把所有附加文件等同于 mod。
- 网络速度只计算实际传输的块字节；本地复用字节计入文件进度，不计入网速。
- 传输卡片采用封面渐隐、网络柱状与磁盘折线、三项速度和双进度布局，颜色跟随
  应用主题，窄窗口上下排列。磁盘字节取实际写入，安装文件数在成功提交时累计；
  接收端通过 `Progress` 帧回传，发送端显示相同的真实安装状态。

## 验证范围

原生回归覆盖错误内容复用、块重定位、manifest 位置、暂存恢复、接收取消、重启
续传、路径/junction 边界、源计划复用和文件提交。Flutter 定向测试覆盖恢复入口、
邀请清理、附加文件选择及大列表、暂存清理与 IPC 生命周期。

本机 TLS 回环基准用于比较数据通路和文件处理开销，不等于两机网络或 Steam A/B。
尚未以两台真实机器验收 1/2.5 GbE、Steam 重启后的库识别及游戏启动。
