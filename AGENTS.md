# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

## Project

This repository contains MaxScript tools for Autodesk 3ds Max (targeting 2024/2025/2026). Scripts are written in MaxScript (`.ms`, `.mcr`); no Python (pymxs) is used here.

## Repository Layout

Each tool lives in its own folder so it can be developed, versioned, and shipped independently.

```
/<ToolName>/
    <ToolName>.ms        # main script / entry point
    <ToolName>.mcr       # macroScript wrapper (for toolbar/menu install), if applicable
    /lib/                # tool-private helpers
    /ui/                 # rollout / dotNet UI code
    /icons/              # 24x24 + 16x16 icons if the tool registers a macro
```

When adding a new tool, create a new top-level folder named after the tool — do not drop loose `.ms` files at the repo root.

## Running & Reloading Scripts in 3ds Max

There is no build step. MaxScript is interpreted by 3ds Max directly.

- **Run once**: in Max, `MAXScript > Run Script…` and pick the `.ms` file, or drag the file into a Max viewport.
- **Reload during development**: `fileIn @"d:\YGJeong\MaxScripts\<ToolName>\<ToolName>.ms"` in the MAXScript Listener re-executes the file (overwrites globals, re-creates rollouts).
- **Install as a macro**: drag the `.mcr` into a Max viewport once; the macro is copied into the user's `usermacros/` and is then available under Customize User Interface → category.
- **Listener output**: `format "...\n"` writes to the Listener; use `print` for value inspection. Errors and stack traces also appear there.

## MaxScript Conventions for This Repo

- **Scope hygiene**: wrap each tool in a `struct` or a single rollout with local variables. Avoid leaking globals — Max persists globals across scenes within a session, so name collisions across tools are real.
- **Rollouts**: define UI as `rollout`, open with `createDialog`. Keep handler bodies thin — delegate to struct methods so logic is callable without the UI (helpful for batch use).
- **Undo**: wrap any scene-modifying operation in `undo on (...)` so a single Ctrl+Z reverses the whole tool action.
- **Selection safety**: never assume `$` (current selection) is non-empty; check `selection.count > 0` and bail with a clear message.
- **Paths**: use `@"..."` literal-string syntax for Windows paths to avoid `\` escape issues.
- **Encoding**: save `.ms` / `.mcr` as UTF-8 with BOM (or ANSI). Max's parser does **not** handle UTF-16 — `Out-File` in PowerShell defaults to UTF-16 LE and will produce files Max cannot read. Use `Set-Content -Encoding utf8` or write via the Write tool.

## macroScript (.mcr) Notes

A `.mcr` file registers a callable macro into Max's UI system. Minimum shape:

```maxscript
macroScript MyTool category:"YG Tools" tooltip:"My Tool" buttonText:"My Tool"
(
    fileIn (getFilenamePath (getSourceFileName()) + "MyTool.ms")
)
```

Using `getSourceFileName()` keeps the macro portable — it loads the sibling `.ms` from wherever the user installed the folder, so devs can keep editing the `.ms` in this repo and just re-run it.

## Testing

MaxScript has no standard unit-test framework. For non-trivial logic, keep pure functions in a struct and exercise them from the Listener:

```maxscript
fileIn @"d:\YGJeong\MaxScripts\<ToolName>\<ToolName>.ms"
MyTool.someFunction 1 2  -- expected: 3
```

Log assertions with `format` and fail loudly via `throw "message"` so regressions show up in the Listener.
