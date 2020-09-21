local config = require'extensions/git/config'
local utils = require"extensions/git/utils"
local tree_utils = require"lib.utils"

local M = {}

M.get_icons = function() return "" end
M.get_hl = function() return end

if vim.g.lua_tree_git_hl == 1 then
  local hl = {
    ["M "] = { { hl = "LuaTreeFileStaged" } },
    [" M"] = { { hl = "LuaTreeFileDirty" } },
    ["MM"] = {
      { hl = "LuaTreeFileStaged" },
      { hl = "LuaTreeFileDirty" }
    },
    ["A "] = {
      { hl = "LuaTreeFileStaged" },
      { hl = "LuaTreeFileNew" }
    },
    ["AM"] = {
      { hl = "LuaTreeFileStaged" },
      { hl = "LuaTreeFileNew" },
      { hl = "LuaTreeFileDirty" }
    },
    ["??"] = { { hl = "LuaTreeFileNew" } },
    ["R "] = { { hl = "LuaTreeFileRenamed" } },
    ["UU"] = { { hl = "LuaTreeFileMerge" } },
    [" D"] = { { hl = "LuaTreeFileDeleted" } },
    dirty = { { hl = "LuaTreeFileDirty" } },
  }
  M.get_hl = function(node)
    local git_status = node.git_status
    if not git_status then return end

    local icons = hl[git_status]

    if icons == nil then
      tree_utils.echo_warning('Unrecognized git state "'..git_status..'". Please open up an issue on https://github.com/kyazdani42/nvim-tree.lua/issues with this message.')
      icons = hl.dirty
    end

    -- TODO: how would we determine hl color when multiple git status are active for example ?
    return icons[1].hl
    -- return icons[#icons].hl
  end
end

if utils.show_git() then
  local icon_state = {
    ["M "] = { { icon = config.git_icons.staged, hl = "LuaTreeGitStaged" } },
    [" M"] = { { icon = config.git_icons.unstaged, hl = "LuaTreeGitDirty" } },
    ["MM"] = {
      { icon = config.git_icons.staged, hl = "LuaTreeGitStaged" },
      { icon = config.git_icons.unstaged, hl = "LuaTreeGitDirty" }
    },
    ["A "] = {
      { icon = config.git_icons.staged, hl = "LuaTreeGitStaged" },
      { icon = config.git_icons.untracked, hl = "LuaTreeGitNew" }
    },
    ["AM"] = {
      { icon = config.git_icons.staged, hl = "LuaTreeGitStaged" },
      { icon = config.git_icons.untracked, hl = "LuaTreeGitNew" },
      { icon = config.git_icons.unstaged, hl = "LuaTreeGitDirty" }
    },
    ["??"] = { { icon = config.git_icons.untracked, hl = "LuaTreeGitNew" } },
    ["R "] = { { icon = config.git_icons.renamed, hl = "LuaTreeGitRenamed" } },
    ["UU"] = { { icon = config.git_icons.unmerged, hl = "LuaTreeGitMerge" } },
    [" D"] = { { icon = config.git_icons.deleted, hl = "LuaTreeGitDeleted" } },
    dirty = { { icon = config.git_icons.unstaged, hl = "LuaTreeGitDirty" } },
  }

  M.get_icons = function(hl, node, line, depth, icon_len)
    local git_status = node.git_status
    if not git_status then return "" end

    local icon = ""
    local icons = icon_state[git_status]
    if not icons then
      if vim.g.lua_tree_git_hl ~= 1 then
        tree_utils.echo_warning('Unrecognized git state "'..git_status..'". Please open up an issue on https://github.com/kyazdani42/nvim-tree.lua/issues with this message.')
      end
      icons = icon_state.dirty
    end
    for _, v in ipairs(icons) do
      table.insert(hl, { v.hl, line, depth+icon_len+#icon, depth+icon_len+#icon+#v.icon })
      icon = icon..v.icon.." "
    end

    return icon
  end
end

return M
