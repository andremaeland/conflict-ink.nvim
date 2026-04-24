local M = {}

M.CURRENT = "ConflictInkCurrent"
M.CURRENT_LABEL = "ConflictInkCurrentLabel"
M.INCOMING = "ConflictInkIncoming"
M.INCOMING_LABEL = "ConflictInkIncomingLabel"
M.BASE = "ConflictInkBase"
M.BASE_LABEL = "ConflictInkBaseLabel"
M.HINT = "ConflictInkHint"
M.HINT_KEY = "ConflictInkHintKey"

--- Calculate relative luminance of a hex color (sRGB).
--- @param hex string e.g. "#1e1e2e"
--- @return number luminance 0.0 to 1.0
local function luminance(hex)
  local r = tonumber(hex:sub(2, 3), 16) / 255
  local g = tonumber(hex:sub(4, 5), 16) / 255
  local b = tonumber(hex:sub(6, 7), 16) / 255
  r = r <= 0.03928 and r / 12.92 or ((r + 0.055) / 1.055) ^ 2.4
  g = g <= 0.03928 and g / 12.92 or ((g + 0.055) / 1.055) ^ 2.4
  b = b <= 0.03928 and b / 12.92 or ((b + 0.055) / 1.055) ^ 2.4
  return 0.2126 * r + 0.7152 * g + 0.0722 * b
end

--- Get the background color from the Normal highlight group.
--- @return string|nil hex color
local function get_bg_color()
  local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = "Normal", link = false })
  if ok and hl and hl.bg then
    return string.format("#%06x", hl.bg)
  end
  return nil
end

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

local dark_high_contrast = {
  current = { bg = "#1e6b26", bold = true },
  current_label = { bg = "#28753b", bold = true },
  incoming = { bg = "#5e35b1", bold = true },
  incoming_label = { bg = "#6a3dba", bold = true },
  base = { bg = "#5e5c20", bold = true },
  base_label = { bg = "#706e24", bold = true },
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

--- Get theme-aware defaults based on background setting and actual background luminance.
function M.defaults()
  if vim.o.background == "light" then
    return light
  end
  local bg = get_bg_color()
  if bg and luminance(bg) < 0.007 then
    return dark_high_contrast
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
