#!/usr/bin/env python3

import json
import os
import pty
import select
import subprocess
import sys
import tempfile
import time


def main():
    repo_root = os.getcwd()
    lean_root = os.environ.get("ORCA_LEAN_NVIM", "/home/neuron/Projects/lean.nvim")
    lean_file = os.environ.get(
        "ORCA_LEAN_FILE",
        os.path.join(lean_root, "spec/fixtures/projects/Example/Example.lean"),
    )

    with tempfile.TemporaryDirectory(prefix="orca-menu-lean-geometry-") as tmpdir:
        result_path = os.path.join(tmpdir, "result.json")
        env = os.environ.copy()
        env.update(
            {
                "HOME": os.path.join(tmpdir, "home"),
                "XDG_STATE_HOME": os.path.join(tmpdir, "state"),
                "XDG_DATA_HOME": os.path.join(tmpdir, "data"),
                "XDG_CACHE_HOME": os.path.join(tmpdir, "cache"),
                "TERM": "xterm-256color",
                "ORCA_LEAN_NVIM": lean_root,
                "ORCA_LUALINE": os.path.join(repo_root, "lualine.nvim"),
                "ORCA_LEAN_FILE": lean_file,
                "ORCA_TERMINAL_RESULT": result_path,
            }
        )
        for key in ("HOME", "XDG_STATE_HOME", "XDG_DATA_HOME", "XDG_CACHE_HOME"):
            os.makedirs(env[key], exist_ok=True)

        master_fd, slave_fd = pty.openpty()
        proc = subprocess.Popen(
            [
                "nvim",
                "-u",
                "tests/terminal/lean_infoview_geometry_init.lua",
                "-S",
                "tests/terminal/lean_infoview_geometry_probe.lua",
            ],
            cwd=repo_root,
            env=env,
            stdin=slave_fd,
            stdout=slave_fd,
            stderr=slave_fd,
            close_fds=True,
        )
        os.close(slave_fd)

        output = bytearray()
        end = time.time() + 15
        while time.time() < end and not os.path.exists(result_path):
            if proc.poll() is not None:
                break
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

        if result.get("status") != "ok":
            raise AssertionError(f"unexpected probe status: {result}")
        if result.get("infoview_config", {}).get("relative") != "":
            raise AssertionError(f"expected a real split infoview window: {result}")
        if result.get("owner_win") != result.get("infoview_win"):
            raise AssertionError(f"expected the infoview to own the menu request: {result}")
        if result.get("anchor", {}).get("col") != result.get("expected_col"):
            raise AssertionError(f"anchor did not use lualine screen geometry: {result}")
        if result.get("popup_screen", [None, None])[1] != result.get("expected_col") + 1:
            raise AssertionError(f"popup is not at the expected editor screen column: {result}")

        print(json.dumps(result, indent=2, sort_keys=True))
        print("ok - tests/terminal/run_lean_infoview_geometry_probe.py")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(str(exc), file=sys.stderr)
        sys.exit(1)
