#!/usr/bin/env python3

import json
import os
import pty
import select
import subprocess
import sys
import tempfile
import time


class PtyUnavailable(Exception):
    pass


CASES = [
    {
        "name": "f12_normal",
        "open_key": "<F12>",
        "start_mode": "normal",
        "send": b"\x1b[24~",
    },
    {
        "name": "f12_insert",
        "open_key": "<F12>",
        "start_mode": "insert",
        "send": b"\x1b[24~",
    },
    {
        "name": "f12_visual",
        "open_key": "<F12>",
        "start_mode": "visual",
        "send": b"\x1b[24~",
    },
    {
        "name": "f12_visual_line",
        "open_key": "<F12>",
        "start_mode": "visual_line",
        "send": b"\x1b[24~",
    },
    {
        "name": "f12_visual_block",
        "open_key": "<F12>",
        "start_mode": "visual_block",
        "send": b"\x1b[24~",
    },
    {
        "name": "leader_normal",
        "open_key": "<leader>m",
        "start_mode": "normal",
        "send": b" m",
    },
    {
        "name": "leader_insert",
        "open_key": "<leader>m",
        "start_mode": "insert",
        "send": b" m",
    },
    {
        "name": "leader_visual",
        "open_key": "<leader>m",
        "start_mode": "visual",
        "send": b" m",
    },
    {
        "name": "leader_visual_line",
        "open_key": "<leader>m",
        "start_mode": "visual_line",
        "send": b" m",
    },
    {
        "name": "meta_normal",
        "open_key": "<M-m>",
        "start_mode": "normal",
        "send": b"\x1bm",
    },
    {
        "name": "meta_insert",
        "open_key": "<M-m>",
        "start_mode": "insert",
        "send": b"\x1bm",
    },
    {
        "name": "meta_visual",
        "open_key": "<M-m>",
        "start_mode": "visual",
        "send": b"\x1bm",
    },
    {
        "name": "meta_visual_block",
        "open_key": "<M-m>",
        "start_mode": "visual_block",
        "send": b"\x1bm",
    },
]


def read_until_exit(master_fd, proc, timeout_s=5.0):
    end = time.time() + timeout_s
    output = bytearray()

    while time.time() < end:
        if proc.poll() is not None:
            break

        ready, _, _ = select.select([master_fd], [], [], 0.05)
        if master_fd in ready:
            try:
                chunk = os.read(master_fd, 4096)
            except OSError:
                break
            if not chunk:
                break
            output.extend(chunk)

    try:
        while True:
            chunk = os.read(master_fd, 4096)
            if not chunk:
                break
            output.extend(chunk)
    except OSError:
        pass

    return output.decode("utf-8", errors="replace")


def run_case(repo_root, case):
    with tempfile.TemporaryDirectory(prefix="orca-menu-terminal-") as tmpdir:
        result_path = os.path.join(tmpdir, "result.json")
        env = os.environ.copy()
        env.update(
            {
                "HOME": os.path.join(tmpdir, "home"),
                "XDG_STATE_HOME": os.path.join(tmpdir, "state"),
                "XDG_DATA_HOME": os.path.join(tmpdir, "data"),
                "XDG_CACHE_HOME": os.path.join(tmpdir, "cache"),
                "TERM": "xterm-256color",
                "ORCA_TERMINAL_RESULT": result_path,
                "ORCA_TERMINAL_OPEN_KEY": case["open_key"],
                "ORCA_TERMINAL_START_MODE": case["start_mode"],
            }
        )

        for key in ("HOME", "XDG_STATE_HOME", "XDG_DATA_HOME", "XDG_CACHE_HOME"):
            os.makedirs(env[key], exist_ok=True)

        try:
            master_fd, slave_fd = pty.openpty()
        except OSError as exc:
            raise PtyUnavailable(str(exc)) from exc
        command = [
            "nvim",
            "-u",
            "tests/minimal_init.lua",
            "-S",
            "tests/terminal/open_hotkey_terminal.lua",
        ]

        proc = subprocess.Popen(
            command,
            cwd=repo_root,
            env=env,
            stdin=slave_fd,
            stdout=slave_fd,
            stderr=slave_fd,
            close_fds=True,
        )
        os.close(slave_fd)

        try:
            time.sleep(0.4)
            os.write(master_fd, case["send"])
            output = read_until_exit(master_fd, proc)
            try:
                proc.wait(timeout=1.0)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait(timeout=1.0)

            if not os.path.exists(result_path):
                raise AssertionError(f"{case['name']}: result file missing\n{output}")

            with open(result_path, "r", encoding="utf-8") as handle:
                result = json.load(handle)

            if result.get("status") != "ok":
                raise AssertionError(f"{case['name']}: unexpected status {result}\n{output}")
            if result.get("mode") != "n":
                raise AssertionError(f"{case['name']}: expected normal mode, got {result}\n{output}")
            if not result.get("menu_mode"):
                raise AssertionError(f"{case['name']}: expected menu mode, got {result}\n{output}")
            if result.get("popup_open"):
                raise AssertionError(f"{case['name']}: popup should stay closed, got {result}\n{output}")

            print(f"ok - {case['name']}")
        finally:
            try:
                os.close(master_fd)
            except OSError:
                pass


def main():
    repo_root = os.getcwd()
    try:
        for case in CASES:
            run_case(repo_root, case)
    except PtyUnavailable as exc:
        print(f"skip - tests/terminal/run_open_hotkey_terminal.py ({exc})")
        return


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(str(exc), file=sys.stderr)
        sys.exit(1)
