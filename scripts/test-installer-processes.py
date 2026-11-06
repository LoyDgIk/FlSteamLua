"""Exercise setup's taskkill policy against isolated Win32 fixture processes."""

from __future__ import annotations

import argparse
import ctypes
from ctypes import wintypes
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import time
import uuid


def command(argv: list[str], cwd: Path | None = None) -> None:
    completed = subprocess.run(argv, cwd=cwd, capture_output=True, timeout=90)
    if completed.returncode:
        raise RuntimeError(completed.stdout.decode(errors="replace") + completed.stderr.decode(errors="replace"))


def find_cmake() -> str:
    cmake = shutil.which("cmake")
    if cmake:
        return cmake
    vswhere = Path(os.environ["ProgramFiles(x86)"]) / "Microsoft Visual Studio/Installer/vswhere.exe"
    visual_studio = subprocess.check_output(
        [str(vswhere), "-latest", "-products", "*", "-requires",
         "Microsoft.VisualStudio.Component.VC.Tools.x86.x64", "-property", "installationPath"],
        timeout=20, text=True,
    ).strip()
    return str(Path(visual_studio) / "Common7/IDE/CommonExtensions/Microsoft/CMake/CMake/bin/cmake.exe")


def run_case(fixture: Path, directory: Path, switches: list[str], keep_child: bool) -> None:
    unique = uuid.uuid4().hex[:12]
    parent_image = directory / f"flsl_parent_{unique}.exe"
    child_image = directory / f"flsl_setup_{unique}.exe"
    child_pid_file = directory / f"child_{unique}.pid"
    shutil.copy2(fixture, parent_image)
    shutil.copy2(fixture, child_image)
    parent = subprocess.Popen(
        [str(parent_image), "parent", str(child_image), str(child_pid_file)],
        creationflags=subprocess.CREATE_NO_WINDOW,
    )
    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel.OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
    kernel.OpenProcess.restype = wintypes.HANDLE
    kernel.WaitForSingleObject.argtypes = [wintypes.HANDLE, wintypes.DWORD]
    kernel.WaitForSingleObject.restype = wintypes.DWORD
    kernel.TerminateProcess.argtypes = [wintypes.HANDLE, wintypes.UINT]
    kernel.CloseHandle.argtypes = [wintypes.HANDLE]
    child_handle = None
    try:
        deadline = time.monotonic() + 10
        while not child_pid_file.exists():
            if parent.poll() is not None or time.monotonic() >= deadline:
                raise RuntimeError("Fixture child did not become ready")
            time.sleep(0.02)
        child_pid = int(child_pid_file.read_text())
        child_handle = kernel.OpenProcess(0x00100001, False, child_pid)
        if not child_handle:
            raise ctypes.WinError(ctypes.get_last_error())
        command([str(Path(os.environ["SystemRoot"]) / "System32/taskkill.exe"),
                 *switches, parent_image.name])
        parent.wait(timeout=10)
        child_running = kernel.WaitForSingleObject(child_handle, 400) == 258
        label = " ".join(switches)
        print(f"{label}: app stopped=True setup alive={child_running}", flush=True)
        if child_running != keep_child:
            raise AssertionError(f"{label}: expected setup alive={keep_child}, got {child_running}")
    finally:
        if child_handle:
            if kernel.WaitForSingleObject(child_handle, 0) == 258:
                kernel.TerminateProcess(child_handle, 0)
                kernel.WaitForSingleObject(child_handle, 5000)
            kernel.CloseHandle(child_handle)
        if parent.poll() is None:
            parent.kill()
            parent.wait(timeout=5)


def stop_workers(fixture: Path, directory: Path, switches: list[str], images: list[str]) -> None:
    """Each explicitly named worker is stopped without a process-tree kill."""
    for index, image in enumerate(images):
        unique = uuid.uuid4().hex[:12]
        executable = directory / f"flsl_worker_{index}_{unique}.exe"
        ready = directory / f"worker_{unique}.pid"
        shutil.copy2(fixture, executable)
        worker = subprocess.Popen(
            [str(executable), "hold", str(ready)],
            creationflags=subprocess.CREATE_NO_WINDOW,
        )
        try:
            deadline = time.monotonic() + 10
            while not ready.exists():
                if worker.poll() is not None or time.monotonic() >= deadline:
                    raise RuntimeError("Fixture worker did not become ready")
                time.sleep(0.02)
            command([str(Path(os.environ["SystemRoot"]) / "System32/taskkill.exe"),
                     *switches, executable.name])
            worker.wait(timeout=10)
            print(f"Explicit target {image}: stopped=True", flush=True)
        finally:
            if worker.poll() is None:
                worker.kill()
                worker.wait(timeout=5)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline", action="store_true", help="Also demonstrate why the old /T policy killed setup")
    parser.add_argument("--cmake")
    parser.add_argument("--installer", type=Path)
    args = parser.parse_args()
    if os.name != "nt":
        raise SystemExit("This regression requires Windows")
    root = Path(__file__).resolve().parent.parent
    installer_path = args.installer or root / "packaging/windows/FlSteamLua.iss"
    installer = installer_path.read_text(encoding="utf-8-sig")
    match = re.search(r"'(/F(?: /T)? /IM )'\s*\+\s*ImageName", installer)
    if not match:
        raise SystemExit("Installer taskkill argument declaration was not found")
    switches = match[1].split()
    targets = re.findall(r"KillApplicationProcess\('([^']+)'\);", installer)
    if not targets:
        raise SystemExit("Installer application/worker targets were not found")
    with tempfile.TemporaryDirectory(prefix="flsl-installer-probe-") as temp:
        directory = Path(temp).resolve()
        build = directory / "build"
        cmake = args.cmake or find_cmake()
        command([cmake, "-S", str(root / "scripts/installer_fixture"), "-B", str(build), "-A", "x64"])
        command([cmake, "--build", str(build), "--config", "Release"])
        fixture = build / "Release/installer_process_fixture.exe"
        if args.baseline:
            run_case(fixture, directory, ["/F", "/T", "/IM"], keep_child=False)
        run_case(fixture, directory, switches, keep_child=True)
        stop_workers(fixture, directory, switches, targets)
    print("Installer process regression: PASS", flush=True)


if __name__ == "__main__":
    main()
