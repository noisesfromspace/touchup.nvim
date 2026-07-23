local M = {}

---Define all highlight groups (default = true so colorschemes can override)
function M.setup()
	local set = vim.api.nvim_set_hl
	set(0, "TouchupBulletDash", { link = "NonText", default = true })
	set(0, "TouchupBulletPlus", { link = "NonText", default = true })
	set(0, "TouchupBulletStar", { link = "NonText", default = true })
	set(0, "TouchupCodeBlock", { link = "CursorLine", default = true })
	set(0, "TouchupQuote", { link = "CursorLine", default = true })
	set(0, "TouchupCheckboxUnchecked", { link = "NonText", default = true })
	set(0, "TouchupCheckboxChecked", { link = "DiagnosticOk", default = true })
	set(0, "TouchupCheckboxPending", { link = "DiagnosticWarn", default = true })
	set(0, "TouchupCheckboxCancelled", { link = "Comment", default = true })
	set(0, "TouchupCheckboxImportant", { link = "DiagnosticError", default = true })
	set(0, "TouchupCheckboxProgress", { link = "DiagnosticInfo", default = true })
	-- Custom checkbox states parse as shortcut links; brackets are redrawn as
	-- overlay virt_text in this group so no link underline shows
	set(0, "TouchupCheckboxBracket", { link = "@markup.list", default = true })
	set(0, "TouchupAdmonitionNote", { link = "DiagnosticInfo", default = true })
	set(0, "TouchupAdmonitionTip", { link = "DiagnosticOk", default = true })
	set(0, "TouchupAdmonitionImportant", { link = "DiagnosticWarn", default = true })
	set(0, "TouchupAdmonitionWarning", { link = "DiagnosticWarn", default = true })
	set(0, "TouchupAdmonitionCaution", { link = "DiagnosticError", default = true })
	set(0, "TouchupDim", { link = "NonText", default = true })
	set(0, "TouchupLinkLabel", { underdotted = true, default = true })
	set(0, "TouchupLinkLabelBold", { bold = true, underdotted = true, default = true })
	set(0, "TouchupLinkLabelItalic", { italic = true, underdotted = true, default = true })
	set(0, "TouchupLinkLabelStrikethrough", { strikethrough = true, underdotted = true, default = true })
	set(0, "TouchupLinkLabelCode", { link = "@markup.raw", default = true })
	set(0, "@markup.quote", { italic = true, default = true })
	set(0, "@markup.heading.1.markdown", { bold = true, underline = true, default = true })
	set(0, "@markup.heading.2.markdown", { underline = true, default = true })
end

return M
