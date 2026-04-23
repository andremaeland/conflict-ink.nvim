local M = {}

local parser = require("conflict-ink.parser")
local hl = require("conflict-ink.highlights")

local NS = vim.api.nvim_create_namespace("conflict-ink")
local HINT_NS = vim.api.nvim_create_namespace("conflict-ink-hint")
local PRIORITY = (vim.hl or vim.highlight).priorities.user

--- Buffer-local conflict state: bufnr -> conflict list
local buf_state = {}

--- Track changedtick per buffer to avoid redundant re-renders
local buf_tick = {}

--- Track buffers where we've suppressed LSP diagnostics
local lsp_suppressed = {}

--- Get the current window width for padding overlay labels.
local function win_width()
  return vim.api.nvim_win_get_width(0)
end

--- Draw an overlay label that replaces the marker line visually.
--- Pads the label text to the full window width so background fills the line.
local function draw_label(bufnr, lnum, label_text, hl_group)
  local padding = win_width() - vim.api.nvim_strwidth(label_text)
  if padding < 0 then
    padding = 0
  end
  vim.api.nvim_buf_set_extmark(bufnr, NS, lnum, 0, {
    hl_group = hl_group,
    virt_text = { { label_text .. string.rep(" ", padding), hl_group } },
    virt_text_pos = "overlay",
    priority = PRIORITY,
  })
end

--- Highlight a range of content lines.
local function hl_range(bufnr, range_start, range_end, hl_group)
  if range_start >= range_end then
    return
  end
  vim.api.nvim_buf_set_extmark(bufnr, NS, range_start, 0, {
    end_row = range_end,
    hl_group = hl_group,
    hl_eol = true,
    hl_mode = "combine",
    priority = PRIORITY,
  })
end

--- Refresh conflict highlights for a buffer.
--- Skips if changedtick is unchanged unless force is true.
--- @param bufnr number
--- @param force boolean|nil
--- @return boolean updated Whether extmarks were actually refreshed
function M.refresh(bufnr, force)
  if vim.bo[bufnr].buftype ~= "" then
    return false
  end

  local tick = vim.api.nvim_buf_get_changedtick(bufnr)
  if not force and buf_tick[bufnr] == tick then
    return false
  end
  buf_tick[bufnr] = tick

  vim.api.nvim_buf_clear_namespace(bufnr, NS, 0, -1)
  vim.api.nvim_buf_clear_namespace(bufnr, HINT_NS, 0, -1)

  local conflicts = parser.parse(bufnr)
  buf_state[bufnr] = conflicts

  -- Suppress/restore LSP diagnostics based on conflict presence
  local config = require("conflict-ink").config
  if config.suppress_lsp_diagnostics then
    M.update_lsp_suppression(bufnr, #conflicts > 0)
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  for _, c in ipairs(conflicts) do
    -- <<<<<<< marker → overlay with "(Current changes)" label
    local current_label = lines[c.start + 1] .. " · Your changes"
    draw_label(bufnr, c.start, current_label, hl.CURRENT_LABEL)

    -- Ours content: from <<<<<<< to either ||||||| (diff3) or =======
    local ours_end = c.base or c.separator
    hl_range(bufnr, c.start, ours_end, hl.CURRENT)

    -- Base section (diff3 only): between ||||||| and =======
    if c.base then
      local base_label = lines[c.base + 1] .. " · Common ancestor"
      draw_label(bufnr, c.base, base_label, hl.BASE_LABEL)
      hl_range(bufnr, c.base, c.separator, hl.BASE)
    end

    -- Theirs content (======= through >>>>>>>, inclusive of marker)
    hl_range(bufnr, c.separator + 1, c.finish + 1, hl.INCOMING)

    -- >>>>>>> marker → overlay with "(Incoming changes)" label
    local incoming_label = lines[c.finish + 1] .. " · Incoming changes"
    draw_label(bufnr, c.finish, incoming_label, hl.INCOMING_LABEL)
  end

  return true
end

--- Show or hide keybinding hint based on cursor position.
--- @param bufnr number
function M.update_hint(bufnr)
  vim.api.nvim_buf_clear_namespace(bufnr, HINT_NS, 0, -1)

  local conflicts = buf_state[bufnr]
  if not conflicts then
    return
  end

  local row = vim.api.nvim_win_get_cursor(0)[1] - 1

  for idx, c in ipairs(conflicts) do
    if row >= c.start and row <= c.finish then
      local config = require("conflict-ink").config
      local m = config.mappings
      local K = hl.HINT_KEY
      local H = hl.HINT
      local counter = string.format("(%d/%d) ", idx, #conflicts)
      vim.api.nvim_buf_set_extmark(bufnr, HINT_NS, c.start, 0, {
        virt_text = {
          { counter, K },
          { "[", H },
          { m.ours, K }, { ": ours", H },
          { " | ", H },
          { m.theirs, K }, { ": theirs", H },
          { " | ", H },
          { m.both, K }, { ": both", H },
          { " | ", H },
          { m.none, K }, { ": none", H },
          { " | ", H },
          { m.prev_conflict, K }, { "/", H }, { m.next_conflict, K }, { ": nav", H },
          { "]", H },
        },
        virt_text_pos = "right_align",
        priority = PRIORITY,
      })
      return
    end
  end
end

--- Get the conflict block under the cursor, if any.
--- @param bufnr number
--- @return table|nil
function M.get_conflict_at_cursor(bufnr)
  local conflicts = buf_state[bufnr]
  if not conflicts then
    return nil
  end

  local row = vim.api.nvim_win_get_cursor(0)[1] - 1
  for _, c in ipairs(conflicts) do
    if row >= c.start and row <= c.finish then
      return c
    end
  end
  return nil
end

--- Get all conflicts for a buffer.
--- @param bufnr number
--- @return table[]|nil
function M.get_conflicts(bufnr)
  return buf_state[bufnr]
end

--- Suppress or restore LSP diagnostics for a buffer.
--- @param bufnr number
--- @param suppress boolean
function M.update_lsp_suppression(bufnr, suppress)
  if suppress and not lsp_suppressed[bufnr] then
    lsp_suppressed[bufnr] = true
    vim.diagnostic.enable(false, { bufnr = bufnr })
  elseif not suppress and lsp_suppressed[bufnr] then
    lsp_suppressed[bufnr] = nil
    vim.diagnostic.enable(true, { bufnr = bufnr })
  end
end

--- Clear the keybinding hint (e.g. on WinLeave).
--- @param bufnr number
function M.clear_hint(bufnr)
  vim.api.nvim_buf_clear_namespace(bufnr, HINT_NS, 0, -1)
end

--- Attach to a buffer to detect all text changes including undo/redo.
--- @param bufnr number
function M.attach(bufnr)
  vim.api.nvim_buf_attach(bufnr, false, {
    on_lines = function(_, buf, _, first, last_orig, last_new, byte_count)
      if first == last_orig and last_orig == last_new and byte_count == 0 then
        return
      end
      vim.schedule(function()
        if vim.api.nvim_buf_is_valid(buf) then
          M.refresh(buf, true)
          M.update_hint(buf)
        end
      end)
    end,
    on_detach = function(_, buf)
      M.cleanup(buf)
    end,
  })
end

--- Clean up state for a wiped buffer.
--- @param bufnr number
function M.cleanup(bufnr)
  if lsp_suppressed[bufnr] then
    pcall(vim.diagnostic.enable, true, { bufnr = bufnr })
    lsp_suppressed[bufnr] = nil
  end
  buf_state[bufnr] = nil
  buf_tick[bufnr] = nil
end

return M
