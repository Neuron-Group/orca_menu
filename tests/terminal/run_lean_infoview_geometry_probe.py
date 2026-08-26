#!/usr/bin/env python3

import json
import fcntl
import os
import pty
import select
import subprocess
import struct
import sys
import tempfile
import time
import termios


def run_case(repo_root, lean_root, lean_file, laststatus, section, owner_kind, env_overrides=None):
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
                "ORCA_INFOVIEW_WIDTH": os.environ.get("ORCA_INFOVIEW_WIDTH", ""),
                "ORCA_INFOVIEW_GUTTER": os.environ.get("ORCA_INFOVIEW_GUTTER", ""),
                "ORCA_IGNORE_INFOVIEW": os.environ.get("ORCA_IGNORE_INFOVIEW", ""),
                "ORCA_INITIAL_LASTSTATUS": os.environ.get("ORCA_INITIAL_LASTSTATUS", ""),
                "ORCA_SWITCH_LASTSTATUS": os.environ.get("ORCA_SWITCH_LASTSTATUS", ""),
                "ORCA_REAL_MOUSE": os.environ.get("ORCA_REAL_MOUSE", "0"),
                "ORCA_REAL_MOUSE_CLICK": os.environ.get("ORCA_REAL_MOUSE_CLICK", "0"),
                "ORCA_REAL_MOUSE_AUTO": os.environ.get("ORCA_REAL_MOUSE_AUTO", "0"),
                "ORCA_MOUSE_TARGET": os.environ.get("ORCA_MOUSE_TARGET", ""),
                "ORCA_TEST_POSITION_CACHE": os.environ.get("ORCA_TEST_POSITION_CACHE", "0"),
                "ORCA_CACHE_TRANSITION_CURRENT": os.environ.get("ORCA_CACHE_TRANSITION_CURRENT", ""),
                "ORCA_MOUSE_COL": os.environ.get("ORCA_MOUSE_COL", ""),
                "ORCA_MOUSE_ROW": os.environ.get("ORCA_MOUSE_ROW", ""),
            }
        )
        env.update({key: str(value) for key, value in (env_overrides or {}).items()})
        for key in ("HOME", "XDG_STATE_HOME", "XDG_DATA_HOME", "XDG_CACHE_HOME"):
            os.makedirs(env[key], exist_ok=True)

        master_fd, slave_fd = pty.openpty()
        columns = int(env.get("ORCA_TERMINAL_COLUMNS", "80"))
        lines = int(env.get("ORCA_TERMINAL_LINES", "24"))
        size = struct.pack("HHHH", lines, columns, 0, 0)
        fcntl.ioctl(slave_fd, termios.TIOCSWINSZ, size)
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
        mouse_col = env.get("ORCA_MOUSE_COL")
        mouse_row = env.get("ORCA_MOUSE_ROW")
        mouse_sent = False
        mouse_send_at = time.time() + 2 if mouse_col and mouse_row else None
        while time.time() < end and not os.path.exists(result_path):
            if proc.poll() is not None:
                break
            if not mouse_sent and env.get("ORCA_REAL_MOUSE_AUTO") == "1":
                ready_path = result_path + ".ready"
                if os.path.exists(ready_path):
                    with open(ready_path, encoding="utf-8") as handle:
                        ready = json.load(handle)
                    mouse_col = str(ready["screencol"])
                    mouse_row = str(ready["screenrow"])
                    os.write(master_fd, f"\x1b[<0;{mouse_col};{mouse_row}M".encode())
                    mouse_sent = True
            if mouse_send_at and not mouse_sent and time.time() >= mouse_send_at:
                os.write(master_fd, f"\x1b[<0;{mouse_col};{mouse_row}M".encode())
                mouse_sent = True
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
        trace_path = result_path + ".trace"
        if os.path.exists(trace_path):
            with open(trace_path, encoding="utf-8") as handle:
                result["trace"] = [json.loads(line) for line in handle if line.strip()]
        return result


def validate(result, laststatus, section, owner_kind):
    if result.get("status") != "ok":
        raise AssertionError(f"unexpected probe status: {result}")
    if "real_mouse" in result:
        real_mouse = result["real_mouse"]
        if real_mouse.get("target_hidden"):
            if real_mouse.get("target_position", {}).get("screen") is not None:
                raise AssertionError(f"hidden real mouse target still exposed screen geometry: {result}")
            if result.get("popup_open"):
                raise AssertionError(f"hidden real mouse target should not open a popup: {result}")
            return
        item = real_mouse.get("item", {})
        col = real_mouse.get("mouse", {}).get("screencol")
        expected_hit = (
            isinstance(col, int)
            and isinstance(item.get("start_col"), int)
            and isinstance(item.get("end_col"), int)
            and item["start_col"] <= col <= item["end_col"]
        )
        actual_hit = real_mouse.get("hit") is not None
        if actual_hit != expected_hit:
            raise AssertionError(f"real mouse hit did not follow lualine item geometry: {result}")
        popup = result.get("popup")
        if popup is not None:
            expected_owner = real_mouse.get("mouse", {}).get("winid")
            if not isinstance(expected_owner, int) or expected_owner <= 0:
                expected_owner = real_mouse.get("target_position", {}).get("winid")
            if popup.get("owner_win") != expected_owner:
                raise AssertionError(f"popup owner did not follow the hit window: {result}")
            popup_item = popup.get("component", {}).get("screen", {}).get("item")
            if popup_item != item:
                raise AssertionError(f"popup did not retain the hit lualine item geometry: {result}")
            border_size = 1 if result.get("popup_config", {}).get("border") else 0
            frame_width = result.get("frame_width")
            if frame_width is not None:
                expected_frame_col = min(
                    max(item["end_col"] + border_size - frame_width + 1, 1),
                    max(result.get("columns", 1) - frame_width + 1, 1),
                )
                if popup.get("popup_entry", {}).get("frame_col") != expected_frame_col:
                    raise AssertionError(f"popup frame did not align to the hit item: {result}")
        return
    if result.get("laststatus") != laststatus or result.get("section") != section:
        raise AssertionError(f"probe configuration did not reach Neovim: {result}")
    if result.get("infoview_config", {}).get("relative") != "":
        raise AssertionError(f"expected a real split infoview window: {result}")
    expected_owner = result.get("infoview_win") if owner_kind == "infoview" else result.get("main_win")
    if result.get("owner_win") != expected_owner:
        raise AssertionError(f"expected {owner_kind} to own the menu request: {result}")
    if result.get("owner_kind") != owner_kind:
        raise AssertionError(f"probe owner configuration did not reach Neovim: {result}")
    if result.get("component_visible") is False:
        component = result.get("component", {})
        if component.get("visible") or component.get("screen") is not None:
            raise AssertionError(f"clipped component exposed visible screen geometry: {result}")
        if result.get("component_range") is not None:
            raise AssertionError(f"clipped component was fully rendered on screen: {result}")
        return
    if result.get("component", {}).get("screen", {}).get("width") != result.get("component_width"):
        raise AssertionError(f"lualine screen span does not match the rendered component: {result}")
    cache_transition = result.get("cache_transition")
    if cache_transition is not None:
        cache_position = cache_transition.get("position") or {}
        expected_cache_index = 3 if laststatus == 3 else 2
        if cache_position.get("index") != expected_cache_index:
            raise AssertionError(f"lualine position cache kept the active infoview layout: {result}")
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
        cases = [
            {
                "name": "requested",
                "laststatus": int(requested_laststatus or "2"),
                "section": requested_section or "a",
                "owner": requested_owner or "infoview",
                "env": {},
            }
        ]
    else:
        cases = [
            {"name": "local_a_infoview", "laststatus": 2, "section": "a", "owner": "infoview", "env": {}},
            {"name": "local_a_main", "laststatus": 2, "section": "a", "owner": "main", "env": {}},
            {"name": "local_y_infoview", "laststatus": 2, "section": "y", "owner": "infoview", "env": {}},
            {"name": "global_y_infoview", "laststatus": 3, "section": "y", "owner": "infoview", "env": {}},
            {"name": "global_y_main", "laststatus": 3, "section": "y", "owner": "main", "env": {}},
            {
                "name": "lean_nvf_global_y_infoview",
                "laststatus": 3,
                "section": "y",
                "owner": "infoview",
                "env": {
                    "ORCA_TERMINAL_COLUMNS": "140",
                    "ORCA_INFOVIEW_GUTTER": "1",
                    "ORCA_SUBMENU_BORDER": "none",
                    "ORCA_MENU_SHAPE": "lean",
                    "ORCA_LUALINE_SHAPE": "nvf",
                    "ORCA_TARGET_INDEX": "4",
                    "ORCA_TOPBAR_HINT_FORMAT": "{hint}→{label}",
                },
            },
        ]

    results = []
    case_results = {}
    for case in cases:
        laststatus = case["laststatus"]
        section = case["section"]
        owner_kind = case["owner"]
        result = run_case(repo_root, lean_root, lean_file, laststatus, section, owner_kind, case["env"])
        validate(result, laststatus, section, owner_kind)
        results.append(result)
        case_results[case["name"]] = result

    if "global_y_infoview" in case_results and "global_y_main" in case_results:
        first = case_results["global_y_infoview"]
        second = case_results["global_y_main"]
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
