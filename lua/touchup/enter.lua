local M = {}

local api = vim.api

---Continue a list item on <CR>: "- item" -> "- ", "1. item" -> "2. ", a
---checkbox item always continues unchecked. <CR> on an empty item exits the
---list. Outside list items this falls through to a plain <CR>.
---Uses a <Plug> mapping with a non-expr callback (like bullets.nvim) so
---buffer edits happen directly — no vim.schedule, no expr-mapping E565,
---and compatible with blink.cmp's fallback mechanism.
local function smart_enter()
	local cursor = api.nvim_win_get_cursor(0)
	local row, col = cursor[1], cursor[2]
	local line = api.nvim_get_current_line()

	-- Numbered checkbox, numbered plain, bullet checkbox, bullet plain.
	-- The marker must be followed by whitespace, or **bold** lines
	-- would look like a list item to us.
	local prefix = line:match("^(%s*%d+[.)]%s+%[.%]%s*)")
		or line:match("^(%s*%d+[.)]%s+)")
		or line:match("^(%s*[-*+]%s+%[.%]%s*)")
		or line:match("^(%s*[-*+]%s+)")
	if not prefix or col < #prefix then
		-- Not a list item: fall through to a plain <CR>
		api.nvim_feedkeys(
			api.nvim_replace_termcodes("<CR>", true, false, true),
			"int",
			false
		)
		return
	end

	if line:sub(#prefix + 1) == "" then
		-- Empty item: exit the list
		api.nvim_set_current_line("")
		api.nvim_win_set_cursor(0, { row, 0 })
		return
	end

	-- Continue the list: split line at cursor, insert continuation prefix
	local cont = prefix:gsub("%[.%]", "[ ]", 1)
	cont = cont:gsub("^(%s*)(%d+)([.)])", function(s, n, d)
		return s .. (tonumber(n) + 1) .. d
	end, 1)

	local before = line:sub(1, col)
	local rest = line:sub(col + 1)
	api.nvim_set_current_line(before)
	api.nvim_buf_set_lines(0, row, row, false, { cont .. rest })
	api.nvim_win_set_cursor(0, { row + 1, #cont + #rest })
end

---After an indent or dedent, renumber a numbered list item to continue from the
---previous item at the same indent level, or reset to 1 if there is none.
---Runs deferred so the default <C-t>/<C-d> has already taken effect.
local function renumber_after_shift()
	local cursor = api.nvim_win_get_cursor(0)
	local row = cursor[1]
	local line = api.nvim_get_current_line()

	local indent, num, delim = line:match("^(%s*)(%d+)([.)])")
	if not indent then
		return
	end

	-- Scan backwards for a sibling at the same indent level
	for r = row - 1, 1, -1 do
		local prev = api.nvim_buf_get_lines(0, r - 1, r, false)[1] or ""
		local p_indent, p_num, p_delim = prev:match("^(%s*)(%d+)([.)])")
		if p_indent then
			if #p_indent == #indent then
				-- Sibling found: continue numbering
				local next_num = tonumber(p_num) + 1
				api.nvim_set_current_line(indent .. next_num .. delim
					.. line:sub(#indent + #num + #delim + 1))
				return
			elseif #p_indent < #indent then
				-- Hit parent level: no siblings, reset to 1
				break
			end
		elseif prev:match("^%s*$") then
			-- Blank line: skip
		else
			-- Non-list line at same or shallower indent: reset to 1
			if (#prev:match("^%s*") or 0) <= #indent then
				break
			end
		end
	end

	-- No sibling found: reset to 1
	api.nvim_set_current_line(indent .. "1" .. delim
		.. line:sub(#indent + #num + #delim + 1))
end

M._renumber_after_shift = renumber_after_shift

---Setup smart list keymaps for a markdown buffer
---@param bufnr integer
function M.setup(bufnr)
	-- Smart Enter: continue or exit list items
	vim.keymap.set("i", "<Plug>(touchup-smart-enter)", smart_enter, {
		buffer = bufnr,
		noremap = true,
		desc = "Smart list Enter",
	})
	vim.keymap.set("i", "<CR>", "<Plug>(touchup-smart-enter)", {
		buffer = bufnr,
		desc = "Smart list Enter",
	})

	-- Indent: indent, then reset numbered items to 1
	vim.keymap.set("i", "<Plug>(touchup-indent)", function()
		api.nvim_feedkeys(
			api.nvim_replace_termcodes("<C-t>", true, false, true),
			"int", false
		)
		vim.schedule(renumber_after_shift)
	end, {
		buffer = bufnr,
		noremap = true,
		desc = "Indent and renumber list",
	})
	vim.keymap.set("i", "<C-t>", "<Plug>(touchup-indent)", {
		buffer = bufnr,
		desc = "Indent and renumber list",
	})

	-- Dedent: dedent, then reset numbered items to 1
	vim.keymap.set("i", "<Plug>(touchup-dedent)", function()
		api.nvim_feedkeys(
			api.nvim_replace_termcodes("<C-d>", true, false, true),
			"int", false
		)
		vim.schedule(renumber_after_shift)
	end, {
		buffer = bufnr,
		noremap = true,
		desc = "Dedent and renumber list",
	})
	vim.keymap.set("i", "<C-d>", "<Plug>(touchup-dedent)", {
		buffer = bufnr,
		desc = "Dedent and renumber list",
	})
end

return M
