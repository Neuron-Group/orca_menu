# NVF Orca Menu Map

Extracted from `~/.config/home-manager/programs/nvf/orca-menu.nix`.

## Global Setup

- open key: `<M-m>`
- mouse: enabled
- topbar hint format: `{hint}→{label}`
- lualine section: `y`
- border: `rounded`
- LSP override: `leanls` swaps in a Lean-specific menu set

## Default Menu Tree

- `Help (?)`
  - `Keymaps (k)`
  - `Help Tags (t)`
  - `Messages (m)`
  - `Check Health (c)`
- `Tools (t)`
  - `Git (g)`
    - `Status (s)`
    - `Branches (b)`
    - `Commits (c)`
    - `Files (f)`
  - `Codex (c)`
    - `Toggle Thread (t)`
    - `New Thread (n)`
    - `List Threads (i)`
    - `Delete Thread (d)`
    - `Send Buffer (b)`
    - `Send Selection (s)`
  - `Projects (p)`
  - `LazyGit (l)`
  - `Diff (d)`
    - `Open View (o)`
    - `File History (h)`
- `LSP (p)`
  - `Definition (d)`
  - `References (r)`
  - `Implementation (i)`
  - `More Go To (g)`
    - `Type Definition (t)`
    - `Declaration (e)`
  - `Rename Symbol (n)`
  - `Code Actions (a)`
  - `Hover Docs (h)`
  - `Format Buffer (f)`
- `View (v)`
  - `Explorer (e)`
  - `Outline (o)`
  - `Terminal (t)`
  - `Undo Tree (u)`
  - `Diagnostics List (d)`
  - `Appearance (a)`
    - `Toggle Wrap (w)`
    - `Toggle Line Numbers (n)`
    - `Toggle Relative Number (r)`
    - `Toggle Spell (s)`
    - `Toggle Paste Mode (p)`
- `Search (s)`
  - `Find in Buffer (f)`
  - `Grep in Project (g)`
  - `Buffers (b)`
  - `Go To (t)`
    - `Commands (c)`
    - `Help (h)`
    - `Keymaps (k)`
  - `Diagnostics (d)`
    - `Document Diagnostics (d)`
    - `Workspace Diagnostics (w)`
    - `Todo Comments (t)`
- `Edit (e)`
  - `Undo (u)`
  - `Redo (r)`
  - `Cut (t)`
  - `Copy (c)`
  - `Paste (p)`
  - `Select All (a)`
  - `Find (f)`
  - `Replace (g)`
- `File (f)`
  - `New Buffer (n)`
  - `Open File (o)`
  - `Recent Files (r)`
  - `Write (w)`
  - `Write As (a)`
  - `Save All (s)`
  - `Close Buffer (c)`
  - `Close All Buffers (b)`
  - `Quit Window (q)`
  - `Quit All (u)`

## Lean Override

- replaces the default menu list when `leanls` is attached
- inserts `∀ (y)` between `Search` and `Edit`
  - `Info View (i)`
  - `Goal (g)`
  - `Term Goal (t)`
  - `Restart File (r)`
