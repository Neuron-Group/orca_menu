#!/usr/bin/env python3

import fcntl
import json
import os
import pty
import select
import struct
import subprocess
import tempfile
import time
import termios


def read_json(master_fd, result_path, proc, predicate, timeout_s=6.0):
    end = time.time() + timeout_s
    output = bytearray()
    while time.time() < end:
        if os.path.exists(result_path):
            try:
                with open(result_path, "r", encoding="utf-8") as handle:
                    result = json.load(handle)
                if predicate(result):
                    return result, output.decode("utf-8", errors="replace")
            except (OSError, json.JSONDecodeError):
                pass

        if proc.poll() is not None:
            break
        ready, _, _ = select.select([master_fd], [], [], 0.05)
        if master_fd in ready:
            try:
                chunk = os.read(master_fd, 4096)
            except OSError:
                break
            if chunk:
                output.extend(chunk)

    return None, output.decode("utf-8", errors="replace")


def main():
    repo_root = os.getcwd()
    with tempfile.TemporaryDirectory(prefix="orca-menu-lualine-mouse-") as tmpdir:
        result_path = os.path.join(tmpdir, "result.json")
        env = os.environ.copy()
        env.update(
            {
                "HOME": os.path.join(tmpdir, "home"),
                "XDG_STATE_HOME": os.path.join(tmpdir, "state"),
                "XDG_DATA_HOME": os.path.join(tmpdir, "data"),
                "XDG_CACHE_HOME": os.path.join(tmpdir, "cache"),
                "TERM": "xterm-256color",
                "ORCA_TEST_EXTRA_RTP": os.path.join(repo_root, "lualine.nvim"),
                "ORCA_TERMINAL_RESULT": result_path,
            }
        )
        for key in ("HOME", "XDG_STATE_HOME", "XDG_DATA_HOME", "XDG_CACHE_HOME"):
            os.makedirs(env[key], exist_ok=True)

        master_fd, slave_fd = pty.openpty()
        fcntl.ioctl(master_fd, termios.TIOCSWINSZ, struct.pack("HHHH", 30, 120, 0, 0))
        proc = subprocess.Popen(
            [
                "nvim",
                "-u",
                "tests/minimal_init.lua",
                "-S",
                "tests/terminal/lualine_mouse_geometry_terminal.lua",
            ],
            cwd=repo_root,
            env=env,
            stdin=slave_fd,
            stdout=slave_fd,
            stderr=slave_fd,
            close_fds=True,
        )
        os.close(slave_fd)

        try:
            ready, output = read_json(
                master_fd,
                result_path,
                proc,
                lambda result: result.get("status") in ("ready", "error"),
            )
            if not ready:
                raise AssertionError(f"PTY did not publish geometry\n{output}")
            if ready.get("status") == "error":
                raise AssertionError(f"PTY geometry setup failed: {ready}\n{output}")

            col = ready["target_col"]
            row = ready["target_row"]
            os.write(master_fd, f"\x1b[<0;{col};{row}M".encode("ascii"))
            os.write(master_fd, f"\x1b[<0;{col};{row}m".encode("ascii"))

            result, output = read_json(
                master_fd,
                result_path,
                proc,
                lambda value: value.get("status") in ("ok", "error") and value.get("status") != "ready",
            )
            if not result:
                raise AssertionError(f"PTY click produced no final result\n{output}")
            if result.get("status") != "ok":
                raise AssertionError(f"unexpected PTY result {result}\n{output}")
            if result.get("active_top") != ready.get("target"):
                raise AssertionError(f"Search was not opened by its rightmost click: {result}\n{output}")

            print("ok - tests/terminal/run_lualine_mouse_geometry_terminal.py")
        finally:
            try:
                proc.wait(timeout=1.0)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait(timeout=1.0)
            try:
                os.close(master_fd)
            except OSError:
                pass


if __name__ == "__main__":
    main()
