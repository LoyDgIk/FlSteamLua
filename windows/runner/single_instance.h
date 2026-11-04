#ifndef RUNNER_SINGLE_INSTANCE_H_
#define RUNNER_SINGLE_INSTANCE_H_

#include <windows.h>

inline constexpr wchar_t kInstanceProperty[] = L"FlSteamLua.MainWindow";
inline constexpr wchar_t kInstanceMutex[] = L"Local\\FlSteamLua.Application";

inline UINT InstanceActivationMessage() {
  static const UINT message =
      RegisterWindowMessageW(L"FlSteamLua.ShowExistingWindow");
  return message;
}

inline BOOL CALLBACK FindInstanceWindow(HWND window, LPARAM result) {
  if (GetPropW(window, kInstanceProperty) != nullptr) {
    *reinterpret_cast<HWND*>(result) = window;
    return FALSE;
  }
  return TRUE;
}

inline void ActivateExistingInstance() {
  HWND existing = nullptr;
  // The first process may still be constructing its native window.
  for (int attempt = 0; attempt < 30 && existing == nullptr; ++attempt) {
    EnumWindows(FindInstanceWindow, reinterpret_cast<LPARAM>(&existing));
    if (existing == nullptr) Sleep(100);
  }
  if (existing == nullptr) return;
  DWORD process_id = 0;
  GetWindowThreadProcessId(existing, &process_id);
  AllowSetForegroundWindow(process_id);
  DWORD_PTR ignored = 0;
  SendMessageTimeoutW(existing, InstanceActivationMessage(), 0, 0,
                      SMTO_ABORTIFHUNG, 2000, &ignored);
}

class InstanceMutex {
 public:
  InstanceMutex() : handle_(CreateMutexW(nullptr, FALSE, kInstanceMutex)),
                    already_running_(GetLastError() == ERROR_ALREADY_EXISTS) {}
  ~InstanceMutex() {
    if (handle_ != nullptr) CloseHandle(handle_);
  }
  bool valid() const { return handle_ != nullptr; }
  bool already_running() const { return already_running_; }

 private:
  HANDLE handle_;
  bool already_running_;
};

#endif  // RUNNER_SINGLE_INSTANCE_H_
