local colors = require'lib.colors'
local extensions = require'lib.extensions'
local config = require'lib.config'
local utils = require'lib.utils'

local api = vim.api

local lines = {}
local hl = {}
local index = 0
local namespace_id = api.nvim_create_namespace('LuaTreeHighlights')

local icon_state = config.get_icon_state()

local get_folder_icon = function() return "" end
local set_folder_hl = function(line, depth, icon_len, _, hl_group)
  table.insert(hl, {hl_group, line, depth+icon_len, -1})
end

if icon_state.show_folder_icon then
  get_folder_icon = function(open)
    if open then
      return icon_state.icons.folder_icons.open .. " "
    else
      return icon_state.icons.folder_icons.default .. " "
    end
  end
  set_folder_hl = function(line, depth, icon_len, name_len, hl_group)
    table.insert(hl, {hl_group, line, depth+icon_len, depth+icon_len+name_len})
    table.insert(hl, {'LuaTreeFolderIcon', line, depth, depth+icon_len})
  end
end

local get_file_icon = function() return icon_state.icons.default end
if icon_state.show_file_icon then
  local web_devicons = require'nvim-web-devicons'

  get_file_icon = function(fname, extension, line, depth)
    local icon, hl_group = web_devicons.get_icon(fname, extension)

    if icon then
      if hl_group then
        table.insert(hl, { hl_group, line, depth, depth + #icon })
      end
      return icon.." "
    else
      return #icon_state.icons.default > 0 and icon_state.icons.default.." " or ""
    end
  end

end

local get_symlink_icon = function() return icon_state.icons.symlink end
if icon_state.show_file_icon then
  get_symlink_icon = function()
    return #icon_state.icons.symlink > 0 and icon_state.icons.symlink.." " or ""
  end
end

local get_padding = function(depth)
  return string.rep(' ', depth)
end

if vim.g.lua_tree_indent_markers == 1 then
  get_padding = function(depth, idx, tree, _, markers)
    local padding = ""
    if depth ~= 0 then
      local rdepth = depth/2
      markers[rdepth] = idx ~= #tree.entries
      for i=1,rdepth do
        if idx == #tree.entries and i == rdepth then
          padding = padding..'└ '
        elseif markers[i] then
          padding = padding..'│ '
        else
          padding = padding..'  '
        end
      end
    end
    return padding
  end
end

local picture = {
  jpg = true,
  jpeg = true,
  png = true,
  gif = true,
}

local root_folder_modifier = vim.g.lua_tree_root_folder_modifier or ':~'

local function update_draw_data(tree, depth, markers)
  if tree.cwd and tree.cwd ~= '/' then
    local root_name = vim.fn.fnamemodify(tree.cwd, root_folder_modifier):gsub('/$', '').."/.."
    table.insert(lines, root_name)
    table.insert(hl, {'LuaTreeRootFolder', index, 0, string.len(root_name)})
    index = 1
  end

  for idx, node in ipairs(tree.entries) do
    local padding = get_padding(depth, idx, tree, node, markers)
    local offset = string.len(padding)
    if depth > 0 then
      table.insert(hl, { 'LuaTreeIndentMarker', index, 0, offset })
    end

    local ext_hl = nil
    for _, v in pairs(extensions.extensions) do
      local e_hl = v.get_hl(node)
      if e_hl then
        ext_hl = e_hl
      end
    end

    if node.entries then
      local icon = get_folder_icon(node.open)
      local ext_icons = ""
      for _, v in pairs(extensions.extensions) do
        ext_icons = ext_icons..v.get_icons(hl, node, index, offset, #icon+#ext_icons+1)
      end
      -- INFO: this is mandatory in order to keep gui attributes (bold/italics)
      set_folder_hl(index, offset, #icon, #node.name+#ext_icons, 'LuaTreeFolderName')
      if ext_hl then
        set_folder_hl(index, offset, #icon, #node.name+#ext_icons, ext_hl)
      end
      index = index + 1
      if node.open then
        table.insert(lines, padding..icon..ext_icons..node.name)
        update_draw_data(node, depth + 2, markers)
      else
        table.insert(lines, padding..icon..ext_icons..node.name)
      end
    elseif node.link_to then
      local icon = get_symlink_icon()
      local link_hl = ext_hl or 'LuaTreeSymlink'
      table.insert(hl, { link_hl, index, offset, -1 })
      table.insert(lines, padding..icon..node.name.." ➛ "..node.link_to)
      index = index + 1

    else
      local icon
      local ext_icons = ""
      icon = get_file_icon(node.name, node.extension, index, offset)
      for _, v in pairs(extensions.extensions) do
        ext_icons = ext_icons..v.get_icons(hl, node, index, offset, #icon+#ext_icons)
      end
      table.insert(lines, padding..icon..ext_icons..node.name)

      if node.executable then
        table.insert(hl, {'LuaTreeExecFile', index, offset+#icon+#ext_icons, -1 })
      elseif picture[node.extension] then
        table.insert(hl, {'LuaTreeImageFile', index, offset+#icon+#ext_icons, -1 })
      end

      if ext_hl then
        table.insert(hl, {ext_hl, index, offset+#icon+#ext_icons, -1 })
      end
      index = index + 1
    end
  end
end

local M = {}

function M.draw(tree, reload)
  if not tree.bufnr then return end
  api.nvim_buf_set_option(tree.bufnr, 'modifiable', true)
  local cursor = api.nvim_win_get_cursor(tree.winnr)
  if reload then
    index = 0
    lines = {}
    hl = {}
    update_draw_data(tree, 0, {})
  end

  api.nvim_buf_set_lines(tree.bufnr, 0, -1, false, lines)
  M.render_hl(tree.bufnr)
  if #lines >= cursor[1] then
    api.nvim_win_set_cursor(tree.winnr, cursor)
  end
  api.nvim_buf_set_option(tree.bufnr, 'modifiable', false)
end

function M.render_hl(bufnr)
  if not bufnr then return end
  api.nvim_buf_clear_namespace(bufnr, namespace_id, 0, -1)
  for _, data in ipairs(hl) do
    api.nvim_buf_add_highlight(bufnr, namespace_id, data[1], data[2], data[3], data[4])
  end
end

return M
