local M = {}

local api = vim.api

local query

-- Label highlight per comment type word (the `thinking` in
-- `<!-- pitel:thinking`). Types without an entry use TouchupCommentBlockLabel.
local type_hl = {
	thinking = "TouchupCommentBlockThinking",
	error = "TouchupCommentBlockError",
	tool = "TouchupCommentBlockTool",
	ui = "TouchupCommentBlockUi",
	usage = "TouchupCommentBlockUsage",
}

---Comment type word from the first line of an html_block:
---`<!-- pitel:thinking` -> "thinking", `<!-- note` -> "note".
---Returns the type (without `pitel:` prefix) plus the start/end columns
---of the label text, or nil for closers (`<!-- /pitel:tool`) and
---non-comment lines.
function M.type_of(line)
	local e, word = select(2, line:find("^%s*<!%-%-%s*(pitel:%a+)"))
	if not word then
		e, word = select(2, line:find("^%s*<!%-%-%s*(%a+)"))
	end
	if not word then
		return nil
	end
	-- Anchored find returns match start as 1, so derive the label start
	-- from the match end and the captured word length.
	return (word:gsub("^pitel:", "")), e - #word + 1, e
end

---Find the closing `<!-- /pitel:tool` line of a tool region.
---lines: full buffer lines (1-based), opener: 1-based opener line.
---Returns the 1-based closer line, or nil. Capped at the next `# @role`
---heading (tool results can legitimately contain markdown headings) so an
---unclosed region cannot swallow the rest of the buffer.
function M.find_tool_end(lines, opener)
	for i = opener + 1, #lines do
		local l = lines[i]
		if l:match("^%s*<!%-%-%s*/pitel:tool") then
			return i
		end
		if l:match("^# @%a+%s*$") then
			return nil
		end
	end
	return nil
end

---Render HTML comment block backgrounds for a range. Called from the
---decoration provider, so extmarks are ephemeral and root is the shared
---parse tree. A `<!-- pitel:tool` opener extends its background over the
---whole region (result text, pitel:ui subsection) up to its closer.
function M.render(ns, bufnr, start_row, end_row, root)
	if not query then
		query = vim.treesitter.query.parse("markdown", "(html_block) @block")
	end

	local tool_spans = {} -- painted tool regions, to skip nested blocks
	for _, node in query:iter_captures(root, bufnr, start_row, end_row) do
		local srow, _, erow = node:range()

		local nested = false
		for _, s in ipairs(tool_spans) do
			if srow > s[1] and srow < s[2] then
				nested = true
				break
			end
		end

		if not nested then
			local first = (api.nvim_buf_get_lines(bufnr, srow, srow + 1, false))[1] or ""
			local ctype, lstart, lend = M.type_of(first)

			if ctype == "tool" then
				local last = api.nvim_buf_line_count(bufnr)
				local lines = api.nvim_buf_get_lines(bufnr, 0, math.min(last, srow + 2000), false)
				local closer = M.find_tool_end(lines, srow + 1)
				if closer then
					erow = closer -- 1-based closer line == exclusive 0-based end row
					table.insert(tool_spans, { srow, erow })
				end
			end

			api.nvim_buf_set_extmark(bufnr, ns, srow, 0, {
				end_row = erow,
				hl_group = "TouchupCommentBlock",
				hl_eol = true,
				ephemeral = true,
			})

			-- Color the type word on the opener line, admonition-style.
			if ctype then
				api.nvim_buf_set_extmark(bufnr, ns, srow, lstart - 1, {
					end_col = lend,
					hl_group = type_hl[ctype] or "TouchupCommentBlockLabel",
					priority = 150,
					ephemeral = true,
				})
			end
		end
	end
end

return M
