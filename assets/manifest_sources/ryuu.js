// Adapted from Fluent-Steam-Lua (zlib); rewritten for async FlSteamLua host.
// @name Ryuu's Manifests
// @id ryuu
// @provides lua,manifest
// @manifest-types files
// @description 通过 Ryuu's Manifests API 下载 AppID 的 Lua 文件或清单 zip。认证使用站点生成的 X-Auth-Key。
// @author Fluent Steam Lua
// @version 2.0.0
// @homepage https://generator.ryuu.lol/api
// @param authKey type=password label="X-Auth-Key" description="Ryuu 站点个人设置里的 Auth Key" required=true
// @param fileType type=text label="文件类型" description="lua=单个 Lua 文本；zip=清单压缩包（默认）" default="zip"
// @param appid type=number label="AppID" required=true

var API_BASE = "https://generator.ryuu.lol";

async function download(ctx) {
    var requested = ctx.params.requestedCapabilities;
    if (!requested || requested.length === 0) return downloadFile(ctx);
    var wantsLua = requested.indexOf("lua") >= 0;
    var wantsFiles = requested.indexOf("manifestFiles") >= 0;
    if (wantsLua && wantsFiles) {
        var luaParams = Object.assign({}, ctx.params, { fileType: "lua" });
        var lua = await downloadFile(Object.assign({}, ctx, { params: luaParams }));
        if (lua.error) return lua;
        var fileParams = Object.assign({}, ctx.params, { fileType: "zip" });
        var files = await downloadFile(Object.assign({}, ctx, { params: fileParams }));
        if (files.error) return files;
        return { artifacts: [lua, files] };
    }
    var params = Object.assign({}, ctx.params, { fileType: wantsLua ? "lua" : "zip" });
    return downloadFile(Object.assign({}, ctx, { params: params }));
}

async function downloadFile(ctx) {
    var appid = ctx.params.appid;
    var authKey = ctx.params.authKey;
    if (!authKey) {
        return { error: "未配置 X-Auth-Key", errorKind: "missing_key" };
    }

    var wanted = String(ctx.params.fileType || "zip").toLowerCase();
    var isLua = wanted === "lua";
    var fileType = isLua ? "lua" : "manifest";
    var url = API_BASE + "/api/download/" + encodeURIComponent(appid) + "?file_type=" + fileType;

    ctx.log("请求 Ryuu 清单：" + url);
    var res = await ctx.http.get(url, {
        headers: { "X-Auth-Key": authKey, "Accept": isLua ? "text/plain, */*" : "application/zip, application/octet-stream, */*" },
        responseType: isLua ? "text" : "base64",
        timeout: 180,
        allowNonSuccess: true
    });

    if (res.status === 401 || res.status === 403) {
        return { error: "X-Auth-Key 无效或已过期", errorKind: "invalid_key", statusCode: res.status };
    }
    if (res.status === 429) {
        return { error: "Ryuu 请求额度已用完，请稍后再试", errorKind: "quota", statusCode: res.status };
    }
    if (res.status === 404) {
        return { error: "该 AppID 没有可用清单", errorKind: "not_found", statusCode: res.status };
    }
    if (!res.ok) {
        return { error: "Ryuu 返回 HTTP " + res.status + "：" + (res.text || ""), errorKind: "unknown", statusCode: res.status };
    }

    if (isLua) {
        if (!res.text) return { error: "Ryuu 返回了空 Lua", errorKind: "invalid_response", statusCode: res.status };
        return { filename: appid + ".lua", content: res.text, encoding: "text", contentType: "text/plain; charset=utf-8" };
    }

    if (!res.base64) return { error: "Ryuu 返回了空清单包", errorKind: "invalid_response", statusCode: res.status };
    return { filename: appid + ".zip", content: res.base64, encoding: "base64", contentType: res.contentType || "application/zip" };
}

async function test(ctx) {
    if (!ctx.params.authKey) {
        return { ok: false, message: "未配置 X-Auth-Key", errorKind: "missing_key" };
    }

    // Ryuu 没有独立的状态接口；用 Range 只取 1 字节探测下载端点，401/403 即 Key 无效。
    var res = await ctx.http.get(API_BASE + "/api/download/440?file_type=lua", {
        headers: { "X-Auth-Key": ctx.params.authKey, "Range": "bytes=0-0" },
        responseType: "text",
        timeout: 30,
        allowNonSuccess: true
    });

    if (res.status === 401 || res.status === 403) {
        return { ok: false, message: "X-Auth-Key 无效或已过期", errorKind: "invalid_key", statusCode: res.status };
    }
    if (res.status === 429) {
        return { ok: false, message: "请求过于频繁，请稍后再试", errorKind: "quota", statusCode: res.status };
    }
    if (res.status === 404) {
        return { ok: true, message: "Key 有效（测试游戏暂无可下载清单）" };
    }
    if (res.status >= 500) {
        return { ok: false, message: "Ryuu 服务端错误 HTTP " + res.status, errorKind: "network", statusCode: res.status };
    }
    return { ok: true, message: "X-Auth-Key 有效" };
}
