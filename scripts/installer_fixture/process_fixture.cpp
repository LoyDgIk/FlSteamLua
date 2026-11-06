#include <windows.h>

#include <string>

// The parent stands in for the running app; its child stands in for setup.
// These processes have random fixture-only names supplied by the Python runner.
int wmain(int argc, wchar_t** argv) {
  if (argc == 3 && std::wstring(argv[1]) == L"hold") {
    const std::wstring ready = argv[2];
    const std::wstring temporary = ready + L".tmp";
    HANDLE file = CreateFileW(temporary.c_str(), GENERIC_WRITE, FILE_SHARE_READ, nullptr,
                              CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (file == INVALID_HANDLE_VALUE) return 10;
    const std::string processId = std::to_string(GetCurrentProcessId());
    DWORD written = 0;
    const BOOL ok = WriteFile(file, processId.data(),
                              static_cast<DWORD>(processId.size()), &written,
                              nullptr);
    CloseHandle(file);
    if (!ok) return 11;
    if (!MoveFileExW(temporary.c_str(), ready.c_str(), MOVEFILE_REPLACE_EXISTING)) {
      return 14;
    }
    Sleep(INFINITE);
    return 0;
  }
  if (argc != 4 || std::wstring(argv[1]) != L"parent") return 12;
  std::wstring command = L"\"" + std::wstring(argv[2]) + L"\" hold \"" +
                          std::wstring(argv[3]) + L"\"";
  STARTUPINFOW startup{};
  startup.cb = sizeof(startup);
  PROCESS_INFORMATION child{};
  if (!CreateProcessW(argv[2], command.data(), nullptr, nullptr, FALSE,
                       CREATE_NO_WINDOW, nullptr, nullptr, &startup, &child)) {
    return 13;
  }
  CloseHandle(child.hThread);
  CloseHandle(child.hProcess);
  Sleep(INFINITE);
  return 0;
}
