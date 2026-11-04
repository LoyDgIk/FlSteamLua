// Adapted from Fluent-Steam-Lua (zlib); rewritten for async FlSteamLua host.
// @name LuaTools
// @id luatools
// @provides lua,manifest
// @manifest-types files
// @description 通过 lua.tools 的清单接口下载 AppID 对应的清单压缩包（lua + manifest）。使用 Discord OAuth 登录 lua.tools 后取得的 Bearer Token。
// @author Fluent Steam Lua
// @version 2.0.0
// @homepage https://lua.tools
// @param token type=password label="Bearer Token" description="lua.tools 登录后的访问令牌（Discord OAuth），由外部配置提供" required=true
// @param source type=text label="清单源" description="可选：Ryuu / Sushi / Skyflare / TwentyTwo Cloud / Sadie (Morrenus)" default="Ryuu"
// @param gameName type=text label="游戏名（可选）" description="仅用于服务端记录，可留空" required=false
// @param appid type=number label="AppID" required=true

var API_BASE = "https://lua.tools";

async function download(ctx) {
    var appid = ctx.params.appid;
    var token = ctx.params.token;
    var source = ctx.params.source || "Ryuu";
    if (!token) {
        return { error: "未配置 Bearer Token", errorKind: "missing_key" };
    }

    var url = API_BASE + "/api/manifest/download?appid=" + encodeURIComponent(appid) +
              "&source=" + encodeURIComponent(source);
    if (ctx.params.gameName) {
        url += "&game_name=" + encodeURIComponent(ctx.params.gameName);
    }

    ctx.log("请求 lua.tools 清单：" + url);
    var res = await ctx.http.get(url, {
        headers: { "Authorization": "Bearer " + token, "Accept": "application/zip, application/octet-stream, */*" },
        responseType: "base64",
        timeout: 180,
        allowNonSuccess: true
    });

    if (res.status === 401 || res.status === 403) {
        return { error: "Bearer Token 无效或已过期，请重新获取", errorKind: "invalid_key", statusCode: res.status };
    }
    if (res.status === 429) {
        return { error: "lua.tools 下载额度已用完，请稍后再试", errorKind: "quota", statusCode: res.status };
    }
    if (res.status === 404) {
        return { error: "该 AppID 没有可用清单", errorKind: "not_found", statusCode: res.status };
    }
    if (!res.ok) {
        return { error: "lua.tools 返回 HTTP " + res.status + "：" + (res.text || ""), errorKind: "unknown", statusCode: res.status };
    }
    if (!res.base64) {
        return { error: "lua.tools 返回了空内容", errorKind: "invalid_response", statusCode: res.status };
    }

    return {
        filename: appid + ".zip",
        content: res.base64,
        encoding: "base64",
        contentType: res.contentType || "application/zip"
    };
}

async function test(ctx) {
    if (!ctx.params.token) {
        return { ok: false, message: "未配置 Bearer Token", errorKind: "missing_key" };
    }

    var res = await ctx.http.get(API_BASE + "/api/me/supporter-status", {
        headers: { "Authorization": "Bearer " + ctx.params.token, "Accept": "application/json" },
        responseType: "json",
        timeout: 30,
        allowNonSuccess: true
    });

    if (res.status === 401 || res.status === 403) {
        return { ok: false, message: "Bearer Token 无效或已过期", errorKind: "invalid_key", statusCode: res.status };
    }
    if (res.status === 429) {
        return { ok: false, message: "请求过于频繁，请稍后再试", errorKind: "quota", statusCode: res.status };
    }
    if (res.status === 404) {
        return { ok: true, message: "Token 已通过（服务端未提供状态接口）" };
    }
    if (!res.ok) {
        return { ok: false, message: "lua.tools 返回 HTTP " + res.status, errorKind: res.status >= 500 ? "network" : "unknown", statusCode: res.status };
    }
    return { ok: true, message: "Bearer Token 有效" };
}
