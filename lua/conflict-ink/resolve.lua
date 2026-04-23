local M = {}

local parser = require("conflict-ink.parser")
local render = require("conflict-ink.render")

--- Get the directory containing a buffer's file.
--- @param bufnr number
--- @return string|nil
local function buf_dir(bufnr)
  local fullpath = vim.api.nvim_buf_get_name(bufnr)
  if fullpath == "" then
    return nil
  end
  return vim.fn.fnamemodify(fullpath, ":h")
end

--- Get the git-relative path for a buffer.
--- @param bufnr number
--- @param dir string
--- @return string|nil
local function git_rel_path(bufnr, dir)
  local fullpath = vim.api.nvim_buf_get_name(bufnr)
  local result = vim.fn.systemlist({ "git", "-C", dir, "ls-files", "--full-name", fullpath })
  if vim.v.shell_error ~= 0 or #result == 0 then
    return nil
  end
  return result[1]
end

--- Fetch a file version from the git index.
--- Stage 1 = base, 2 = ours, 3 = theirs.
--- @param dir string
--- @param relpath string
--- @param stage number
--- @return string|nil
local function git_show_stage(dir, relpath, stage)
  local result = vim.fn.system({ "git", "-C", dir, "show", ":" .. stage .. ":" .. relpath })
  if vim.v.shell_error ~= 0 then
    return nil
  end
  return result
end

--- Write content to a temp file and return the path.
--- @param content string
--- @param name string
--- @return string
local function write_tmp(content, name)
  local path = vim.fn.tempname() .. "-" .. name
  local f = io.open(path, "w")
  if f then
    f:write(content)
    f:close()
  end
  return path
end

--- Parse diff3 output to extract base content per conflict.
--- Returns a list of conflicts with ours, base, theirs line tables.
--- @param lines string[]
--- @return table[]
local function parse_diff3_conflicts(lines)
  local conflicts = {}
  local current = nil
  local section = nil

  for _, line in ipairs(lines) do
    if line:match("^<<<<<<<") then
      current = { ours = {}, base = {}, theirs = {} }
      section = "ours"
    elseif current and line:match("^|||||||") then
      section = "base"
    elseif current and line:match("^=======") then
      section = "theirs"
    elseif current and line:match("^>>>>>>>") then
      table.insert(conflicts, current)
      current = nil
      section = nil
    elseif current and section then
      table.insert(current[section], line)
    end
  end

  return conflicts
end

--- Try to smart-merge a single conflict using the base.
--- Returns merged lines if non-overlapping, or nil if truly conflicting.
--- @param ours string[]
--- @param base string[]
--- @param theirs string[]
--- @return string[]|nil
local function try_merge(ours, base, theirs)
  local base_text = table.concat(base, "\n") .. "\n"
  local ours_text = table.concat(ours, "\n") .. "\n"
  local theirs_text = table.concat(theirs, "\n") .. "\n"

  -- If one side is identical to base, the other side's changes win
  if ours_text == base_text then
    return theirs
  end
  if theirs_text == base_text then
    return ours
  end

  -- If both sides made identical changes, either one works
  if ours_text == theirs_text then
    return ours
  end

  -- Try line-level merge: apply non-overlapping changes from both sides
  local ours_diff = vim.diff(base_text, ours_text, { result_type = "indices" })
  local theirs_diff = vim.diff(base_text, theirs_text, { result_type = "indices" })

  if not ours_diff or not theirs_diff then
    return nil
  end

  -- Check for overlapping hunks
  for _, oh in ipairs(ours_diff) do
    local o_start, o_count = oh[1], oh[2]
    local o_end = o_start + math.max(o_count - 1, 0)
    for _, th in ipairs(theirs_diff) do
      local t_start, t_count = th[1], th[2]
      local t_end = t_start + math.max(t_count - 1, 0)
      if o_start <= t_end and t_start <= o_end then
        return nil -- overlapping changes, can't auto-merge
      end
    end
  end

  -- Non-overlapping: apply both sets of changes to the base
  -- Build a map of base line → replacement lines
  local replacements = {}

  for _, oh in ipairs(ours_diff) do
    local b_start, b_count, a_start, a_count = oh[1], oh[2], oh[3], oh[4]
    local new_lines = {}
    for j = 0, a_count - 1 do
      table.insert(new_lines, ours[a_start + j])
    end
    replacements[b_start] = { b_count = b_count, lines = new_lines }
  end

  for _, th in ipairs(theirs_diff) do
    local b_start, b_count, a_start, a_count = th[1], th[2], th[3], th[4]
    local new_lines = {}
    for j = 0, a_count - 1 do
      table.insert(new_lines, theirs[a_start + j])
    end
    replacements[b_start] = { b_count = b_count, lines = new_lines }
  end

  -- Reconstruct merged result from base + replacements
  local merged = {}
  local i = 1
  while i <= #base do
    if replacements[i] then
      local r = replacements[i]
      vim.list_extend(merged, r.lines)
      i = i + math.max(r.b_count, 1)
    else
      table.insert(merged, base[i])
      i = i + 1
    end
  end

  return merged
end

--- Attempt to auto-resolve conflicts in the current buffer.
--- Resolves non-overlapping changes, leaves true conflicts.
--- @param bufnr number|nil
--- @return number resolved count, number total count
function M.resolve(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  local dir = buf_dir(bufnr)
  if not dir then
    vim.notify("conflict-ink: buffer has no file path", vim.log.levels.WARN)
    return 0, 0
  end

  local relpath = git_rel_path(bufnr, dir)
  if not relpath then
    vim.notify("conflict-ink: not a git-tracked file", vim.log.levels.WARN)
    return 0, 0
  end

  -- Fetch base, ours, theirs from git index
  local base_content = git_show_stage(dir, relpath, 1)
  local ours_content = git_show_stage(dir, relpath, 2)
  local theirs_content = git_show_stage(dir, relpath, 3)

  if not base_content or not ours_content or not theirs_content then
    vim.notify("conflict-ink: could not fetch merge stages from git index", vim.log.levels.WARN)
    return 0, 0
  end

  -- Write to temp files and run git merge-file with diff3
  local base_tmp = write_tmp(base_content, "base")
  local ours_tmp = write_tmp(ours_content, "ours")
  local theirs_tmp = write_tmp(theirs_content, "theirs")

  local merged = vim.fn.system({
    "git", "merge-file", "-p", "--diff3",
    ours_tmp, base_tmp, theirs_tmp,
  })

  -- Clean up temp files
  os.remove(base_tmp)
  os.remove(ours_tmp)
  os.remove(theirs_tmp)

  -- Parse the diff3 output to get base per conflict
  local merged_lines = vim.split(merged, "\n", { plain = true })
  if merged_lines[#merged_lines] == "" then
    table.remove(merged_lines)
  end
  local diff3_conflicts = parse_diff3_conflicts(merged_lines)

  -- Now match against current buffer conflicts and try to resolve
  local buf_conflicts = parser.parse(bufnr)
  local resolved = 0
  local total = #buf_conflicts

  -- Resolve from bottom to top
  for i = #buf_conflicts, 1, -1 do
    local c = buf_conflicts[i]
    local dc = diff3_conflicts[i]
    if dc then
      local result = try_merge(dc.ours, dc.base, dc.theirs)
      if result then
        vim.api.nvim_buf_set_lines(bufnr, c.start, c.finish + 1, false, result)
        resolved = resolved + 1
      end
    end
  end

  render.refresh(bufnr, true)

  local remaining = total - resolved
  if remaining > 0 then
    vim.notify(
      string.format("conflict-ink: resolved %d/%d conflicts (%d remaining)", resolved, total, remaining),
      vim.log.levels.INFO
    )
  end

  return resolved, total
end

return M
