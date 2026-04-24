local M = {}

M.config = {}

local defaults = {
  enabled = true,
  highlights = {},
  mappings = {
    ours = "co",
    theirs = "ct",
    both = "cb",
    none = "c0",
    next_conflict = "]x",
    prev_conflict = "[x",
  },
  default_mappings = true,
  hint_enabled = true,
  suppress_lsp_diagnostics = false,
}

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", defaults, opts or {})

  if not M.config.enabled then
    return
  end

  require("conflict-ink.highlights").setup(M.config.highlights)

  local render = require("conflict-ink.render")
  local actions = require("conflict-ink.actions")

  local group = vim.api.nvim_create_augroup("ConflictInk", { clear = true })

  -- Attach to buffers for on_lines change detection (handles undo/redo)
  vim.api.nvim_create_autocmd("BufReadPost", {
    group = group,
    callback = function(args)
      render.attach(args.buf)
      render.refresh(args.buf, true)
      if M.config.default_mappings then
        local conflicts = render.get_conflicts(args.buf)
        if conflicts and #conflicts > 0 then
          actions.set_buf_mappings(args.buf, M.config.mappings)
        end
      end
    end,
  })

  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
    group = group,
    callback = function(args)
      if M.config.hint_enabled then
        render.update_hint(args.buf)
      end
    end,
  })

  vim.api.nvim_create_autocmd("WinLeave", {
    group = group,
    callback = function(args)
      render.clear_hint(args.buf)
    end,
  })

  vim.api.nvim_create_autocmd("ColorScheme", {
    group = group,
    callback = function()
      require("conflict-ink.highlights").setup(M.config.highlights)
    end,
  })

  vim.api.nvim_create_autocmd("VimEnter", {
    group = group,
    callback = function()
      require("conflict-ink.highlights").setup(M.config.highlights)
    end,
  })

  vim.api.nvim_create_autocmd("OptionSet", {
    group = group,
    pattern = "background",
    callback = function()
      require("conflict-ink.highlights").setup(M.config.highlights)
    end,
  })

  -- Attach and refresh current buffer immediately if already loaded
  local bufnr = vim.api.nvim_get_current_buf()
  if vim.bo[bufnr].buftype == "" and vim.api.nvim_buf_is_loaded(bufnr) then
    render.attach(bufnr)
    render.refresh(bufnr, true)
    if M.config.default_mappings then
      local conflicts = render.get_conflicts(bufnr)
      if conflicts and #conflicts > 0 then
        actions.set_buf_mappings(bufnr, M.config.mappings)
      end
    end
  end
end

--- Statusline component. Returns conflict count string or empty string.
--- Usage with lualine: { "require('conflict-ink').status()" }
--- @return string
function M.status()
  local render = require("conflict-ink.render")
  local conflicts = render.get_conflicts(vim.api.nvim_get_current_buf())
  if not conflicts or #conflicts == 0 then
    return ""
  end
  return #conflicts .. " conflict" .. (#conflicts > 1 and "s" or "")
end

return M
