# conflict-ink.nvim

Enhanced visual styling and smart resolution for git merge conflicts in Neovim.

<!-- TODO: add screenshot -->

## Features

- **Overlay labels** — replaces raw `<<<<<<<`/`>>>>>>>` markers with readable labels
- **Theme-aware highlights** — distinct colors for ours/theirs/base sections, adapts to dark and light colorschemes
- **Keybinding hints** — right-aligned virtual text with conflict counter `(1/3)` shown when cursor enters a conflict
- **Smart auto-resolve** — merges non-overlapping changes automatically using the git index (no `diff3` config needed)
- **Diff3 support** — detects and highlights `|||||||` base sections
- **LSP diagnostic suppression** — optionally hides noisy LSP errors while conflicts exist, restores when resolved
- **Statusline component** — conflict count for lualine/heirline integration
- **Resolve notification** — notifies when all conflicts in a buffer have been resolved

## Requirements

- Neovim >= 0.10

## Installation

### lazy.nvim

```lua
{
  "andremaeland/conflict-ink.nvim",
  event = "BufReadPost",
  opts = {},
}
```

## Configuration

All options with defaults:

```lua
require("conflict-ink").setup({
  enabled = true,

  -- Override any highlight (omitted keys use theme-aware defaults)
  highlights = {
    -- current        = { bg = "#2D4A2D", bold = true },
    -- current_label  = { bg = "#385C38", bold = true },
    -- incoming       = { bg = "#3D2D5C", bold = true },
    -- incoming_label = { bg = "#4A3870", bold = true },
    -- base           = { bg = "#3B3926", bold = true },
    -- base_label     = { bg = "#4A4830", bold = true },
    -- hint           = { link = "Comment" },
    -- hint_key       = { link = "Keyword" },
  },

  mappings = {
    ours          = "co",
    theirs        = "ct",
    both          = "cb",
    none          = "c0",
    next_conflict = "]x",
    prev_conflict = "[x",
  },

  default_mappings         = true,
  hint_enabled             = true,
  suppress_lsp_diagnostics = false,
})
```

## Mappings

Buffer-local mappings are set automatically when a file contains conflicts.

| Key | Action |
|-----|--------|
| `co` | Accept ours (current) |
| `ct` | Accept theirs (incoming) |
| `cb` | Keep both sides |
| `c0` | Remove both sides |
| `]x` | Jump to next conflict |
| `[x` | Jump to previous conflict |

Set `default_mappings = false` to disable and define your own.

## Commands

| Command | Description |
|---------|-------------|
| `:ConflictInkResolve` | Smart auto-resolve non-overlapping conflicts |
| `:ConflictInkOurs` | Accept ours for conflict under cursor |
| `:ConflictInkTheirs` | Accept theirs for conflict under cursor |
| `:ConflictInkBoth` | Keep both sides |
| `:ConflictInkNone` | Remove both sides |
| `:ConflictInkNext` | Jump to next conflict |
| `:ConflictInkPrev` | Jump to previous conflict |
| `:ConflictInkAllOurs` | Accept ours for all conflicts |
| `:ConflictInkAllTheirs` | Accept theirs for all conflicts |
| `:ConflictInkRefresh` | Re-scan buffer for conflicts |

## Smart Resolve

`:ConflictInkResolve` automatically merges conflicts where both sides made changes to different lines. It works by:

1. Fetching the base (common ancestor), ours, and theirs versions from the git index
2. Diffing each side against the base to identify what changed
3. Merging changes that don't overlap
4. Leaving truly conflicting changes as-is

This does **not** require `git config merge.conflictstyle diff3` — the base is fetched directly from the git index.

## Statusline

A component is provided for statusline integration:

```lua
-- lualine
require("lualine").setup({
  sections = {
    lualine_x = { require("conflict-ink").status },
  },
})
```

Returns `"3 conflicts"` when conflicts exist, or `""` when none.

## Inspiration

- Conflict UI styling inspired by [avante.nvim](https://github.com/yetone/avante.nvim)
- Smart resolve inspired by the merge conflict resolver in JetBrains IDEs
- Keybinding conventions follow [git-conflict.nvim](https://github.com/akinsho/git-conflict.nvim)

## License

MIT
