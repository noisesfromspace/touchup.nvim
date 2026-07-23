local M = {}

M.defaults = {
	filetypes = { "markdown" },
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
	markers = {
		enabled = true,
	},
	quotes = {
		enabled = true,
	},
	admonitions = {
		enabled = true,
	},
	links = {
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
