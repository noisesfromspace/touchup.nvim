local M = {}

---Define all highlight groups (default = true so colorschemes can override)
function M.setup()
  vim.api.nvim_set_hl(0, "TouchupBulletDash", { link = "NonText", default = true })
  vim.api.nvim_set_hl(0, "TouchupBulletPlus", { link = "NonText", default = true })
  vim.api.nvim_set_hl(0, "TouchupBulletStar", { link = "NonText", default = true })
  vim.api.nvim_set_hl(0, "TouchupCodeBlock", { link = "CursorLine", default = true })
  vim.api.nvim_set_hl(0, "TouchupCheckboxUnchecked", { link = "NonText", default = true })
  vim.api.nvim_set_hl(0, "TouchupCheckboxChecked", { link = "DiagnosticOk", default = true })
  vim.api.nvim_set_hl(0, "TouchupCheckboxPending", { link = "DiagnosticWarn", default = true })
  vim.api.nvim_set_hl(0, "TouchupCheckboxCancelled", { link = "Comment", default = true })
  vim.api.nvim_set_hl(0, "TouchupCheckboxImportant", { link = "DiagnosticError", default = true })
  vim.api.nvim_set_hl(0, "TouchupCheckboxProgress", { link = "DiagnosticInfo", default = true })
  vim.api.nvim_set_hl(0, "@markup.heading.1.markdown", { bold = true, underline = true, default = true })
  vim.api.nvim_set_hl(0, "@markup.heading.2.markdown", { underline = true, default = true })
end

return M
