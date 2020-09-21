local tree_utils = require'lib.utils'
local utils = require"extensions/git/utils"
local mappings = require"extensions/git/mappings"
local renderer = require"extensions/git/renderer"

local M = {
  init_colors = require"extensions/git/colors".setup,
  set_mappings = mappings.set_mappings,
  get_icons = renderer.get_icons,
  get_hl = renderer.get_hl,
}

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
      if path:match(tree_utils.path_to_matching_str(name)) then
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
  if (not utils.show_git()) and vim.g.lua_tree_git_hl ~= 1 then
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

  local matching_cwd = tree_utils.path_to_matching_str(git_root..'/')
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
      local matcher = '^'..tree_utils.path_to_matching_str(relpath)
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
  if utils.show_git() then
    M.reload_roots()
    refresh(node)
  end
end

return M
