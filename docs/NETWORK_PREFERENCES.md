# 网络与下载来源

封面来源和 GitHub 公开下载来源分别设置，默认保持原图片地址和 GitHub 直连。
设置保存在新应用自己的 `settings.json`：`coverCdn`、`githubMirror`。

## 封面

提供 Steam 商店接口、小黑盒接口、Akamai 主/备用节点、Cloudflare 和
Akamai 竖版大图。这些是原项目 `CdnEndpoint.cs` 中的来源；列表存在不代表
当前网络可达。界面中的测速实际请求每个来源，展示本次延迟和错误，
不会根据测试结果自动改偏好。

主页、库、商店和详情通过 `NetworkCoverImage` 在显示时应用设置，保留原图片
作为失败回退。商店的业务对象仍保留其接口返回的图片地址；图片来源的额外
解析不会阻塞商店搜索结果。工具的封面下载也使用所选来源。

## GitHub 公开下载

`NetworkHttpClient` 在明确选择镜像后才改变下载地址。镜像候选来自原项目
`GitHubMirror.cs`：`gh-proxy.com`、`ghfast.top`、`gh-proxy.org`。
仅匿名 HTTPS GET/HEAD 的 GitHub release 文件和 raw 文件可经镜像处理。
查询参数、用户信息、Authorization、Cookie、未知自定义请求头、其他端口、
POST 和 GitHub API 均保持直连。镜像请求失败后回到原公开地址。

内核下载和清单脚本 HTTP 宿主在默认客户端上应用这项设置。注入的测试或
专用客户端不被替换。镜像不会处理 Steam 登录、应用接口或云端凭证请求。

## 验证边界

`test/network` 包含来源解析、镜像选择、失败回退、敏感请求直连和页面测试。
这些是隔离 fixture，不是上述第三方服务的持续在线保证。
真实测速只有用户在设置中点击测试时才执行。
