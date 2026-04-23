if vim.g.loaded_conflict_ink then
  return
end
vim.g.loaded_conflict_ink = true

vim.api.nvim_create_user_command("ConflictInkRefresh", function()
  local render = require("conflict-ink.render")
  local actions = require("conflict-ink.actions")
  local config = require("conflict-ink").config
  local bufnr = vim.api.nvim_get_current_buf()
  render.refresh(bufnr)
  if config.default_mappings then
    local conflicts = render.get_conflicts(bufnr)
    if conflicts and #conflicts > 0 then
      actions.set_buf_mappings(bufnr, config.mappings)
    end
  end
end, { desc = "Re-scan buffer for git conflicts" })

vim.api.nvim_create_user_command("ConflictInkOurs", function()
  local actions = require("conflict-ink.actions")
  actions.choose_ours(vim.api.nvim_get_current_buf())
end, { desc = "Accept ours (current) side" })

vim.api.nvim_create_user_command("ConflictInkTheirs", function()
  local actions = require("conflict-ink.actions")
  actions.choose_theirs(vim.api.nvim_get_current_buf())
end, { desc = "Accept theirs (incoming) side" })

vim.api.nvim_create_user_command("ConflictInkBoth", function()
  local actions = require("conflict-ink.actions")
  actions.choose_both(vim.api.nvim_get_current_buf())
end, { desc = "Keep both sides" })

vim.api.nvim_create_user_command("ConflictInkNone", function()
  local actions = require("conflict-ink.actions")
  actions.choose_none(vim.api.nvim_get_current_buf())
end, { desc = "Remove both sides" })

vim.api.nvim_create_user_command("ConflictInkNext", function()
  require("conflict-ink.actions").next_conflict()
end, { desc = "Jump to next conflict" })

vim.api.nvim_create_user_command("ConflictInkPrev", function()
  require("conflict-ink.actions").prev_conflict()
end, { desc = "Jump to previous conflict" })

vim.api.nvim_create_user_command("ConflictInkAllOurs", function()
  require("conflict-ink.actions").choose_all_ours()
end, { desc = "Accept ours for all conflicts" })

vim.api.nvim_create_user_command("ConflictInkAllTheirs", function()
  require("conflict-ink.actions").choose_all_theirs()
end, { desc = "Accept theirs for all conflicts" })

vim.api.nvim_create_user_command("ConflictInkResolve", function()
  require("conflict-ink.resolve").resolve()
end, { desc = "Smart auto-resolve non-overlapping conflicts" })
