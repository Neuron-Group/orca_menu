#!/usr/bin/env python3

import json
import os
import pty
import select
import struct
import subprocess
import tempfile
import termios
import time
import fcntl


def main():
    repo_root = os.getcwd()
    with tempfile.TemporaryDirectory(prefix="orca-menu-statusline-mouse-") as tmpdir:
        result_path = os.path.join(tmpdir, "result.json")
        ready_path = result_path + ".ready"
        popup_ready_path = ready_path + ".popup"
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
                "ORCA_TERMINAL_READY": ready_path,
            }
        )
        for key in ("HOME", "XDG_STATE_HOME", "XDG_DATA_HOME", "XDG_CACHE_HOME"):
            os.makedirs(env[key], exist_ok=True)

        master_fd, slave_fd = pty.openpty()
        fcntl.ioctl(slave_fd, termios.TIOCSWINSZ, struct.pack("HHHH", 24, 80, 0, 0))
        proc = subprocess.Popen(
            [
                "nvim",
                "-u",
                "tests/minimal_init.lua",
                "-c",
                "luafile tests/terminal/statusline_mouse_cursor_guard.lua",
            ],
            cwd=repo_root,
            env=env,
            stdin=slave_fd,
            stdout=slave_fd,
            stderr=slave_fd,
            close_fds=True,
        )
        os.close(slave_fd)

        sent_topbar = False
        sent_popup = False
        output = bytearray()
        deadline = time.time() + 5
        while time.time() < deadline and not os.path.exists(result_path):
            if not sent_topbar and os.path.exists(ready_path):
                with open(ready_path, encoding="utf-8") as handle:
                    target = json.load(handle)
                os.write(master_fd, f"\x1b[<0;{target['col']};{target['row']}M".encode())
                sent_topbar = True
            if sent_topbar and not sent_popup and os.path.exists(popup_ready_path):
                with open(popup_ready_path, encoding="utf-8") as handle:
                    target = json.load(handle)
                os.write(master_fd, f"\x1b[<0;{target['col']};{target['row']}M".encode())
                sent_popup = True

            ready, _, _ = select.select([master_fd], [], [], 0.05)
            if master_fd in ready:
                try:
                    output.extend(os.read(master_fd, 4096))
                except OSError:
                    break

        try:
            proc.wait(timeout=1)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait(timeout=1)

        if not os.path.exists(result_path):
            raise AssertionError("result file missing\n" + output.decode("utf-8", errors="replace"))

        with open(result_path, encoding="utf-8") as handle:
            result = json.load(handle)

        if not sent_topbar:
            raise AssertionError(f"topbar mouse event was not sent: {result}")
        if not sent_popup:
            raise AssertionError(f"popup mouse event was not sent: {result}")
        if result.get("popup_open"):
            raise AssertionError(f"popup item click did not close Orca: {result}")
        if result.get("action") != 1:
            raise AssertionError(f"popup item action did not run exactly once: {result}")
        if result.get("local_mouse") != 0:
            raise AssertionError(f"buffer-local mouse mapping ran after Orca intercept: {result}")
        if result.get("cursor") != [3, 2]:
            raise AssertionError(f"popup item action cursor move was lost: {result}")
        restored = result.get("restored_mapping") or {}
        if (
            restored.get("desc") != "Original buffer-local mouse mapping"
            or restored.get("buffer") != 1
            or restored.get("rhs") != "<Plug>(OrcaTerminalOriginalMouse)"
            or restored.get("noremap") != 0
        ):
            raise AssertionError(f"original buffer-local mouse mapping was not restored: {result}")

        print("ok - tests/terminal/run_statusline_mouse_cursor_guard.py")


if __name__ == "__main__":
    main()
