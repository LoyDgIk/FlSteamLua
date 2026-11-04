# Manifest source scripts

Bundled sources are adapted from Fluent-Steam-Lua under its zlib license and use the new asynchronous FlSteamLua host. Previous synchronous scripts are not supported.

Each script declares an ID, display name and editable parameters in `// @` metadata. Place additional scripts in `%LOCALAPPDATA%\FlSteamLua\data\manifest-scripts` or import them from the source settings page. IDs must be unique.

```javascript
// @id my-source
// @name My source
// @version 2.0.0
// @param token type=password label="Access token" required=true

async function download(ctx) {
  const response = await ctx.http.get('https://example.org/' + ctx.params.appid, {
    headers: {Authorization: 'Bearer ' + ctx.params.token},
    responseType: 'base64'
  });
  return {
    filename: ctx.params.appid + '.zip',
    encoding: 'base64',
    content: response.base64,
    contentType: response.contentType
  };
}

async function test(ctx) {
  const response = await ctx.http.get('https://example.org/status');
  return {ok: response.ok, message: response.ok ? 'Connected' : 'Connection failed'};
}
```

- `ctx.params`: parsed source settings plus the requested numeric `appid` during downloads.
- `ctx.log(message)`: appends a task log, with configured secret values redacted by the host.
- `ctx.http.get(url, options)` and `ctx.http.post(url, options)`: return Promises. HTTP/HTTPS only; the host performs all network access.
- HTTP options: string `headers`, `responseType` (`text`, `json`, `base64`), `timeout` in seconds, `allowNonSuccess`, `maxBytes`; POST also accepts `body` and `contentType`.
- Responses contain `status`, `ok`, `contentType`, `headers`, `url`, and `text`, plus `data` for JSON or `base64` for binary responses.
- Downloads return `filename`, `content`, `encoding` (`text` or `base64`), and optional `contentType`; failures return `{error, errorKind, statusCode}`. Files must use `.lua`, `.bin`, `.manifest`, `.zip`, `.7z` or `.rar` names without directories.
- A source that resolves kernel manifest request codes declares `// @provides manifest` with `// @manifest-types codes` and may return `manifestRequestCodes: [{depotId, manifestId, requestCode}]`. This is the same content-source system used by the kernel local proxy; all IDs are decimal strings.
- Optional `test(ctx)` returns `{ok, message, errorKind?, statusCode?}`. A source without `test` is not reported as connection-tested.

QuickJS runs in a separate Dart isolate with a bounded JS heap and execution limit. Scripts receive no filesystem bridge. Source password fields are stored with current-user Windows DPAPI rather than in the public source settings JSON.
