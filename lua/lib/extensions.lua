local M = {
  extensions = {},
}

function M.add(extension)
  M.extensions[#M.extensions] = extension
end

return M
