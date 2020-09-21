local tree_config = require"lib.config"
local utils = require"extensions/git/utils"
local config = require"extensions/git/config"

local M = {}

local function set_mapping(buf, key, fn)
  vim.api.nvim_buf_set_keymap(buf, 'n', key, ':lua require"extensions/git/mappings".'..fn..'<cr>', {
      nowait = true, noremap = true, silent = true
    })
end

local function gen_go_to(mode)
  local icon_state = tree_config.get_icon_state()
  local flags = mode == 'prev_git_item' and 'b' or ''
  local icons = table.concat(vim.tbl_values(icon_state.icons.git_icons or config.git_icons), '\\|')
  return function()
    return utils.show_git() and vim.fn.search(icons, flags)
  end
end

M.keypress_funcs = {
  prev_git_item = gen_go_to('prev_git_item'),
  next_git_item = gen_go_to('next_git_item'),
}

function M.set_mappings(buf)
  local keybindings = vim.g.lua_tree_bindings or {}
  local bindings = {
    prev_git_item   = keybindings.prev_git_item or '[c',
    next_git_item   = keybindings.next_git_item or ']c',
  }
  local mappings = {
    [bindings.prev_git_item] = "keypress_funcs.prev_git_item()";
    [bindings.next_git_item] = "keypress_funcs.next_git_item()";
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

return M
