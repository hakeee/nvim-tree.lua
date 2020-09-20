local config = require'lib.config'
local utils = require'lib.utils'

local function set_mapping(buf, key, fn)
  vim.api.nvim_buf_set_keymap(buf, 'n', key, ':lua require"tree".'..fn..'<cr>', {
      nowait = true, noremap = true, silent = true
    })
end

local git_icons = {
  unstaged = "✗",
  staged = "✓",
  unmerged = "",
  renamed = "➜",
  untracked = "★",
  deleted = ""
}

local function show_git()
  local show_git_icon = true
  if vim.g.lua_tree_show_icon == nil then
    return show_git_icon
  end
  if vim.g.lua_tree_show_icon.git == nil then
    return show_git_icon
  end
  return vim.g.lua_tree_show_icon.git == 1
end

local function gen_go_to(mode)
  local icon_state = config.get_icon_state()
  local flags = mode == 'prev_git_item' and 'b' or ''
  local icons = table.concat(vim.tbl_values(icon_state.icons.git_icons or git_icons), '\\|')
  return function()
    return show_git() and vim.fn.search(icons, flags)
  end
end

local M = {
  keypress_funcs = {
    prev_git_item = gen_go_to('prev_git_item'),
    next_git_item = gen_go_to('next_git_item'),
  }
}

function M.set_mappings(buf)
  local keybindings = vim.g.lua_tree_bindings or {}
  local bindings = {
    prev_git_item   = keybindings.prev_git_item or '[c',
    next_git_item   = keybindings.next_git_item or ']c',
  }
  local mappings = {
    [bindings.prev_git_item] = "on_keypress('prev_git_item')";
    [bindings.next_git_item] = "on_keypress('next_git_item')";
  }

  for k,v in pairs(mappings) do
    if type(k) == 'table' then
      for _, key in pairs(k) do
        set_mapping(buf, key, v)
      end
    else
      set_mapping(buf, k, v)
    end
  end
end

local roots = {}

local not_git = 'not a git repo'

local function update_root_status(root)
  local status = vim.fn.systemlist('cd "'..root..'" && git status --porcelain=v1 -u')
  roots[root] = {}

  for _, v in pairs(status) do
    local head = v:sub(0, 2)
    local body = v:sub(4, -1)
    if body:match('%->') ~= nil then
      body = body:gsub('^.* %-> ', '')
    end
    roots[root][body] = head
  end
end

function M.reload_roots()
  for root, status in pairs(roots) do
    if status ~= not_git then
      update_root_status(root)
    end
  end
end

local function get_git_root(path)
  if roots[path] then
    return path, roots[path]
  end

  for name, status in pairs(roots) do
    if status ~= not_git then
      if path:match(utils.path_to_matching_str(name)) then
        return name, status
      end
    end
  end
end

local function create_root(cwd)
  local git_root = vim.fn.system('cd "'..cwd..'" && git rev-parse --show-toplevel')

  if not git_root or #git_root == 0 or git_root:match('fatal') then
    roots[cwd] = not_git
    return false
  end

  update_root_status(git_root:sub(0, -2))
  return true
end

function M.update_status(entries, cwd)
  if (not show_git()) and vim.g.lua_tree_git_hl ~= 1 then
    return
  end

  local git_root, git_status = get_git_root(cwd)
  if not git_root then
    if not create_root(cwd) then
      return
    end
    git_root, git_status = get_git_root(cwd)
  elseif git_status == not_git then
    return
  end

  local matching_cwd = utils.path_to_matching_str(git_root..'/')
  for _, node in pairs(entries) do
    local relpath = node.absolute_path:gsub(matching_cwd, '')
    if node.entries ~= nil then
      relpath = relpath..'/'
      node.git_status = nil
    end

    local status = git_status[relpath]
    if status then
      node.git_status = status
    elseif node.entries ~= nil then
      local matcher = '^'..utils.path_to_matching_str(relpath)
      for key, entry_status in pairs(git_status) do
        if key:match(matcher) then
          node.git_status = entry_status
          break
        end
      end
    else
      node.git_status = nil
    end
  end
end

local function refresh(node)
  M.update_status(node.entries, node.absolute_path or node.cwd)
  for _, entry in pairs(node.entries) do
    if entry.entries ~= nil then
      refresh(entry)
    end
  end
end

function M.refresh(node)
  if show_git() then
    M.reload_roots()
    refresh(node)
  end
end


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
      utils.echo_warning('Unrecognized git state "'..git_status..'". Please open up an issue on https://github.com/kyazdani42/nvim-tree.lua/issues with this message.')
      icons = hl.dirty
    end

    -- TODO: how would we determine hl color when multiple git status are active ?
    return icons[1].hl
    -- return icons[#icons].hl
  end
end

if show_git() then
  local icon_state = {
    ["M "] = { { icon = git_icons.staged, hl = "LuaTreeGitStaged" } },
    [" M"] = { { icon = git_icons.unstaged, hl = "LuaTreeGitDirty" } },
    ["MM"] = {
      { icon = git_icons.staged, hl = "LuaTreeGitStaged" },
      { icon = git_icons.unstaged, hl = "LuaTreeGitDirty" }
    },
    ["A "] = {
      { icon = git_icons.staged, hl = "LuaTreeGitStaged" },
      { icon = git_icons.untracked, hl = "LuaTreeGitNew" }
    },
    ["AM"] = {
      { icon = git_icons.staged, hl = "LuaTreeGitStaged" },
      { icon = git_icons.untracked, hl = "LuaTreeGitNew" },
      { icon = git_icons.unstaged, hl = "LuaTreeGitDirty" }
    },
    ["??"] = { { icon = git_icons.untracked, hl = "LuaTreeGitNew" } },
    ["R "] = { { icon = git_icons.renamed, hl = "LuaTreeGitRenamed" } },
    ["UU"] = { { icon = git_icons.unmerged, hl = "LuaTreeGitMerge" } },
    [" D"] = { { icon = git_icons.deleted, hl = "LuaTreeGitDeleted" } },
    dirty = { { icon = git_icons.unstaged, hl = "LuaTreeGitDirty" } },
  }

  M.get_icons = function(hl, node, line, depth, icon_len)
    local git_status = node.git_status
    if not git_status then return "" end

    local icon = ""
    local icons = icon_state[git_status]
    if not icons then
      if vim.g.lua_tree_git_hl ~= 1 then
        utils.echo_warning('Unrecognized git state "'..git_status..'". Please open up an issue on https://github.com/kyazdani42/nvim-tree.lua/issues with this message.')
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
  if config.get_icon_state().show_file_icon then
    require'nvim-web-devicons'.setup()
  end
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
