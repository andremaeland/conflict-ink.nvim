local M = {}

M.CURRENT = "ConflictInkCurrent"
M.CURRENT_LABEL = "ConflictInkCurrentLabel"
M.INCOMING = "ConflictInkIncoming"
M.INCOMING_LABEL = "ConflictInkIncomingLabel"
M.BASE = "ConflictInkBase"
M.BASE_LABEL = "ConflictInkBaseLabel"
M.HINT = "ConflictInkHint"
M.HINT_KEY = "ConflictInkHintKey"

local dark = {
  current = { bg = "#2D4A2D", bold = true },
  current_label = { bg = "#385C38", bold = true },
  incoming = { bg = "#3D2D5C", bold = true },
  incoming_label = { bg = "#4A3870", bold = true },
  base = { bg = "#3B3926", bold = true },
  base_label = { bg = "#4A4830", bold = true },
  hint = { link = "Comment" },
  hint_key = { link = "Keyword" },
}

local light = {
  current = { bg = "#D6F5D6", bold = true },
  current_label = { bg = "#C2EBC2", bold = true },
  incoming = { bg = "#E5D6FF", bold = true },
  incoming_label = { bg = "#D4C2F5", bold = true },
  base = { bg = "#FFF5CC", bold = true },
  base_label = { bg = "#FFECB3", bold = true },
  hint = { link = "Comment" },
  hint_key = { link = "Keyword" },
}

--- Get theme-aware defaults based on background setting.
function M.defaults()
  if vim.o.background == "light" then
    return light
  end
  return dark
end

--- Apply highlight groups. User overrides are merged on top of theme defaults.
--- @param user_hl table|nil User highlight overrides from config
function M.setup(user_hl)
  local base = M.defaults()
  local hl_config = vim.tbl_deep_extend("force", base, user_hl or {})

  local set = vim.api.nvim_set_hl
  set(0, M.CURRENT, hl_config.current)
  set(0, M.CURRENT_LABEL, hl_config.current_label)
  set(0, M.INCOMING, hl_config.incoming)
  set(0, M.INCOMING_LABEL, hl_config.incoming_label)
  set(0, M.BASE, hl_config.base)
  set(0, M.BASE_LABEL, hl_config.base_label)
  set(0, M.HINT, hl_config.hint)
  set(0, M.HINT_KEY, hl_config.hint_key)
end

return M
