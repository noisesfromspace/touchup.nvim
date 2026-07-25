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
		-- Obsidian-style checkbox states. Standard `[ ]`/`[x]` are handled via
		-- treesitter; every other key here is matched by a regex fallback
		-- against `- [<char>]` / `* [<char>]` / `+ [<char>]`, so adding a new
		-- single-character key here is enough to support a brand-new state.
		-- `icons[" "]` (unchecked) is intentionally not customizable: it always
		-- renders as a plain space, no overlay.
		icons = {
			["x"] = { text = "󰗠", hl = "TouchupCheckboxChecked" },
			["X"] = { text = "󰗠", hl = "TouchupCheckboxChecked" },
			["/"] = { text = "󱎖", hl = "TouchupCheckboxPending" },
			[">"] = { text = "", hl = "TouchupCheckboxCancelled" },
			["<"] = { text = "󰃖", hl = "TouchupCheckboxCancelled" },
			["-"] = { text = "󰍶", hl = "TouchupCheckboxCancelled" },
			["?"] = { text = "󰋗", hl = "TouchupCheckboxPending" },
			["!"] = { text = "󰀦", hl = "TouchupCheckboxImportant" },
			["*"] = { text = "󰓎", hl = "TouchupCheckboxPending" },
			['"'] = { text = "󰸥", hl = "TouchupCheckboxCancelled" },
			["l"] = { text = "󰆋", hl = "TouchupCheckboxProgress" },
			["b"] = { text = "󰃀", hl = "TouchupCheckboxProgress" },
			["i"] = { text = "󰰄", hl = "TouchupCheckboxChecked" },
			["S"] = { text = "", hl = "TouchupCheckboxChecked" },
			["I"] = { text = "󰛨", hl = "TouchupCheckboxPending" },
			["p"] = { text = "", hl = "TouchupCheckboxChecked" },
			["c"] = { text = "", hl = "TouchupCheckboxUnchecked" },
			["f"] = { text = "󱠇", hl = "TouchupCheckboxUnchecked" },
			["k"] = { text = "", hl = "TouchupCheckboxPending" },
			["w"] = { text = "", hl = "TouchupCheckboxProgress" },
			["u"] = { text = "󰔵", hl = "TouchupCheckboxChecked" },
			["d"] = { text = "󰔳", hl = "TouchupCheckboxUnchecked" },
		},
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
