local M = {}

local MARKERS = {
  ours = "^<<<<<<<",
  base = "^|||||||",
  separator = "^=======",
  theirs = "^>>>>>>>",
}

--- Parse a buffer for git conflict markers.
--- Supports both standard and diff3 (||||||| base) conflict styles.
--- @param bufnr number|nil Buffer number (default: current)
--- @return table[] List of conflict blocks (0-indexed line numbers):
---   - start: <<<<<<< line
---   - base: ||||||| line (nil if not diff3)
---   - separator: ======= line
---   - finish: >>>>>>> line
---   - ours_label: text of the <<<<<<< line
---   - theirs_label: text of the >>>>>>> line
---   - base_label: text of the ||||||| line (nil if not diff3)
function M.parse(bufnr)
  bufnr = bufnr or 0
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local conflicts = {}
  local current = nil

  for i, line in ipairs(lines) do
    local lnum = i - 1
    if line:match(MARKERS.ours) then
      current = { start = lnum, ours_label = line }
    elseif current and not current.separator and line:match(MARKERS.base) then
      current.base = lnum
      current.base_label = line
    elseif current and line:match(MARKERS.separator) then
      current.separator = lnum
    elseif current and current.separator and line:match(MARKERS.theirs) then
      current.finish = lnum
      current.theirs_label = line
      table.insert(conflicts, current)
      current = nil
    end
  end

  return conflicts
end

return M
