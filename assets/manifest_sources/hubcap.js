// Adapted from Fluent-Steam-Lua (zlib); rewritten for async FlSteamLua host.
// @name Hubcap
// @id hubcap
// @provides lua,manifest
// @manifest-types files
// @description 通过 HubcapDB 的 v1 API 下载 AppID 的 Lua 或清单 zip。认证使用网站生成的 API Key（Authorization: Bearer）。
// @author Fluent Steam Lua
// @version 2.0.0
// @homepage https://hubcapmanifest.com
// @param apiKey type=password label="API Key" description="HubcapDB 账户页生成的 Key；请求头 Authorization: Bearer <key>" required=true
// @param fileType type=text label="文件类型" description="lua=单个 Lua 文本；zip=清单压缩包（默认）" default="zip"
// @param appid type=number label="AppID" required=true

var API_BASE = "https://hubcapmanifest.com";

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
    var apiKey = ctx.params.apiKey;
    if (!apiKey) {
        return { error: "未配置 API Key", errorKind: "missing_key" };
    }

    var wanted = String(ctx.params.fileType || "zip").toLowerCase();
    var isLua = wanted === "lua";
    var url = API_BASE + (isLua ? "/api/v1/lua/" : "/api/v1/manifest/") + encodeURIComponent(appid);

    ctx.log("请求 Hubcap 清单：" + url);
    var res = await ctx.http.get(url, {
        headers: {
            "Authorization": "Bearer " + apiKey,
            "X-API-Key": apiKey,
            "Accept": isLua ? "text/plain, */*" : "application/zip, application/octet-stream, */*"
        },
        responseType: isLua ? "text" : "base64",
        timeout: 180,
        allowNonSuccess: true
    });

    if (res.status === 401 || res.status === 403) {
        return { error: "API Key 无效或已过期，请重新生成", errorKind: "invalid_key", statusCode: res.status };
    }
    if (res.status === 429) {
        return { error: "Hubcap 今日下载额度已用完", errorKind: "quota", statusCode: res.status };
    }
    if (res.status === 404) {
        return { error: "该 AppID 没有可用清单", errorKind: "not_found", statusCode: res.status };
    }
    if (!res.ok) {
        return { error: "Hubcap 返回 HTTP " + res.status + "：" + (res.text || ""), errorKind: "unknown", statusCode: res.status };
    }

    if (isLua) {
        if (!res.text) return { error: "Hubcap 返回了空 Lua", errorKind: "invalid_response", statusCode: res.status };
        return { filename: appid + ".lua", content: res.text, encoding: "text", contentType: "text/plain; charset=utf-8" };
    }

    if (!res.base64) {
        return { error: "Hubcap 返回了空清单包", errorKind: "invalid_response", statusCode: res.status };
    }
    return {
        filename: appid + ".zip",
        content: res.base64,
        encoding: "base64",
        contentType: res.contentType || "application/zip"
    };
}

async function test(ctx) {
    if (!ctx.params.apiKey) {
        return { ok: false, message: "未配置 API Key", errorKind: "missing_key" };
    }

    var res = await ctx.http.get(API_BASE + "/api/v1/status/440", {
        headers: { "Authorization": "Bearer " + ctx.params.apiKey, "Accept": "application/json" },
        responseType: "json",
        timeout: 30,
        allowNonSuccess: true
    });

    if (res.status === 401 || res.status === 403) {
        return { ok: false, message: "API Key 无效或已过期", errorKind: "invalid_key", statusCode: res.status };
    }
    if (res.status === 429) {
        return { ok: false, message: "请求过于频繁，请稍后再试", errorKind: "quota", statusCode: res.status };
    }
    if (res.status === 404) {
        return { ok: true, message: "Key 有效（测试游戏暂无状态数据）" };
    }
    if (!res.ok) {
        return { ok: false, message: "Hubcap 返回 HTTP " + res.status, errorKind: res.status >= 500 ? "network" : "unknown", statusCode: res.status };
    }
    return { ok: true, message: "API Key 有效" };
}
