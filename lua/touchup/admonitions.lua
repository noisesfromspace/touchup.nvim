local M = {}

local api = vim.api

local query

-- Map GFI admonition types to Diagnostic* highlight groups
local type_hl = {
	NOTE = "TouchupAdmonitionNote",
	TIP = "TouchupAdmonitionTip",
	IMPORTANT = "TouchupAdmonitionImportant",
	WARNING = "TouchupAdmonitionWarning",
	CAUTION = "TouchupAdmonitionCaution",
	ERROR = "TouchupAdmonitionCaution",
}

---Color the [!TYPE] prefix of blockquote admonitions per type.
---Called from the decoration provider. Uses the markdown root
---because admonitions are block_quote nodes.
function M.render(ns, bufnr, start_row, end_row, root)
	if not query then
		query = vim.treesitter.query.parse("markdown", "(block_quote) @quote")
	end

	for _, node in query:iter_captures(root, bufnr, start_row, end_row) do
		local srow, _, erow = node:range()
		local lines = api.nvim_buf_get_lines(bufnr, srow, srow + 1, false)
		local first = lines[1] or ""
		local bcol, ecol, mtype = first:find("^>%s*%[!(%w+)%]")
		if mtype then
			local hl = type_hl[mtype] or "TouchupAdmonitionNote"
			api.nvim_buf_set_extmark(bufnr, ns, srow, bcol - 1, {
				end_col = ecol,
				hl_group = hl,
				priority = 150,
				ephemeral = true,
			})
		end
	end
end

return M
