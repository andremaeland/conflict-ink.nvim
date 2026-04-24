local M = {}

local parser = require("conflict-ink.parser")
local render = require("conflict-ink.render")
local hl = require("conflict-ink.highlights")

local NS = vim.api.nvim_create_namespace("conflict-ink-three-way")
local RESULT_NS = vim.api.nvim_create_namespace("conflict-ink-three-way-result")
local HINT_NS = vim.api.nvim_create_namespace("conflict-ink-three-way-hint")

local session = nil

-- ---------------------------------------------------------------------------
-- Aligned content builders
--
-- Both outer pane buffers have the SAME line count as the center (result)
-- buffer. Conflict markers and the opposite side's content are replaced with
-- empty lines so that line N in every pane refers to the same logical line,
-- and scrollbind gives perfect visual alignment without diffthis.
-- ---------------------------------------------------------------------------

-- Build the aligned ours buffer: ours content at its center positions,
-- theirs content + all marker lines replaced with empty strings.
local function build_ours_aligned(all_lines, conflicts)
  local out = {}
  local pos = 0
  for _, c in ipairs(conflicts) do
    for i = pos, c.start - 1 do          -- shared lines before conflict
      table.insert(out, all_lines[i + 1])
    end
    table.insert(out, "")                -- <<<<<<< → blank
    local ours_stop = c.base or c.separator
    for i = c.start + 1, ours_stop - 1 do  -- ours content (kept)
      table.insert(out, all_lines[i + 1])
    end
    if c.base then                        -- ||||||| + base content → blank
      for _ = c.base, c.separator - 1 do
        table.insert(out, "")
      end
    end
    table.insert(out, "")                -- ======= → blank
    for _ = c.separator + 1, c.finish - 1 do  -- theirs content → blank
      table.insert(out, "")
    end
    table.insert(out, "")                -- >>>>>>> → blank
    pos = c.finish + 1
  end
  for i = pos, #all_lines - 1 do        -- trailing shared lines
    table.insert(out, all_lines[i + 1])
  end
  return out
end

-- Build the aligned theirs buffer: theirs content at its center positions,
-- ours content + all marker lines replaced with empty strings.
local function build_theirs_aligned(all_lines, conflicts)
  local out = {}
  local pos = 0
  for _, c in ipairs(conflicts) do
    for i = pos, c.start - 1 do          -- shared lines before conflict
      table.insert(out, all_lines[i + 1])
    end
    table.insert(out, "")                -- <<<<<<< → blank
    local ours_stop = c.base or c.separator
    for _ = c.start + 1, ours_stop - 1 do  -- ours content → blank
      table.insert(out, "")
    end
    if c.base then                        -- ||||||| + base content → blank
      for _ = c.base, c.separator - 1 do
        table.insert(out, "")
      end
    end
    table.insert(out, "")                -- ======= → blank
    for i = c.separator + 1, c.finish - 1 do  -- theirs content (kept)
      table.insert(out, all_lines[i + 1])
    end
    table.insert(out, "")                -- >>>>>>> → blank
    pos = c.finish + 1
  end
  for i = pos, #all_lines - 1 do        -- trailing shared lines
    table.insert(out, all_lines[i + 1])
  end
  return out
end

-- ---------------------------------------------------------------------------
-- Decorations: center result buffer
-- ---------------------------------------------------------------------------

local function decorate_result(result_bufnr)
  vim.api.nvim_buf_clear_namespace(result_bufnr, RESULT_NS, 0, -1)

  local conflicts = parser.parse(result_bufnr)
  if #conflicts == 0 then return end

  local width = 80
  if session and vim.api.nvim_win_is_valid(session.center_win) then
    width = vim.api.nvim_win_get_width(session.center_win)
  end

  local lines = vim.api.nvim_buf_get_lines(result_bufnr, 0, -1, false)
  local prio = (vim.hl or vim.highlight).priorities.user

  local function overlay(lnum, text, hl_group)
    local pad = math.max(0, width - vim.api.nvim_strwidth(text))
    vim.api.nvim_buf_set_extmark(result_bufnr, RESULT_NS, lnum, 0, {
      virt_text = { { text .. string.rep(" ", pad), hl_group } },
      virt_text_pos = "overlay",
      priority = prio,
    })
  end

  local function bg_range(start_lnum, end_lnum, hl_group)
    if start_lnum >= end_lnum then return end
    vim.api.nvim_buf_set_extmark(result_bufnr, RESULT_NS, start_lnum, 0, {
      end_row = end_lnum,
      hl_group = hl_group,
      hl_eol = true,
      hl_mode = "combine",
      priority = prio - 1,
    })
  end

  for _, c in ipairs(conflicts) do
    local ours_label = (lines[c.start + 1] or ""):match("^<<<<<<<%s*(.-)%s*$") or ""
    local ours_text = " ▶  Ours" .. (ours_label ~= "" and (" — " .. ours_label) or "")
    local ours_fill = string.rep("─", math.max(1, width - vim.api.nvim_strwidth(ours_text) - 1))
    overlay(c.start, ours_text .. " " .. ours_fill, hl.CURRENT_LABEL)
    bg_range(c.start + 1, c.base or c.separator, hl.CURRENT)

    if c.base then
      local base_text = "  Base"
      local base_fill = string.rep("─", math.max(1, width - vim.api.nvim_strwidth(base_text) - 1))
      overlay(c.base, base_text .. " " .. base_fill, hl.BASE_LABEL)
      bg_range(c.base + 1, c.separator, hl.BASE)
    end

    overlay(c.separator, string.rep("─", width), hl.INCOMING_LABEL)
    bg_range(c.separator + 1, c.finish, hl.INCOMING)

    local theirs_label = (lines[c.finish + 1] or ""):match("^>>>>>>>%s*(.-)%s*$") or ""
    local theirs_text = " ◀  Theirs" .. (theirs_label ~= "" and (" — " .. theirs_label) or "")
    local theirs_fill = string.rep("─", math.max(1, width - vim.api.nvim_strwidth(theirs_text) - 1))
    overlay(c.finish, theirs_text .. " " .. theirs_fill, hl.INCOMING_LABEL)
  end
end

-- ---------------------------------------------------------------------------
-- Decorations: outer panes
--
-- Because the aligned buffers share line positions with the center, we can
-- use the conflict positions from the center directly.
-- ---------------------------------------------------------------------------

local function decorate_ours(ours_bufnr, conflicts)
  vim.api.nvim_buf_clear_namespace(ours_bufnr, NS, 0, -1)
  local prio = (vim.hl or vim.highlight).priorities.user
  for _, c in ipairs(conflicts) do
    local first = c.start + 1
    local last = c.base or c.separator
    if last > first then
      vim.api.nvim_buf_set_extmark(ours_bufnr, NS, first, 0, {
        end_row = last,
        hl_group = hl.CURRENT,
        hl_eol = true,
        hl_mode = "combine",
        priority = prio - 1,
      })
      vim.api.nvim_buf_set_extmark(ours_bufnr, NS, first, 0, {
        sign_text = "▶▶",
        sign_hl_group = hl.CURRENT_LABEL,
        priority = prio,
      })
    end
  end
end

local function decorate_theirs(theirs_bufnr, conflicts)
  vim.api.nvim_buf_clear_namespace(theirs_bufnr, NS, 0, -1)
  local prio = (vim.hl or vim.highlight).priorities.user
  for _, c in ipairs(conflicts) do
    local first = c.separator + 1
    local last = c.finish
    if last > first then
      vim.api.nvim_buf_set_extmark(theirs_bufnr, NS, first, 0, {
        end_row = last,
        hl_group = hl.INCOMING,
        hl_eol = true,
        hl_mode = "combine",
        priority = prio - 1,
      })
      vim.api.nvim_buf_set_extmark(theirs_bufnr, NS, first, 0, {
        sign_text = "◀◀",
        sign_hl_group = hl.INCOMING_LABEL,
        priority = prio,
      })
    end
  end
end

-- ---------------------------------------------------------------------------
-- Conflict navigation
-- ---------------------------------------------------------------------------

local function conflict_at_cursor(result_bufnr)
  local conflicts = parser.parse(result_bufnr)
  local row = vim.api.nvim_win_get_cursor(0)[1] - 1
  for _, c in ipairs(conflicts) do
    if row >= c.start and row <= c.finish then
      return c
    end
  end
  return nil
end

local function nav_next(result_bufnr)
  local conflicts = parser.parse(result_bufnr)
  if #conflicts == 0 then
    vim.notify("conflict-ink: all conflicts resolved", vim.log.levels.INFO)
    return
  end
  local row = vim.api.nvim_win_get_cursor(0)[1] - 1
  for _, c in ipairs(conflicts) do
    if c.start > row then
      vim.api.nvim_win_set_cursor(0, { c.start + 1, 0 })
      return
    end
  end
  vim.api.nvim_win_set_cursor(0, { conflicts[1].start + 1, 0 })
end

local function nav_prev(result_bufnr)
  local conflicts = parser.parse(result_bufnr)
  if #conflicts == 0 then return end
  local row = vim.api.nvim_win_get_cursor(0)[1] - 1
  for i = #conflicts, 1, -1 do
    if conflicts[i].start < row then
      vim.api.nvim_win_set_cursor(0, { conflicts[i].start + 1, 0 })
      return
    end
  end
  vim.api.nvim_win_set_cursor(0, { conflicts[#conflicts].start + 1, 0 })
end

-- ---------------------------------------------------------------------------
-- Cursor hint (shown when cursor is inside a conflict in the result buffer)
-- ---------------------------------------------------------------------------

local function update_hint(result_bufnr)
  vim.api.nvim_buf_clear_namespace(result_bufnr, HINT_NS, 0, -1)
  local conflicts = parser.parse(result_bufnr)
  if #conflicts == 0 then return end
  local row = vim.api.nvim_win_get_cursor(0)[1] - 1
  local K, H = hl.HINT_KEY, hl.HINT
  for idx, c in ipairs(conflicts) do
    if row >= c.start and row <= c.finish then
      vim.api.nvim_buf_set_extmark(result_bufnr, HINT_NS, c.start, 0, {
        virt_text = {
          { string.format("(%d/%d) ", idx, #conflicts), K },
          { "[", H },
          { "co", K }, { ": ours", H },
          { "  ", H },
          { "ct", K }, { ": theirs", H },
          { "]", H },
        },
        virt_text_pos = "right_align",
        priority = (vim.hl or vim.highlight).priorities.user,
      })
      return
    end
  end
end

local function clear_hint(result_bufnr)
  vim.api.nvim_buf_clear_namespace(result_bufnr, HINT_NS, 0, -1)
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

-- Rebuild outer pane buffers from the current result buffer state and
-- re-decorate all panes. Called after any text change (resolution or undo).
local function resync_outer_panes()
  if not session then return end
  local s = session
  local current_lines = vim.api.nvim_buf_get_lines(s.result_bufnr, 0, -1, false)
  local conflicts = parser.parse(s.result_bufnr)

  local new_ours = build_ours_aligned(current_lines, conflicts)
  local new_theirs = build_theirs_aligned(current_lines, conflicts)

  vim.bo[s.ours_bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(s.ours_bufnr, 0, -1, false, new_ours)
  vim.bo[s.ours_bufnr].modifiable = false

  vim.bo[s.theirs_bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(s.theirs_bufnr, 0, -1, false, new_theirs)
  vim.bo[s.theirs_bufnr].modifiable = false

  decorate_result(s.result_bufnr)
  decorate_ours(s.ours_bufnr, conflicts)
  decorate_theirs(s.theirs_bufnr, conflicts)
end

-- Replace the conflict block in the result buffer; the TextChanged autocmd
-- will trigger resync_outer_panes to keep everything aligned.
local function apply_resolution(c, lines)
  vim.api.nvim_buf_set_lines(session.result_bufnr, c.start, c.finish + 1, false, lines)
end

function M.accept_ours()
  if not session then return end
  local c = conflict_at_cursor(session.result_bufnr)
  if not c then
    vim.notify("conflict-ink: cursor not inside a conflict", vim.log.levels.WARN)
    return
  end
  local stop = c.base or c.separator
  local lines = vim.api.nvim_buf_get_lines(session.result_bufnr, c.start + 1, stop, false)
  apply_resolution(c, lines)
end

function M.accept_theirs()
  if not session then return end
  local c = conflict_at_cursor(session.result_bufnr)
  if not c then
    vim.notify("conflict-ink: cursor not inside a conflict", vim.log.levels.WARN)
    return
  end
  local lines = vim.api.nvim_buf_get_lines(session.result_bufnr, c.separator + 1, c.finish, false)
  apply_resolution(c, lines)
end

function M.close()
  if not session then return end
  local s = session
  session = nil

  local result_lines = vim.api.nvim_buf_get_lines(s.result_bufnr, 0, -1, false)

  pcall(vim.api.nvim_set_current_tabpage, s.orig_tabpage)
  pcall(vim.cmd, "tabclose " .. vim.api.nvim_tabpage_get_number(s.merge_tabpage))

  if vim.api.nvim_buf_is_valid(s.orig_bufnr) then
    vim.api.nvim_buf_set_lines(s.orig_bufnr, 0, -1, false, result_lines)
    render.refresh(s.orig_bufnr, true)
  end

  for _, b in ipairs({ s.ours_bufnr, s.result_bufnr, s.theirs_bufnr }) do
    if vim.api.nvim_buf_is_valid(b) then
      vim.api.nvim_buf_delete(b, { force = true })
    end
  end
end

--- Open the three-way merge view in a new tab.
--- Layout: Ours | Result | Theirs  (all buffers share the same line count for
--- perfect scrollbind alignment — no diffthis, no filler-line artifacts).
--- @param bufnr number|nil
function M.open(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  if session then
    if not vim.api.nvim_tabpage_is_valid(session.merge_tabpage) then
      session = nil
    else
      vim.notify("conflict-ink: merge view already open", vim.log.levels.WARN)
      vim.api.nvim_set_current_tabpage(session.merge_tabpage)
      return
    end
  end

  if vim.bo[bufnr].buftype ~= "" then
    vim.notify("conflict-ink: not a file buffer", vim.log.levels.WARN)
    return
  end

  local conflicts = parser.parse(bufnr)
  if #conflicts == 0 then
    vim.notify("conflict-ink: no conflicts in buffer", vim.log.levels.INFO)
    return
  end

  local all_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local ours_lines = build_ours_aligned(all_lines, conflicts)
  local theirs_lines = build_theirs_aligned(all_lines, conflicts)

  local ours_label = (conflicts[1].ours_label or ""):match("^<<<<<<<%s*(.-)%s*$") or "ours"
  local theirs_label = (conflicts[1].theirs_label or ""):match("^>>>>>>>%s*(.-)%s*$") or "theirs"
  local filepath = vim.api.nvim_buf_get_name(bufnr)
  local filename = vim.fn.fnamemodify(filepath, ":t")
  local ft = vim.bo[bufnr].filetype
  local orig_tabpage = vim.api.nvim_get_current_tabpage()

  local function make_buf(lines, name, writable)
    local b = vim.api.nvim_create_buf(false, true)
    vim.bo[b].buftype = "nofile"
    vim.bo[b].swapfile = false
    vim.bo[b].buflisted = false
    vim.bo[b].bufhidden = "wipe"
    vim.api.nvim_buf_set_lines(b, 0, -1, false, lines)
    vim.bo[b].filetype = ft
    if not writable then
      vim.bo[b].modifiable = false
    end
    pcall(vim.api.nvim_buf_set_name, b, name)
    return b
  end

  local result_bufnr = make_buf(all_lines, filepath .. " [Result]", true)
  local ours_bufnr = make_buf(ours_lines, filepath .. " [Ours]", false)
  local theirs_bufnr = make_buf(theirs_lines, filepath .. " [Theirs]", false)

  vim.cmd("tabnew")
  local merge_tabpage = vim.api.nvim_get_current_tabpage()
  local center_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(center_win, result_bufnr)

  vim.cmd("leftabove vsplit")
  local left_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(left_win, ours_bufnr)

  vim.api.nvim_set_current_win(center_win)
  vim.cmd("rightbelow vsplit")
  local right_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(right_win, theirs_bufnr)

  for _, win in ipairs({ left_win, center_win, right_win }) do
    vim.wo[win].scrollbind = true
    vim.wo[win].cursorbind = true
    vim.wo[win].wrap = false
    vim.wo[win].foldmethod = "manual"
  end
  vim.wo[left_win].number = false
  vim.wo[center_win].number = true
  vim.wo[right_win].number = false
  vim.wo[left_win].signcolumn = "yes"
  vim.wo[center_win].signcolumn = "no"
  vim.wo[right_win].signcolumn = "yes"

  vim.wo[left_win].winbar = string.format(" ▶▶  Ours — %s", ours_label)
  vim.wo[center_win].winbar = string.format(" Result — %s", filename)
  vim.wo[right_win].winbar = string.format(" ◀◀  Theirs — %s", theirs_label)

  session = {
    orig_bufnr = bufnr,
    ours_bufnr = ours_bufnr,
    result_bufnr = result_bufnr,
    theirs_bufnr = theirs_bufnr,
    orig_tabpage = orig_tabpage,
    merge_tabpage = merge_tabpage,
    left_win = left_win,
    center_win = center_win,
    right_win = right_win,
  }

  decorate_result(result_bufnr)
  decorate_ours(ours_bufnr, conflicts)
  decorate_theirs(theirs_bufnr, conflicts)

  local function map(lhs, fn, desc)
    vim.keymap.set("n", lhs, fn, { buffer = result_bufnr, silent = true, desc = desc })
  end
  map("co", M.accept_ours, "3-way: accept ours")
  map("ct", M.accept_theirs, "3-way: accept theirs")
  map("]x", function() nav_next(result_bufnr) end, "3-way: next conflict")
  map("[x", function() nav_prev(result_bufnr) end, "3-way: prev conflict")
  map("q", M.close, "3-way: close and apply result")

  vim.api.nvim_create_autocmd("TextChanged", {
    buffer = result_bufnr,
    callback = resync_outer_panes,
  })

  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
    buffer = result_bufnr,
    callback = function() update_hint(result_bufnr) end,
  })

  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = result_bufnr,
    callback = function() clear_hint(result_bufnr) end,
  })

  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = result_bufnr,
    once = true,
    callback = function()
      if session and session.result_bufnr == result_bufnr then
        session = nil
      end
    end,
  })

  vim.api.nvim_set_current_win(center_win)
  vim.notify(
    string.format(
      "conflict-ink: %d conflict%s — co: accept ours, ct: accept theirs, q: close",
      #conflicts, #conflicts == 1 and "" or "s"
    ),
    vim.log.levels.INFO
  )
end

return M
