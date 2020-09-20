local api = vim.api
local config = require'lib.config'
local extensions = require'lib.extensions'

local M = {}

local function get_color_from_hl(hl_name, fallback)
  local id = vim.api.nvim_get_hl_id_by_name(hl_name)
  if not id then return fallback end

  local hl = vim.api.nvim_get_hl_by_id(id, true)
  if not hl or not hl.foreground then return fallback end

  return hl.foreground
end

local function get_colors()
  return {
    red      = vim.g.terminal_color_1  or get_color_from_hl('Keyword', 'Red'),
    green    = vim.g.terminal_color_2  or get_color_from_hl('Character', 'Green'),
    yellow   = vim.g.terminal_color_3  or get_color_from_hl('PreProc', 'Yellow'),
    blue     = vim.g.terminal_color_4  or get_color_from_hl('Include', 'Blue'),
    purple   = vim.g.terminal_color_5  or get_color_from_hl('Define', 'Purple'),
    cyan     = vim.g.terminal_color_6  or get_color_from_hl('Conditional', 'Cyan'),
    dark_red = vim.g.terminal_color_9  or get_color_from_hl('Keyword', 'DarkRed'),
    orange   = vim.g.terminal_color_11 or get_color_from_hl('Number', 'Orange'),
  }
end

local function get_hl_groups()
  local colors = get_colors()

  return {
    IndentMarker = { fg = '#8094b4' },
    Symlink = { gui = 'bold', fg = colors.cyan },
    FolderIcon = { fg = '#8094b4' },
    RootFolder = { fg = colors.purple },

    ExecFile = { gui = 'bold', fg = colors.green },
    ImageFile = { gui = 'bold', fg = colors.purple },
  }
end

local function get_links()
  return {
    FolderName = 'Directory',
    Normal = 'Normal',
    EndOfBuffer = 'EndOfBuffer',
    CursorLine = 'CursorLine',
    VertSplit = 'VertSplit',
    CursorColumn = 'CursorColumn',
  }
end

function M.setup()
  if config.get_icon_state().show_file_icon then
    require'nvim-web-devicons'.setup()
  end
  local higlight_groups = get_hl_groups()
  for k, d in pairs(higlight_groups) do
    local gui = d.gui or 'NONE'
    api.nvim_command('hi def LuaTree'..k..' gui='..gui..' guifg='..d.fg)
  end

  local links = get_links()
  for k, d in pairs(links) do
    api.nvim_command('hi def link LuaTree'..k..' '..d)
  end

  for _, v in pairs(extensions.extensions) do
    v.setup()
  end
end

return M
