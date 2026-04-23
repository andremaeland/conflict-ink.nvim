local M = {}

local render = require("conflict-ink.render")

--- Buffers that already have mappings set.
local mapped_bufs = {}

--- Accept the "ours" (current) side of the conflict under cursor.
function M.choose_ours(bufnr)
  local c = render.get_conflict_at_cursor(bufnr)
  if not c then
    return
  end
  local ours_end = c.base or c.separator
  local lines = vim.api.nvim_buf_get_lines(bufnr, c.start + 1, ours_end, false)
  vim.api.nvim_buf_set_lines(bufnr, c.start, c.finish + 1, false, lines)
  render.refresh(bufnr)
end

--- Accept the "theirs" (incoming) side of the conflict under cursor.
function M.choose_theirs(bufnr)
  local c = render.get_conflict_at_cursor(bufnr)
  if not c then
    return
  end
  local lines = vim.api.nvim_buf_get_lines(bufnr, c.separator + 1, c.finish, false)
  vim.api.nvim_buf_set_lines(bufnr, c.start, c.finish + 1, false, lines)
  render.refresh(bufnr)
end

--- Keep both sides of the conflict under cursor.
function M.choose_both(bufnr)
  local c = render.get_conflict_at_cursor(bufnr)
  if not c then
    return
  end
  local ours_end = c.base or c.separator
  local ours = vim.api.nvim_buf_get_lines(bufnr, c.start + 1, ours_end, false)
  local theirs = vim.api.nvim_buf_get_lines(bufnr, c.separator + 1, c.finish, false)
  local combined = vim.list_extend(ours, theirs)
  vim.api.nvim_buf_set_lines(bufnr, c.start, c.finish + 1, false, combined)
  render.refresh(bufnr)
end

--- Remove both sides of the conflict under cursor.
function M.choose_none(bufnr)
  local c = render.get_conflict_at_cursor(bufnr)
  if not c then
    return
  end
  vim.api.nvim_buf_set_lines(bufnr, c.start, c.finish + 1, false, {})
  render.refresh(bufnr)
end

--- Jump to the next conflict in the buffer.
function M.next_conflict()
  local bufnr = vim.api.nvim_get_current_buf()
  local conflicts = render.get_conflicts(bufnr)
  if not conflicts or #conflicts == 0 then
    return
  end

  local row = vim.api.nvim_win_get_cursor(0)[1] - 1
  for _, c in ipairs(conflicts) do
    if c.start > row then
      vim.api.nvim_win_set_cursor(0, { c.start + 1, 0 })
      return
    end
  end
  -- Wrap to first
  vim.api.nvim_win_set_cursor(0, { conflicts[1].start + 1, 0 })
end

--- Jump to the previous conflict in the buffer.
function M.prev_conflict()
  local bufnr = vim.api.nvim_get_current_buf()
  local conflicts = render.get_conflicts(bufnr)
  if not conflicts or #conflicts == 0 then
    return
  end

  local row = vim.api.nvim_win_get_cursor(0)[1] - 1
  for i = #conflicts, 1, -1 do
    if conflicts[i].start < row then
      vim.api.nvim_win_set_cursor(0, { conflicts[i].start + 1, 0 })
      return
    end
  end
  -- Wrap to last
  vim.api.nvim_win_set_cursor(0, { conflicts[#conflicts].start + 1, 0 })
end

--- Resolve all conflicts in the buffer by choosing ours.
function M.choose_all_ours(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local conflicts = render.get_conflicts(bufnr)
  if not conflicts then return end
  -- Resolve from bottom to top so line numbers stay valid
  for i = #conflicts, 1, -1 do
    local c = conflicts[i]
    local ours_end = c.base or c.separator
    local lines = vim.api.nvim_buf_get_lines(bufnr, c.start + 1, ours_end, false)
    vim.api.nvim_buf_set_lines(bufnr, c.start, c.finish + 1, false, lines)
  end
  render.refresh(bufnr, true)
end

--- Resolve all conflicts in the buffer by choosing theirs.
function M.choose_all_theirs(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local conflicts = render.get_conflicts(bufnr)
  if not conflicts then return end
  for i = #conflicts, 1, -1 do
    local c = conflicts[i]
    local lines = vim.api.nvim_buf_get_lines(bufnr, c.separator + 1, c.finish, false)
    vim.api.nvim_buf_set_lines(bufnr, c.start, c.finish + 1, false, lines)
  end
  render.refresh(bufnr, true)
end

--- Set buffer-local keymaps for conflict resolution.
--- @param bufnr number
--- @param maps table Mapping config from user setup
function M.set_buf_mappings(bufnr, maps)
  if mapped_bufs[bufnr] then
    return
  end
  mapped_bufs[bufnr] = true

  local function map(lhs, fn, desc)
    vim.keymap.set("n", lhs, fn, { buffer = bufnr, silent = true, desc = desc })
  end

  map(maps.ours, function() M.choose_ours(bufnr) end, "Conflict: choose ours")
  map(maps.theirs, function() M.choose_theirs(bufnr) end, "Conflict: choose theirs")
  map(maps.both, function() M.choose_both(bufnr) end, "Conflict: choose both")
  map(maps.none, function() M.choose_none(bufnr) end, "Conflict: choose none")
  map(maps.next_conflict, function() M.next_conflict() end, "Conflict: next")
  map(maps.prev_conflict, function() M.prev_conflict() end, "Conflict: prev")
end

return M
