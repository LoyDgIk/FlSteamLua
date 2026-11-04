# 局域网游戏传输

FlSteamLua 的局域网传输由独立 Go 进程 `lan_transfer_engine.exe` 完成。Flutter
只负责页面、设备确认、目标库选择和状态展示；发现、TLS、manifest 解析、chunk
调度、缓存索引、断点恢复和最终安装均不经过 Dart 数据通道。

该协议是 FlSteamLua 自有的高性能协议，不尝试冒充或兼容 Steam 客户端私有的
局域网内容协议。

## 进程与 IPC

- `lan_transfer_engine.exe` 使用 Windows x64 构建，单实例运行，随主程序启动和
  退出。
- Flutter 通过继承的 stdin/stdout 发送逐行 JSON-RPC；响应携带相同 `id`。
- 异步事件使用 `event/data`，日志只写 stderr。
- Dart 命令包括 `hello`、`configure`、`discovery.start`、`discovery.stop`、
  `peer.probe`、`plan.prepare`、`plan.discard`、`send.start`、
  `offer.accept`、`offer.reject`、`session.pause`、`session.resume`、
  `session.cancel`、`trust.set`、`cache.stats`、`cache.clear` 和 `shutdown`。
- Dart 不保存完整 chunk 列表。计划以 `planId` 留在 Go 引擎中，界面只接收文件
  分类、大小、数量和可选附件摘要。

## 发现与身份

- UDP 发现使用 `239.255.42.99:47821`，同时支持广播和手动 IP。
- TCP 传输使用 `47821`，协议版本为 `flsteamlua-lan/4`。
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

控制消息使用 Protobuf wire format，chunk payload 保留原始字节。协议支持
Hello、Offer、Decision、Plan、PlanReady、ChunkData、ChunkAck、Credit、
Finish、Cancel 和 Error。

初始 offer 只包含 AppID、游戏名、总大小、文件/chunk 数量和警告，不包含几十
万个 chunk。接收端接受后才在同一 TLS 连接内传输完整计划和缺失块位图。

## 计划与 chunk

- Go 引擎直接解析 VDF/ACF、Lua 和 Steam `depotcache/*.manifest`。
- manifest 文件名加密时，通过 Windows DPAPI 解出 key cache 后使用 AES-256
  解密文件名。
- 官方文件使用 manifest 中的文件大小和 chunk SHA-1；manifest 之外的附加文件
  使用 4 MiB 固定分块。
- 接收端先返回已有 chunk 位图。已有内容直接来自目标库当前安装文件，缺失块才
  进入网络传输。
- 默认允许 16 个 chunk 同时在途，调度器根据完成 ACK 持续补充；单 chunk 上限
  受 16 MiB 帧限制。
- 接收端把 chunk 直接写入同卷 staging 文件的目标偏移，不为整个游戏再保留一份
  chunk cache。已有文件只在出现缺失块时复制到 staging，避免更新时复制全部
  150 GB 内容。
- staging 状态位图持久化在
  `steamapps/.flsteamlua/incoming/<bundleId>/state.bits`，断线后再次接受同一
  计划只传输缺失块。

## 完成与恢复

- 官方 chunk 使用 manifest SHA-1 验证；manifest 文件自身使用 SHA-256 验证。
- 全部 chunk 到齐后，Go 进程检查 Steam 是否运行。Steam 运行时保持
  `waitingForSteamExit`，不会主动关闭 Steam。
- 提交时把 staging 文件移动到目标库，写入 ACF、Lua 和 depot manifest；已有
  目标目录中未在本次计划内的 mod、存档和其他文件不会被删除。
- 发送端失败会向接收端发送取消；接收端 60 秒收不到传输活动时自动标记失败。
- 暂停或断线保留 staging 和块位图；恢复时重新确认同一计划，只请求缺失块。

## 界面行为

- 局域网传输是独立页面。退出传输详情页不会停止传输。
- 正在进行的传输可以从任务列表重新打开详情，也可以从局域网传输页面的活动
  传输或历史记录进入。
