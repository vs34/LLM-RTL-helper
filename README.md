
# 🔧 LLM-Powered RTL Copilot for Neovim

## 📖 Overview

This project is an **AI-assisted RTL design and verification system** tightly integrated with **Neovim**.
It uses **Google’s API (LLM backend)** to generate, debug, and validate RTL code — while keeping full design context in a lightweight **JSON-based state system**.

Unlike black-box copilots, this tool works in a transparent, EDA-style flow:

* Tracks context across editing sessions using JSON.
* Generates **Verilog RTL** modules + **testbenches** automatically.
* Runs block-level simulation to catch errors early.
* Surfaces **errors, warnings, and suggestions inline in Neovim**.
* Provides a **Git-style review system** for accepting/rejecting AI suggestions.

The goal: **a Copilot for RTL engineers**, blending AI with the rigor of hardware design.

---

## ✨ Features

* 🔹 **Context Tracking**: JSON files capture design history, AI state, and verification logs.
* 🔹 **Error/Warning Mode**: Inline diagnostics appended at the end of RTL lines.
* 🔹 **Replace/Suggestion Mode**: AI suggestions shown in Git-style `++` / `--` patches, with interactive acceptance.
* 🔹 **Review Mode**: See all suggestions in a diff-like split window before applying.
* 🔹 **RTL Generation**: Generate synthesizable Verilog RTL from natural language or specs.
* 🔹 **Testbench Generation**: Auto-create Verilog testbenches for functional validation.
* 🔹 **Simulation & Testing**: Runs block-level simulation (e.g., via Icarus/Verilator) and surfaces errors/warnings.
* 🔹 **Undo-Friendly**: Every change is reversible, fits neatly into Neovim’s workflow.
* 🔹 **Language Agnostic**: Works not only with Verilog, but can be extended for VHDL, C, or Python.

---

## 🛠️ Workflow

1. **Write Prompt** → Describe RTL block or edit intent in Neovim.
2. **Generate** → AI produces RTL / testbench, saved in your buffer.
3. **Test** → Simulation auto-runs, errors/warnings stored in JSON.
4. **Annotate** → Inline diagnostics appear at offending lines.
5. **Review Suggestions** → AI proposes fixes (`++` additions, `--` removals).
6. **Accept/Reject** → Engineer decides patch-by-patch.
7. **Iterate** → JSON log keeps track of history, context, and decisions.

## 🚀 Getting Started

### Prerequisites

* Neovim (>=0.9)
* Python 3.x
* Verilator / Icarus Verilog (for simulation)
* Google API key (LLM backend)

### Usage

Inside Neovim:

```vim
:AIWarnings    " Show inline errors/warnings
:AISuggest     " Show AI code suggestions
:AIReview      " Review all suggestions Git-style
:AIApply       " Accept current suggestion
```

---

## 🎯 Vision

This project is more than just Copilot-in-Neovim.
It’s a **next-gen AI-EDA assistant**:

* Brings **Copilot-style AI** into hardware design.
* Embeds **EDA rigor**: simulation, testbenches, coverage.
* Makes **engineers stay in control** with review + patch workflows.


# AI Annotations — Neovim plugin

A small, self-contained Lua plugin for Neovim that loads a JSON file of annotations (errors, warnings, suggestions) and presents them inline as virtual-text + highlights. Suggestions can be applied/ skipped interactively (single or batch) and all edits are normal buffer edits (undoable with `u`). Designed to behave like a Git-diff + Copilot hybrid for staying in full control of AI edits.

> Works with `init.vim` or `init.lua`. Neovim **≥ 0.7** recommended.

---

## Features

* Load annotations from **one JSON file** (single communication bridge).
* Three core modes:

  * **Error/Warning Mode** — renders `❌`/`⚠️` inline at EOL + line highlights.
  * **Replace/Suggestion Mode** — shows suggestion previews (`++ ...`) inline; supports `replacement` or `diff`.
  * **Review Mode** — aggregated patch-like split window to apply/skip suggestions interactively.
* Apply suggestions with buffer edits (uses Neovim API so undo/redo works).
* Adjust subsequent suggestion line numbers after edits (simple delta).
* Export accepted suggestions to JSON.
* Multi-file and multi-language (JSON points to file paths).
* Safe: clamps out-of-range line numbers and avoids crashing on bad JSON.

---

## Installation

Place the plugin file in your Neovim Lua dir:

```bash
# recommended location
mkdir -p ~/.config/nvim/lua
# copy the plugin file as:
~/.config/nvim/lua/ai_annotations.lua
```

### Load from `init.vim`

Add this to `~/.config/nvim/init.vim`:

```vim
" for init.vim
lua require('ai_annotations').setup()
```

### Load from `init.lua`

Add:

```lua
require('ai_annotations').setup()
```

If your file sits outside `~/.config/nvim/lua/`, either move it (recommended) or add its folder to `package.path` / `&runtimepath` as explained in the plugin comments.

---

## Quick usage

1. Prepare a JSON file (see schema below).
2. In Neovim:

   ```vim
   :AILoad /full/path/to/annotations.json
   :AIWarnings           " render error/warning inline
   :AISuggest            " render suggestion inline
   :AIReview             " open review split (apply/skip)
   :AIApply <id>         " apply suggestion by id
   :AISkip <id>          " skip a suggestion
   :AIExport /tmp/out.json
   ```
3. In Review buffer:

   * `ga` — apply suggestion under cursor
   * `gs` — skip suggestion under cursor
   * `gA` — apply all suggestions
   * `q`  — close review buffer
4. Undo an applied suggestion with `u` like a normal edit.

---

## JSON schema (example)

Top-level object with `entries` array. Each entry should contain at least `id`, `file`, `start_line`, `type`.

```json
{
  "meta": { "generated_by": "ai-tool", "timestamp": "2025-09-08T00:00:00Z" },
  "entries": [
    {
      "id": "sug-001",
      "file": "/home/me/projects/foo/src/top.v",
      "start_line": 12,
      "end_line": 14,
      "type": "suggestion",
      "message": "Refactor this register update.",
      "replacement": "always_ff @(posedge clk) begin\n  if (reset) q <= 0;\n  else q <= d;\nend"
    },
    {
      "id": "err-001",
      "file": "/home/me/projects/foo/src/top.v",
      "start_line": 30,
      "type": "error",
      "message": "Missing semicolon"
    }
  ]
}
```

Notes:

* `start_line` and `end_line` are **1-based**.
* For suggestions you may provide `replacement` (full text) or `diff` (unified-diff style). The plugin will extract added lines (`+`) from the diff if present.
* File paths should match what Neovim sees — **absolute paths** are safest.

---

## Commands (user-facing)

* `:AILoad <path>` — load JSON and render.
* `:AIWarnings` — render only errors/warnings inline.
* `:AISuggest` — render only suggestions inline.
* `:AIReview` — open review split UI.
* `:AIApply <id>` — apply suggestion by id.
* `:AISkip <id>` — mark suggestion as skipped.
* `:AIExport <path>` — export applied suggestions to JSON.

---

## Implementation notes (high-level)

* Uses a single namespace for virtual text / highlights to allow clearing.
* Creates/loads buffers via `bufadd` + `bufload` to avoid stealing focus.
* Always clamps 0-based line indexes with the current `nvim_buf_line_count` to prevent `Invalid 'line'` errors.
* Applies edits with `nvim_buf_set_lines` so edits are recorded in the normal undo tree (`u` works).
* Adjusts later entry line numbers on change by a simple `delta` (naive but practical).
* Review panel is a scratch buffer and has local keymaps for quick actions.

---

## Troubleshooting

**`module 'ai_annotations' not found`**

* Ensure plugin file is at `~/.config/nvim/lua/ai_annotations.lua` and your `require` matches the filename.
* If kept elsewhere, add its directory to `package.path` or `runtimepath` in your `init.vim`.

**`E5108: Invalid 'line': out of range`**

* Happens when JSON `start_line` is greater than file length or < 1.
* Use absolute paths and ensure `start_line` uses 1-based indexing.
* Plugin clamps line numbers, but sanity-check the JSON if results look wrong.

**No warnings/suggestions visible**

* Run `:lua print(vim.inspect(require('ai_annotations').data.entries))` to confirm JSON loaded.
* Use `:AIWarnings` / `:AISuggest` individually to test.
* If both were rendered but disappeared, call `:AIWarnings` again; plugin also provides `render_all()` via `:AILoad` which clears namespace once and then shows both.

**Anchors drift after edits**

* The plugin uses line-number anchoring. If the file changed externally since JSON generation, anchor offsets may be off. Prefer generating JSON on up-to-date files or use context anchoring logic (future enhancement).

---

## Extending / Development

Ideas and possible improvements:

* Integrate with `vim.diagnostic.set()` so entries appear in `:lopen` / quickfix.
* Use fuzzy-text anchors (context lines) instead of line numbers for robustness.
* Parse and apply full unified patches (`git apply` style) instead of naive `+` extraction.
* Add sign-column icons for quick scanning.
* Group multiple applied edits into a single undo step if desired.
* Convert to proper plugin repo with `README.md`, license, and tests.

---

## Example: minimal `init.vim` snippet

```vim
" init.vim
" place ai_annotations.lua at ~/.config/nvim/lua/ai_annotations.lua
lua require('ai_annotations').setup()
```

If your module file is named `ai_annotation.lua` (singular), require with that name:

```vim
lua require('ai_annotation').setup()
```

