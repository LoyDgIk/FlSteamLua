"""Exercise exported failure paths without loading Steam or touching accounts."""
import ctypes
from pathlib import Path

dll = ctypes.CDLL(str(Path(__file__).parent / "build" / "Release" / "steam_bridge.dll"))
dll.sb_open.argtypes = [ctypes.c_wchar_p, ctypes.c_uint32]
dll.sb_open.restype = ctypes.c_void_p
dll.sb_error.argtypes = [ctypes.c_void_p]
dll.sb_error.restype = ctypes.c_char_p
for path, app_id in [(None, 0), ("", 440), (r"Z:\missing-steam-bridge-test", 440)]:
    assert dll.sb_open(path, app_id) is None
    assert dll.sb_error(None)
for name in ["sb_request_stats", "sb_stats_ready", "sb_store_stats", "sb_store_result"]:
    function = getattr(dll, name)
    function.argtypes = [ctypes.c_void_p]
    function.restype = ctypes.c_int
    assert function(None) in (0, -1)
dll.sb_close.argtypes = [ctypes.c_void_p]
dll.sb_close(None)
print("steam_bridge ABI failure-path smoke: PASS (no Steam connection)")
