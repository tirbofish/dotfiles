-- base46 theme built from pywal's current palette (~/.cache/wal/colors.json)

local ok, wal = pcall(function()
  local f = assert(io.open(vim.fn.expand "~/.cache/wal/colors.json"))
  local data = vim.json.decode(f:read "*a")
  f:close()
  return data
end)

local onedark = require "base46.themes.onedark"
if not ok then
  return onedark
end

local L = require("base46.colors").change_hex_lightness
local c = wal.colors
local bg, fg = wal.special.background, wal.special.foreground

local M = {}

M.base_30 = {
  white = fg,
  darker_black = L(bg, -3),
  black = bg, --  nvim bg
  black2 = L(bg, 6),
  one_bg = L(bg, 10),
  one_bg2 = L(bg, 16),
  one_bg3 = L(bg, 22),
  grey = L(bg, 28),
  grey_fg = L(bg, 34),
  grey_fg2 = L(bg, 40),
  light_grey = c.color8,
  red = c.color1,
  baby_pink = L(c.color1, 10),
  pink = c.color13,
  line = L(bg, 12), -- for lines like vertsplit
  green = c.color2,
  vibrant_green = c.color10,
  nord_blue = c.color12,
  blue = c.color4,
  yellow = c.color3,
  sun = c.color11,
  purple = c.color5,
  dark_purple = L(c.color5, -10),
  teal = c.color6,
  orange = c.color9,
  cyan = c.color14,
  statusline_bg = L(bg, 4),
  lightbg = L(bg, 13),
  pmenu_bg = c.color4,
  folder_bg = c.color4,
}

M.base_16 = {
  base00 = bg,
  base01 = L(bg, 8),
  base02 = L(bg, 14),
  base03 = c.color8,
  base04 = L(c.color8, 15),
  base05 = fg,
  base06 = L(fg, 5),
  base07 = c.color15,
}

-- syntax accents stay onedark so code keeps distinct hues; pywal drives bg/fg/ui
for _, k in ipairs { "base08", "base09", "base0A", "base0B", "base0C", "base0D", "base0E", "base0F" } do
  M.base_16[k] = onedark.base_16[k]
end

M.type = "dark"

return M
