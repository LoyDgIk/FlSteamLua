// CloudRedirect_CliMain adapter. Runs outside Flutter and Steam; no hooks are installed.
#include <windows.h>
#include <tlhelp32.h>
#include <cstdio>
#include <string>
#include <vector>

static bool SteamRunning() {
  HANDLE snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  if (snapshot == INVALID_HANDLE_VALUE) return true;
  PROCESSENTRY32W entry{};
  entry.dwSize = sizeof(entry);
  bool running = false;
  if (Process32FirstW(snapshot, &entry)) {
    do { if (_wcsicmp(entry.szExeFile, L"steam.exe") == 0) { running = true; break; } }
    while (Process32NextW(snapshot, &entry));
  }
  CloseHandle(snapshot);
  return running;
}

static std::string Utf8(const wchar_t* text) {
  int count = WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, text, -1, nullptr, 0, nullptr, nullptr);
  if (count <= 0) return {};
  std::string value(static_cast<size_t>(count), '\0');
  WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, text, -1, value.data(), count, nullptr, nullptr);
  value.pop_back();
  return value;
}

int wmain(int argc, wchar_t** argv) {
  if (argc != 6 || SteamRunning()) return 2;
  for (int i : {3, 4}) {
    wchar_t* end = nullptr;
    unsigned long long value = _wcstoui64(argv[i], &end, 10);
    if (end == argv[i] || *end != L'\0' || value == 0 || value > 0xffffffffULL) return 2;
  }
  if (!(wcslen(argv[1]) > 2 && (argv[1][1] == L':' || argv[1][0] == L'\\'))) return 2;
  SetDefaultDllDirectories(LOAD_LIBRARY_SEARCH_DEFAULT_DIRS);
  HMODULE module = LoadLibraryExW(argv[1], nullptr, LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR | LOAD_LIBRARY_SEARCH_DEFAULT_DIRS);
  if (!module) return 3;
  auto run = reinterpret_cast<int (*)(int, char**)>(GetProcAddress(module, "CloudRedirect_CliMain"));
  if (!run) return 4;
  std::vector<std::string> args{"cloud_sync_worker", "--cli", "sync-remote-app",
    Utf8(argv[2]), Utf8(argv[3]), Utf8(argv[4]), Utf8(argv[5])};
  std::vector<char*> pointers;
  for (auto& value : args) pointers.push_back(value.data());
  return run(static_cast<int>(pointers.size()), pointers.data());
}
