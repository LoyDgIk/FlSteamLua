/*
 * Altered C++ implementation for FlSteamLua. Steam client interface layouts are
 * derived from SteamAchievementManager (Copyright (c) 2024 Rick) and the local
 * Fluent-Steam-Lua native ticket integration. Original notices are in LICENSES.
 */
#define STEAM_BRIDGE_IMPLEMENTATION
#include "steam_bridge.h"
#include <windows.h>
#include <cstring>
#include <filesystem>
#include <memory>
#include <string>

namespace {
thread_local std::string open_error;
uint32_t process_app_id = 0;
bool session_active = false;

struct CallbackMessage {
  int user;
  int id;
  void* data;
  int size;
};

using CreateInterface = void* (__cdecl*)(const char*, int*);
using GetCallback = bool (__cdecl*)(int, CallbackMessage*, uint64_t*);
using FreeCallback = bool (__cdecl*)(int);

struct Session {
  HMODULE module = nullptr;
  void* client = nullptr;
  void* stats = nullptr;
  void* user_legacy = nullptr;
  void* user = nullptr;
  void* utils = nullptr;
  void* ticket = nullptr;
  int pipe = 0;
  int user_handle = 0;
  uint32_t app_id = 0;
  GetCallback get_callback = nullptr;
  FreeCallback free_callback = nullptr;
  int stats_result = 0;
  int store_result = 0;
  std::string error;
};

template<typename T> T slot(void* object, size_t index) {
  return reinterpret_cast<T>((*reinterpret_cast<void***>(object))[index]);
}

void fail(Session* s, const std::string& error) {
  if (s) s->error = error;
  else open_error = error;
}

bool available(Session* s) {
  if (!s || !s->stats) { fail(s, "Steam session is not connected"); return false; }
  return true;
}

void dispose(Session* s) {
  if (!s) return;
  if (s->client && s->pipe) {
    if (s->user_handle) {
      using Fn = void (__fastcall*)(void*, int, int);
      slot<Fn>(s->client, 4)(s->client, s->pipe, s->user_handle);
    }
    using Fn = bool (__fastcall*)(void*, int);
    slot<Fn>(s->client, 1)(s->client, s->pipe);
  }
  if (s->module) FreeLibrary(s->module);
}

template<typename T> T read(const void* data, size_t offset) {
  T value{};
  std::memcpy(&value, static_cast<const unsigned char*>(data) + offset, sizeof(T));
  return value;
}
}

void* sb_open(const wchar_t* steam_path, uint32_t app_id) {
  open_error.clear();
  if (!steam_path || !*steam_path || app_id == 0) {
    fail(nullptr, "A Steam installation path and a nonzero AppID are required");
    return nullptr;
  }
  if (session_active || (process_app_id && process_app_id != app_id)) {
    fail(nullptr, "Each AppID requires its own worker process");
    return nullptr;
  }
  std::filesystem::path root(steam_path);
  std::error_code path_error;
  auto dll = root / L"steamclient64.dll";
  if (!std::filesystem::is_regular_file(dll, path_error)) dll = root / L"bin" / L"steamclient64.dll";
  path_error.clear();
  if (!std::filesystem::is_regular_file(dll, path_error)) {
    fail(nullptr, "steamclient64.dll was not found in the Steam installation");
    return nullptr;
  }
  const auto app = std::to_wstring(app_id);
  SetEnvironmentVariableW(L"SteamAppId", app.c_str());
  SetEnvironmentVariableW(L"SteamGameId", app.c_str());
  auto s = std::make_unique<Session>();
  s->app_id = app_id;
  s->module = LoadLibraryExW(dll.c_str(), nullptr, LOAD_WITH_ALTERED_SEARCH_PATH);
  if (!s->module) {
    fail(nullptr, "Loading steamclient64.dll failed (Win32 " + std::to_string(GetLastError()) + ")");
    return nullptr;
  }
  process_app_id = app_id;
  const auto create = reinterpret_cast<CreateInterface>(GetProcAddress(s->module, "CreateInterface"));
  s->get_callback = reinterpret_cast<GetCallback>(GetProcAddress(s->module, "Steam_BGetCallback"));
  s->free_callback = reinterpret_cast<FreeCallback>(GetProcAddress(s->module, "Steam_FreeLastCallback"));
  if (!create || !s->get_callback || !s->free_callback) {
    fail(nullptr, "Steam client callback exports are unavailable"); dispose(s.get()); return nullptr;
  }
  s->client = create("SteamClient023", nullptr);
  if (!s->client) s->client = create("SteamClient018", nullptr);
  if (!s->client) { fail(nullptr, "Steam client interface is unavailable"); dispose(s.get()); return nullptr; }
  using NewPipe = int (__fastcall*)(void*);
  s->pipe = slot<NewPipe>(s->client, 0)(s->client);
  if (!s->pipe) { fail(nullptr, "Cannot create a Steam pipe; start Steam first"); dispose(s.get()); return nullptr; }
  using Connect = int (__fastcall*)(void*, int);
  s->user_handle = slot<Connect>(s->client, 2)(s->client, s->pipe);
  if (!s->user_handle) { fail(nullptr, "No signed-in Steam user is available"); dispose(s.get()); return nullptr; }
  using UserInterface = void* (__fastcall*)(void*, int, int, const char*);
  using UtilsInterface = void* (__fastcall*)(void*, int, const char*);
  s->stats = slot<UserInterface>(s->client, 13)(s->client, s->user_handle, s->pipe, "STEAMUSERSTATS_INTERFACE_VERSION013");
  s->user_legacy = slot<UserInterface>(s->client, 5)(s->client, s->user_handle, s->pipe, "SteamUser012");
  s->user = slot<UserInterface>(s->client, 5)(s->client, s->user_handle, s->pipe, "SteamUser023");
  s->utils = slot<UtilsInterface>(s->client, 9)(s->client, s->pipe, "SteamUtils010");
  s->ticket = slot<UserInterface>(s->client, 12)(s->client, s->user_handle, s->pipe, "STEAMAPPTICKET_INTERFACE_VERSION001");
  if (!s->stats || !s->user_legacy || !s->utils) {
    fail(nullptr, "Required Steam user/stats interfaces are unavailable"); dispose(s.get()); return nullptr;
  }
  using GetAppId = uint32_t (__fastcall*)(void*);
  if (slot<GetAppId>(s->utils, 9)(s->utils) != app_id) {
    fail(nullptr, "Steam AppID context does not match this worker"); dispose(s.get()); return nullptr;
  }
  session_active = true;
  return s.release();
}

void sb_close(void* handle) {
  auto s = static_cast<Session*>(handle);
  if (!s) return;
  dispose(s);
  delete s;
  session_active = false;
}

const char* sb_error(void* handle) {
  auto s = static_cast<Session*>(handle);
  return s ? s->error.c_str() : open_error.c_str();
}

void sb_pump(void* handle) {
  auto s = static_cast<Session*>(handle);
  if (!s || !s->get_callback) return;
  CallbackMessage message{};
  uint64_t call = 0;
  while (s->get_callback(s->pipe, &message, &call)) {
    if (message.data && message.size >= 12 && read<uint64_t>(message.data, 0) == s->app_id) {
      const int result = read<int32_t>(message.data, 8);
      if (message.id == 1101) {
        s->stats_result = result == 1 ? 1 : -1;
        if (result != 1) fail(s, "Steam stats request failed (EResult " + std::to_string(result) + ")");
      } else if (message.id == 1102) {
        s->store_result = result == 1 ? 1 : -1;
        if (result != 1) fail(s, "Steam did not save stats (EResult " + std::to_string(result) + ")");
      }
    }
    s->free_callback(s->pipe);
  }
}

int sb_request_stats(void* handle) {
  auto s = static_cast<Session*>(handle);
  if (!available(s)) return 0;
  sb_pump(s);
  s->stats_result = 0;
  uint64_t steam_id = 0;
  // SteamUser012 returns its CSteamID through the hidden return pointer on x64.
  using GetSteamId = void (__fastcall*)(void*, uint64_t*);
  slot<GetSteamId>(s->user_legacy, 2)(s->user_legacy, &steam_id);
  using Request = uint64_t (__fastcall*)(void*, uint64_t);
  if (!steam_id || !slot<Request>(s->stats, 15)(s->stats, steam_id)) {
    fail(s, "Steam rejected the user stats request"); s->stats_result = -1; return 0;
  }
  return 1;
}

int sb_stats_ready(void* handle) { auto s = static_cast<Session*>(handle); return s ? s->stats_result : -1; }
int sb_store_result(void* handle) { auto s = static_cast<Session*>(handle); return s ? s->store_result : -1; }

uint32_t sb_achievement_count(void* handle) {
  auto s = static_cast<Session*>(handle);
  if (!available(s)) return 0;
  using Fn = uint32_t (__fastcall*)(void*);
  return slot<Fn>(s->stats, 13)(s->stats);
}

const char* sb_achievement_name(void* handle, uint32_t index) {
  auto s = static_cast<Session*>(handle);
  if (!available(s) || index >= sb_achievement_count(handle)) return nullptr;
  using Fn = const char* (__fastcall*)(void*, uint32_t);
  return slot<Fn>(s->stats, 14)(s->stats, index);
}

const char* sb_achievement_attribute(void* handle, const char* id, const char* key) {
  auto s = static_cast<Session*>(handle);
  if (!available(s) || !id || !key) return nullptr;
  using Fn = const char* (__fastcall*)(void*, const char*, const char*);
  return slot<Fn>(s->stats, 11)(s->stats, id, key);
}

int sb_achievement_state(void* handle, const char* id, uint8_t* achieved, uint32_t* time) {
  auto s = static_cast<Session*>(handle);
  if (!available(s) || !id || !achieved || !time) return 0;
  bool value = false;
  using Fn = bool (__fastcall*)(void*, const char*, bool*, uint32_t*);
  if (!slot<Fn>(s->stats, 8)(s->stats, id, &value, time)) { fail(s, "Cannot read achievement"); return 0; }
  *achieved = value ? 1 : 0;
  return 1;
}

int sb_set_achievement(void* handle, const char* id, int achieved) {
  auto s = static_cast<Session*>(handle);
  if (!available(s) || !id) return 0;
  using Fn = bool (__fastcall*)(void*, const char*);
  const bool ok = slot<Fn>(s->stats, achieved ? 6 : 7)(s->stats, id);
  if (!ok) fail(s, "Steam rejected achievement change");
  return ok ? 1 : 0;
}

int sb_get_stat_int(void* handle, const char* id, int32_t* value) {
  auto s = static_cast<Session*>(handle);
  if (!available(s) || !id || !value) return 0;
  using Fn = bool (__fastcall*)(void*, const char*, int32_t*);
  return slot<Fn>(s->stats, 1)(s->stats, id, value) ? 1 : 0;
}
int sb_get_stat_float(void* handle, const char* id, float* value) {
  auto s = static_cast<Session*>(handle);
  if (!available(s) || !id || !value) return 0;
  using Fn = bool (__fastcall*)(void*, const char*, float*);
  return slot<Fn>(s->stats, 0)(s->stats, id, value) ? 1 : 0;
}
int sb_set_stat_int(void* handle, const char* id, int32_t value) {
  auto s = static_cast<Session*>(handle);
  if (!available(s) || !id) return 0;
  using Fn = bool (__fastcall*)(void*, const char*, int32_t);
  const bool ok = slot<Fn>(s->stats, 3)(s->stats, id, value);
  if (!ok) fail(s, "Steam rejected integer statistic change");
  return ok ? 1 : 0;
}
int sb_set_stat_float(void* handle, const char* id, float value) {
  auto s = static_cast<Session*>(handle);
  if (!available(s) || !id) return 0;
  using Fn = bool (__fastcall*)(void*, const char*, float);
  const bool ok = slot<Fn>(s->stats, 2)(s->stats, id, value);
  if (!ok) fail(s, "Steam rejected float statistic change");
  return ok ? 1 : 0;
}

int sb_store_stats(void* handle) {
  auto s = static_cast<Session*>(handle);
  if (!available(s)) return 0;
  sb_pump(s);
  s->store_result = 0;
  using Fn = bool (__fastcall*)(void*);
  if (!slot<Fn>(s->stats, 9)(s->stats)) { fail(s, "Steam rejected StoreStats"); s->store_result = -1; return 0; }
  return 1;
}

int sb_app_ticket(void* handle, uint8_t* output, uint32_t capacity, uint64_t* steam_id) {
  auto s = static_cast<Session*>(handle);
  if (!s || !s->ticket || !output || !capacity) { fail(s, "AppTicket interface or buffer is unavailable"); return -1; }
  using Fn = uint32_t (__fastcall*)(void*, uint32_t, void*, uint32_t, uint32_t*, uint32_t*, uint32_t*, uint32_t*);
  uint32_t app_offset=0, steam_offset=0, signature_offset=0, signature_size=0;
  const uint32_t size = slot<Fn>(s->ticket, 0)(s->ticket, s->app_id, output, capacity,
      &app_offset, &steam_offset, &signature_offset, &signature_size);
  if (!size || size > capacity) { fail(s, "Steam returned no ownership ticket for this AppID"); return -1; }
  if (steam_id) *steam_id = steam_offset <= size && size - steam_offset >= 8 ? read<uint64_t>(output, steam_offset) : 0;
  return static_cast<int>(size);
}

uint64_t sb_request_encrypted_ticket(void* handle) {
  auto s = static_cast<Session*>(handle);
  if (!s || !s->user) { fail(s, "SteamUser023 interface is unavailable"); return 0; }
  using Fn = uint64_t (__fastcall*)(void*, void*, int);
  const auto call = slot<Fn>(s->user, 21)(s->user, nullptr, 0);
  if (!call) fail(s, "Steam rejected encrypted ticket request");
  return call;
}

int sb_encrypted_ticket(void* handle, uint64_t call, uint8_t* output, uint32_t capacity) {
  auto s = static_cast<Session*>(handle);
  if (!s || !s->user || !s->utils || !call || !output || !capacity) {
    fail(s, "Encrypted ticket request or buffer is invalid"); return -1;
  }
  using Complete = bool (__fastcall*)(void*, uint64_t, bool*);
  bool failed = false;
  if (!slot<Complete>(s->utils, 11)(s->utils, call, &failed)) return 0;
  if (failed) { fail(s, "Encrypted ticket API call failed"); return -1; }
  using Result = bool (__fastcall*)(void*, uint64_t, void*, int, int, bool*);
  int result = 0;
  if (!slot<Result>(s->utils, 13)(s->utils, call, &result, 4, 154, &failed) || failed || result != 1) {
    fail(s, "Encrypted ticket response failed (EResult " + std::to_string(result) + ")"); return -1;
  }
  using Get = bool (__fastcall*)(void*, void*, int, uint32_t*);
  uint32_t size = 0;
  if (!slot<Get>(s->user, 22)(s->user, output, static_cast<int>(capacity), &size) || !size || size > capacity) {
    fail(s, "Cannot read encrypted app ticket"); return -1;
  }
  return static_cast<int>(size);
}

