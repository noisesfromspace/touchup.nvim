local M = {}

M.defaults = {
  bullets = {
    enabled = true,
    icons = { "✸", "✿", "✦", "✧" },
  },
  code_blocks = {
    enabled = true,
  },
  checkboxes = {
    enabled = true,
  },
  enter = {
    enabled = true,
  },
}

---Merge user config with defaults
function M.merge(user)
  return vim.tbl_deep_extend("keep", user or {}, M.defaults)
end

return M
