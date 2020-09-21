local M = {}

function M.show_git()
  local show_git_icon = true
  if vim.g.lua_tree_show_icon == nil then
    return show_git_icon
  end
  if vim.g.lua_tree_show_icon.git == nil then
    return show_git_icon
  end
  return vim.g.lua_tree_show_icon.git == 1
end

return M
