#!/usr/bin/env python3

import json
import os
import pty
import select
import subprocess
import sys
import tempfile
import time


def run_case(repo_root, lean_root, lean_file, laststatus, section):
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
                "ORCA_LASTSTATUS": str(laststatus),
                "ORCA_LUALINE_SECTION": section,
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
            return json.load(handle)


def validate(result, laststatus, section):
    if result.get("status") != "ok":
        raise AssertionError(f"unexpected probe status: {result}")
    if result.get("laststatus") != laststatus or result.get("section") != section:
        raise AssertionError(f"probe configuration did not reach Neovim: {result}")
    if result.get("infoview_config", {}).get("relative") != "":
        raise AssertionError(f"expected a real split infoview window: {result}")
    if result.get("owner_win") != result.get("infoview_win"):
        raise AssertionError(f"expected the infoview to own the menu request: {result}")
    if result.get("anchor", {}).get("col") != result.get("expected_col"):
        raise AssertionError(f"anchor did not use lualine screen geometry: {result}")
    if result.get("popup_screen", [None, None])[1] != result.get("expected_col") + 1:
        raise AssertionError(f"popup is not at the expected editor screen column: {result}")
    popup_entry = result.get("popup_entry", {})
    if popup_entry.get("frame_col") != result.get("expected_frame_col"):
        raise AssertionError(f"popup frame does not follow lualine's host geometry: {result}")
    window_screen = result["component"]["screen"].get("window")
    if window_screen:
        frame_end = popup_entry["frame_col"] + popup_entry["frame_width"] - 1
        if popup_entry["frame_col"] < window_screen["start_col"] or frame_end > window_screen["end_col"]:
            raise AssertionError(f"popup frame escaped lualine's host window: {result}")


def main():
    repo_root = os.getcwd()
    lean_root = os.environ.get("ORCA_LEAN_NVIM", "/home/neuron/Projects/lean.nvim")
    lean_file = os.environ.get(
        "ORCA_LEAN_FILE",
        os.path.join(lean_root, "spec/fixtures/projects/Example/Example.lean"),
    )
    requested_laststatus = os.environ.get("ORCA_LASTSTATUS")
    requested_section = os.environ.get("ORCA_LUALINE_SECTION")
    if requested_laststatus or requested_section:
        cases = [(int(requested_laststatus or "2"), requested_section or "a")]
    else:
        cases = [(2, "a"), (3, "y")]

    results = []
    for laststatus, section in cases:
        result = run_case(repo_root, lean_root, lean_file, laststatus, section)
        validate(result, laststatus, section)
        results.append(result)

    print(json.dumps(results if len(results) > 1 else results[0], indent=2, sort_keys=True))
    print("ok - tests/terminal/run_lean_infoview_geometry_probe.py")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(str(exc), file=sys.stderr)
        sys.exit(1)
