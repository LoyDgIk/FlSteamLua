#pragma once
#include <stdint.h>

#ifdef STEAM_BRIDGE_IMPLEMENTATION
#define SB_API extern "C" __declspec(dllexport)
#else
#define SB_API extern "C" __declspec(dllimport)
#endif

// One session per OS process. SteamAppId is set before steamclient is loaded.
SB_API void* sb_open(const wchar_t* steam_path, uint32_t app_id);
SB_API void sb_close(void* session);
SB_API const char* sb_error(void* session);
SB_API int sb_request_stats(void* session);
SB_API int sb_stats_ready(void* session);
SB_API void sb_pump(void* session);
SB_API uint32_t sb_achievement_count(void* session);
SB_API const char* sb_achievement_name(void* session, uint32_t index);
SB_API const char* sb_achievement_attribute(void* session, const char* id, const char* key);
SB_API int sb_achievement_state(void* session, const char* id, uint8_t* achieved, uint32_t* unlock_time);
SB_API int sb_set_achievement(void* session, const char* id, int achieved);
SB_API int sb_get_stat_int(void* session, const char* id, int32_t* value);
SB_API int sb_get_stat_float(void* session, const char* id, float* value);
SB_API int sb_set_stat_int(void* session, const char* id, int32_t value);
SB_API int sb_set_stat_float(void* session, const char* id, float value);
SB_API int sb_store_stats(void* session);
SB_API int sb_store_result(void* session);
// AppTicket: bytes written, or -1 on failure. Optional steam_id receives account ID.
SB_API int sb_app_ticket(void* session, uint8_t* output, uint32_t capacity, uint64_t* steam_id);
SB_API uint64_t sb_request_encrypted_ticket(void* session);
// Encrypted ticket: 0 while pending, bytes written on success, -1 on error.
SB_API int sb_encrypted_ticket(void* session, uint64_t call, uint8_t* output, uint32_t capacity);
