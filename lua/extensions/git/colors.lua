local tcolors = require'lib.colors'

local M = {}

local function get_hl_groups()
  local colors = tcolors.get_colors()

  return {
    GitDirty = { fg = colors.yellow },
    GitDeleted = { fg = colors.dark_red },
    GitStaged = { fg = colors.green },
    GitMerge = { fg = colors.orange },
    GitRenamed = { fg = colors.purple },
    GitNew = { fg = colors.yellow }
  }
end

local function get_links()
  return {
    FileDirty = 'LuaTreeGitDirty',
    FileNew = 'LuaTreeGitNew',
    FileRenamed = 'LuaTreeGitRenamed',
    FileMerge = 'LuaTreeGitMerge',
    FileStaged = 'LuaTreeGitStaged',
    FileDeleted = 'LuaTreeGitDeleted',
  }
end

function M.setup()
  local higlight_groups = get_hl_groups()
  for k, d in pairs(higlight_groups) do
    local gui = d.gui or 'NONE'
    vim.api.nvim_command('hi def LuaTree'..k..' gui='..gui..' guifg='..d.fg)
  end

  local links = get_links()
  for k, d in pairs(links) do
    vim.api.nvim_command('hi def link LuaTree'..k..' '..d)
  end
end

return M
