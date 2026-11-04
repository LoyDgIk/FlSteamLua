# WebDAV Windows authentication

The WebDAV provider accepts `basic`, `auto`, `digest`, `ntlm`, `negotiate`,
`bearer`, and `none`. The existing portable HTTP transport handles Basic,
Digest, Bearer, and unauthenticated requests. For NTLM/Negotiate, Dart calls the
Windows system `winhttp.dll` through FFI inside a worker isolate. No .NET runtime,
C# process, third-party authentication DLL, or global certificate configuration
is used.

NTLM and Negotiate use the username/password entered in the provider settings.
The username can be `DOMAIN\username` or `username@domain`. Ambient Windows
credentials are not sent automatically. `auto` recognizes an NTLM/Negotiate
challenge and hands that request to the Windows transport. Explicit
`Authorization` headers remain authoritative.

The initial native request disables WinHTTP automatic authentication, including
for loopback/IP endpoints where the high automatic-logon policy alone is not
effective. A caller-provided `Authorization` header keeps automatic
authentication disabled for the entire request. After an unauthenticated 401
probe, the provider reads the real `WWW-Authenticate` response header, verifies
the offered scheme, creates a new request, and sets
the configured non-null username/password before allowing WinHTTP to perform its
connection-bound handshake. A server which does not offer the selected
authentication scheme produces an HTTP 401 result instead of falling back to
another scheme.
Redirects are returned as HTTP errors rather than forwarding credentials to
another endpoint. Win32 transport errors include their real numeric error code.

`allow_insecure_tls` is preserved in the CloudRedirect credential JSON and can be
enabled explicitly in the WebDAV settings for a trusted self-hosted endpoint.
It defaults to false. When enabled, the Windows transport skips the server
certificate's CA, name, validity, and usage checks for that provider's requests;
it does not change Windows trust stores. Plain HTTP independently requires
`allow_insecure_http`.

Tests include injectable transport contracts and local HTTP fixtures exercising
the real WinHTTP FFI for DAV methods, binary bodies, response headers, rejection
of an incompatible challenge, explicit-header priority under a real NTLM
challenge, absence of ambient credentials on loopback, and redirect handling.
These fixtures do not
constitute an NTLM domain/server or Kerberos end-to-end test. A real configured
NTLM/Negotiate WebDAV account remains necessary for that acceptance check.

## Primary API references

- [Authentication in WinHTTP](https://learn.microsoft.com/en-us/windows/win32/winhttp/authentication-in-winhttp)
- [WinHttpSetCredentials](https://learn.microsoft.com/en-us/windows/win32/api/winhttp/nf-winhttp-winhttpsetcredentials)
- [WinHTTP option flags](https://learn.microsoft.com/en-us/windows/win32/winhttp/option-flags)
- Windows SDK 10.0.26100.0 `um/winhttp.h` for the shipped x64 ABI and constants.
