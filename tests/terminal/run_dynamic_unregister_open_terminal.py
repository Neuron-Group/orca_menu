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


def read_until_exit(master_fd, proc, timeout_s=6.0):
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


def main():
    repo_root = os.getcwd()
    with tempfile.TemporaryDirectory(prefix="orca-menu-dynamic-unregister-open-") as tmpdir:
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
            }
        )
        for key in ("HOME", "XDG_STATE_HOME", "XDG_DATA_HOME", "XDG_CACHE_HOME"):
            os.makedirs(env[key], exist_ok=True)

        try:
            master_fd, slave_fd = pty.openpty()
        except OSError as exc:
            raise PtyUnavailable(str(exc)) from exc

        proc = subprocess.Popen(
            ["nvim", "-u", "tests/minimal_init.lua", "-S", "tests/terminal/dynamic_unregister_open_terminal.lua"],
            cwd=repo_root,
            env=env,
            stdin=slave_fd,
            stdout=slave_fd,
            stderr=slave_fd,
            close_fds=True,
        )
        os.close(slave_fd)

        try:
            output = read_until_exit(master_fd, proc)
            try:
                proc.wait(timeout=1.0)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait(timeout=1.0)

            if not os.path.exists(result_path):
                raise AssertionError(f"result file missing\n{output}")

            with open(result_path, "r", encoding="utf-8") as handle:
                result = json.load(handle)

            if result.get("status") != "ok":
                raise AssertionError(f"unexpected status {result}\n{output}")
            if result.get("menu_count") != 2:
                raise AssertionError(f"expected two menus after unregistering view, got {result}\n{output}")
            if result.get("second_label") != "Tools":
                raise AssertionError(f"expected Tools as remaining runtime menu, got {result}\n{output}")
            if result.get("third_label") is not None:
                raise AssertionError(f"expected third menu removed after unregister, got {result}\n{output}")
            if result.get("popup_open"):
                raise AssertionError(f"expected popup closed after unregistering open runtime menu, got {result}\n{output}")
            if result.get("stack_depth") != 0:
                raise AssertionError(f"expected cleared menu stack after unregistering open runtime menu, got {result}\n{output}")
            if result.get("active_top") != 2:
                raise AssertionError(f"expected active_top to clamp to remaining runtime menu, got {result}\n{output}")
            if not result.get("second_label_col"):
                raise AssertionError(f"expected visible remaining runtime label, got {result}\n{output}")

            print("ok - tests/terminal/run_dynamic_unregister_open_terminal.py")
        finally:
            try:
                os.close(master_fd)
            except OSError:
                pass


if __name__ == "__main__":
    try:
        main()
    except PtyUnavailable as exc:
        print(f"skip - tests/terminal/run_dynamic_unregister_open_terminal.py ({exc})")
    except Exception as exc:
        print(str(exc), file=sys.stderr)
        sys.exit(1)
