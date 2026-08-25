#!/usr/bin/env python3

import json
import os
import pty
import select
import subprocess
import sys
import tempfile
import time


def run_case(repo_root, lean_root, lean_file, laststatus, section, owner_kind):
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
                "ORCA_OWNER": owner_kind,
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


def validate(result, laststatus, section, owner_kind):
    if result.get("status") != "ok":
        raise AssertionError(f"unexpected probe status: {result}")
    if result.get("laststatus") != laststatus or result.get("section") != section:
        raise AssertionError(f"probe configuration did not reach Neovim: {result}")
    if result.get("infoview_config", {}).get("relative") != "":
        raise AssertionError(f"expected a real split infoview window: {result}")
    expected_owner = result.get("infoview_win") if owner_kind == "infoview" else result.get("main_win")
    if result.get("owner_win") != expected_owner:
        raise AssertionError(f"expected {owner_kind} to own the menu request: {result}")
    if result.get("owner_kind") != owner_kind:
        raise AssertionError(f"probe owner configuration did not reach Neovim: {result}")
    if result.get("component", {}).get("screen", {}).get("width") != result.get("component_width"):
        raise AssertionError(f"lualine screen span does not match the rendered component: {result}")
    if result.get("anchor", {}).get("col") != result.get("expected_col"):
        raise AssertionError(f"anchor did not use lualine screen geometry: {result}")
    if result.get("popup_screen", [None, None])[1] != result.get("expected_col") + 1:
        raise AssertionError(f"popup is not at the expected editor screen column: {result}")
    popup_entry = result.get("popup_entry", {})
    if popup_entry.get("frame_col") != result.get("expected_frame_col"):
        raise AssertionError(f"popup frame does not follow lualine's screen geometry: {result}")


def main():
    repo_root = os.getcwd()
    lean_root = os.environ.get("ORCA_LEAN_NVIM", "/home/neuron/Projects/lean.nvim")
    lean_file = os.environ.get(
        "ORCA_LEAN_FILE",
        os.path.join(lean_root, "spec/fixtures/projects/Example/Example.lean"),
    )
    requested_laststatus = os.environ.get("ORCA_LASTSTATUS")
    requested_section = os.environ.get("ORCA_LUALINE_SECTION")
    requested_owner = os.environ.get("ORCA_OWNER")
    if requested_laststatus or requested_section:
        cases = [(int(requested_laststatus or "2"), requested_section or "a", requested_owner or "infoview")]
    else:
        cases = [
            (2, "a", "infoview"),
            (2, "a", "main"),
            (3, "y", "infoview"),
            (3, "y", "main"),
        ]

    results = []
    for laststatus, section, owner_kind in cases:
        result = run_case(repo_root, lean_root, lean_file, laststatus, section, owner_kind)
        validate(result, laststatus, section, owner_kind)
        results.append(result)

    global_results = [result for result in results if result.get("laststatus") == 3]
    if len(global_results) == 2:
        first, second = global_results
        if first.get("component", {}).get("screen") != second.get("component", {}).get("screen"):
            raise AssertionError(f"global lualine geometry changed with the owner window: {results}")
        if first.get("anchor", {}).get("col") != second.get("anchor", {}).get("col"):
            raise AssertionError(f"global popup anchor changed with the owner window: {results}")
        if first.get("popup_entry", {}).get("frame_col") != second.get("popup_entry", {}).get("frame_col"):
            raise AssertionError(f"global popup frame changed with the owner window: {results}")

    print(json.dumps(results if len(results) > 1 else results[0], indent=2, sort_keys=True))
    print("ok - tests/terminal/run_lean_infoview_geometry_probe.py")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(str(exc), file=sys.stderr)
        sys.exit(1)
