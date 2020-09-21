local M = {
  extensions = {},
}

local function all(fname, ...)
  for _, extension in pairs(M.extensions) do
    if extension[fname] then
      extension[fname](...)
    end
  end
end

function M.add(extension)
  M.extensions[#M.extensions] = extension
end

function M.init_colors()
  all("init_colors")
end

function M.refresh(node)
  all("refresh", node)
end

function M.set_mappings(buf)
  all("set_mappings", buf)
end

function M.update_status(entries, cwd)
  all("update_status", entries, cwd)
end

function M.get_icons(hl, node, index, offset, length)
  local icons = ""
  for _, e in pairs(M.extensions) do
    icons = icons..e.get_icons(hl, node, index, offset, length+#icons)
  end
  return icons
end

function M.get_hl(node)
  local hl = nil
  for _, e in pairs(M.extensions) do
    local e_hl = e.get_hl(node)
    if e_hl then
      hl = e_hl
    end
  end
  return hl
end

return M
