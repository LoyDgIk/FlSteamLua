// Adapted from Fluent-Steam-Lua (zlib); rewritten for async FlSteamLua host.
// @name ManifestHub2
// @id manifesthub2
// @provides manifest
// @manifest-types files
// @description ManifestHub2 清单 API（apikey 查询参数）。支持按 depotid+manifestid 下载单个 .manifest；若服务端支持 appid 打包，也可直接按 AppID 下载 zip。
// @author Fluent Steam Lua
// @version 2.0.0
// @homepage https://manifesthub2.filegear-sg.me
// @param apikey type=password label="API Key" description="ManifestHub2 网站生成的 API Key（免费 Key 24 小时有效）" required=true
// @param depotid type=number label="Depot ID（可选）" description="填写后按单个 depot 清单下载" required=false
// @param manifestid type=text label="Manifest ID（可选）" description="与 Depot ID 配套使用" required=false
// @param appid type=number label="AppID" required=true

var API_BASE = "https://api.manifesthub2.filegear-sg.me";

async function download(ctx) {
    var apikey = ctx.params.apikey;
    var appid = ctx.params.appid;
    if (!apikey) {
        return { error: "未配置 API Key", errorKind: "missing_key" };
    }

    var depotid = ctx.params.depotid;
    var manifestid = ctx.params.manifestid;
    var url = API_BASE + "/manifest?apikey=" + encodeURIComponent(apikey);

    if (depotid && manifestid) {
        url += "&depotid=" + encodeURIComponent(depotid) + "&manifestid=" + encodeURIComponent(manifestid);
    } else {
        // ManifestHub2 文档接口是 depot 级；部分兼容服务端支持按 appid 返回打包结果。
        url += "&appid=" + encodeURIComponent(appid);
    }

    ctx.log("请求 ManifestHub2 清单：" + url);
    var res = await ctx.http.get(url, {
        headers: { "Accept": "application/octet-stream, application/zip, */*" },
        responseType: "base64",
        timeout: 180,
        allowNonSuccess: true
    });

    if (res.status === 401 || res.status === 403) {
        return { error: "API Key 无效或已过期", errorKind: "invalid_key", statusCode: res.status };
    }
    if (res.status === 429) {
        return { error: "ManifestHub2 请求过于频繁（含 Cloudflare 限流），请稍后再试", errorKind: "quota", statusCode: res.status };
    }
    if (res.status === 404 || res.status === 400) {
        if (!depotid || !manifestid) {
            return {
                error: "ManifestHub2 文档接口需要 Depot ID + Manifest ID；请在参数里补全后重试",
                errorKind: "not_configured",
                statusCode: res.status
            };
        }
        return { error: "该 Depot/Manifest 没有可用清单", errorKind: "not_found", statusCode: res.status };
    }
    if (!res.ok) {
        return { error: "ManifestHub2 返回 HTTP " + res.status + "：" + (res.text || ""), errorKind: "unknown", statusCode: res.status };
    }
    if (!res.base64) {
        return { error: "ManifestHub2 返回了空内容", errorKind: "invalid_response", statusCode: res.status };
    }

    var filename = (depotid && manifestid) ? (depotid + "_" + manifestid + ".manifest") : (appid + ".zip");
    return {
        filename: filename,
        content: res.base64,
        encoding: "base64",
        contentType: res.contentType || "application/octet-stream"
    };
}

async function test(ctx) {
    if (!ctx.params.apikey) {
        return { ok: false, message: "未配置 API Key", errorKind: "missing_key" };
    }

    // 用 1/1 做鉴权探测：401/403 表示 Key 无效；400/404 表示 Key 已被接受但没有该清单。
    var res = await ctx.http.get(API_BASE + "/manifest?apikey=" + encodeURIComponent(ctx.params.apikey) + "&depotid=1&manifestid=1", {
        headers: { "Accept": "application/octet-stream, application/json, */*" },
        responseType: "text",
        timeout: 30,
        allowNonSuccess: true
    });

    if (res.status === 401 || res.status === 403) {
        return { ok: false, message: "API Key 无效或已过期", errorKind: "invalid_key", statusCode: res.status };
    }
    if (res.status === 429) {
        return { ok: false, message: "请求过于频繁（含 Cloudflare 限流），请稍后再试", errorKind: "quota", statusCode: res.status };
    }
    if (res.status === 400 || res.status === 404) {
        return { ok: true, message: "API Key 有效（测试清单不存在）" };
    }
    if (!res.ok) {
        return { ok: false, message: "ManifestHub2 返回 HTTP " + res.status, errorKind: res.status >= 500 ? "network" : "unknown", statusCode: res.status };
    }
    return { ok: true, message: "API Key 有效" };
}
