local M = {}

local api = vim.api

local query

---Dim emphasis, strikethrough and code delimiters (**, *, ~~, `) for a range.
---Delimiters inside headings are left alone; the heading styling is
---strong enough and decoupling underline color from fg is fragile.
---itrees is one tree per inline region in the buffer.
function M.render(ns, bufnr, start_row, end_row, itrees, block_root)
	if not itrees then
		return
	end

	if not query then
		query = vim.treesitter.query.parse(
			"markdown_inline",
			"[(strong_emphasis) (emphasis) (strikethrough) (code_span)] @span"
		)
	end

	for _, tree in ipairs(itrees) do
		for _, node in query:iter_captures(tree:root(), bufnr, start_row, end_row) do
			local srow, scol, erow, ecol = node:range()
			if srow == erow then
				local text = vim.treesitter.get_node_text(node, bufnr)
				-- Delimiter characters are specific to the node type, or `` `**` ``
				-- would dim the asterisks as if they were part of the backtick run.
				local ds
				local ntype = node:type()
				if ntype == "code_span" then
					ds = "`"
				elseif ntype == "strikethrough" then
					ds = "~"
				else
					ds = "*_"
				end
				local lead = #(text:match("^[" .. ds .. "]+") or "")
				local trail = #(text:match("[" .. ds .. "]+$") or "")

				-- Don't dim inside headings: the styling is strong enough and
				-- decoupling underline color from text color is unreliable across
				-- colorscheme load order.
				local in_heading = false
				if block_root then
					local bn = vim.treesitter.get_node({
						buf = bufnr,
						pos = { srow, scol },
						ignore_injections = true,
					})
					while bn do
						local t = bn:type()
						if t == "atx_heading" or t == "setext_heading" then
							in_heading = true
							break
						end
						bn = bn:parent()
					end
				end

				if not in_heading then
					if lead > 0 then
						api.nvim_buf_set_extmark(bufnr, ns, srow, scol, {
							end_col = scol + lead,
							hl_group = "TouchupDim",
							priority = 150,
							ephemeral = true,
						})
					end
					if trail > 0 and trail < ecol - scol then
						api.nvim_buf_set_extmark(bufnr, ns, srow, ecol - trail, {
							end_col = ecol,
							hl_group = "TouchupDim",
							priority = 150,
							ephemeral = true,
						})
					end
				end
			end
		end
	end
end

return M
