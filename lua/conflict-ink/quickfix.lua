local M = {}

--- Populate the quickfix list with all conflicts found in the git repository.
function M.populate()
  local git_root_result = vim.fn.systemlist("git rev-parse --show-toplevel")
  if vim.v.shell_error ~= 0 then
    vim.notify("conflict-ink: not a git repository", vim.log.levels.WARN)
    return
  end
  local git_root = git_root_result[1]

  local conflicted_files = vim.fn.systemlist(
    "rg --files-with-matches --multiline '^<<<<<<<' " .. vim.fn.shellescape(git_root)
  )
  if #conflicted_files == 0 then
    vim.notify("conflict-ink: no conflicted files", vim.log.levels.INFO)
    return
  end

  local parser = require("conflict-ink.parser")
  local qf_items = {}

  for _, abs_path in ipairs(conflicted_files) do
    local lines = vim.fn.readfile(abs_path)
    local conflicts = parser.parse_lines(lines)

    for i, conflict in ipairs(conflicts) do
      table.insert(qf_items, {
        filename = abs_path,
        lnum = conflict.start + 1,
        col = 1,
        text = string.format("[%d/%d] %s", i, #conflicts, conflict.ours_label),
      })
    end
  end

  if #qf_items == 0 then
    vim.notify("conflict-ink: no conflicts found", vim.log.levels.INFO)
    return
  end

  vim.fn.setqflist({}, "r", { title = "Conflicts", items = qf_items })
  vim.cmd("copen")
end

return M
