local M = {}

local MAX_FILE_SIZE = 1024 * 1024 -- 1 MB

--- Build quickfix items from a list of absolute file paths.
--- Note: rg respects .gitignore by default, so conflicted files matching ignore rules won't appear.
--- @param paths string[]
--- @return table[]
function M.build_items(paths)
  local parser = require("conflict-ink.parser")
  local qf_items = {}

  for _, abs_path in ipairs(paths) do
    local stat = vim.uv.fs_stat(abs_path)
    if stat and stat.size > MAX_FILE_SIZE then
      vim.notify("conflict-ink: skipping large file: " .. abs_path, vim.log.levels.WARN)
    else
      local lines = vim.fn.readfile(abs_path)
      local conflicts = parser.parse_lines(lines)

      for i, conflict in ipairs(conflicts) do
        table.insert(qf_items, {
          filename = abs_path,
          lnum = conflict.start + 1, -- parse_lines returns 0-indexed; quickfix expects 1-indexed
          col = 1,
          text = string.format("[%d/%d] %s", i, #conflicts, conflict.ours_label),
        })
      end
    end
  end

  return qf_items
end

--- Populate the quickfix list with all conflicts found in the git repository.
function M.populate()
  if vim.fn.executable("rg") == 0 then
    vim.notify("conflict-ink: ripgrep (rg) is required but not installed", vim.log.levels.ERROR)
    return
  end

  local git_root_result = vim.fn.systemlist("git rev-parse --show-toplevel")
  if vim.v.shell_error ~= 0 then
    vim.notify("conflict-ink: not a git repository", vim.log.levels.WARN)
    return
  end
  local git_root = git_root_result[1]

  local conflicted_files = vim.fn.systemlist(
    "rg --files-with-matches '^<<<<<<<' " .. vim.fn.shellescape(git_root)
  )
  if #conflicted_files == 0 then
    vim.notify("conflict-ink: no conflicted files", vim.log.levels.INFO)
    return
  end

  local qf_items = M.build_items(conflicted_files)

  if #qf_items == 0 then
    vim.notify("conflict-ink: no conflicts found", vim.log.levels.INFO)
    return
  end

  vim.fn.setqflist({}, "r", { title = "Conflicts", items = qf_items })
  vim.cmd("copen")
end

return M
