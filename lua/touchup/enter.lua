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

---Setup smart list Enter keymap for a markdown buffer
---@param bufnr integer
function M.setup(bufnr)
	vim.keymap.set("i", "<Plug>(touchup-smart-enter)", smart_enter, {
		buffer = bufnr,
		noremap = true,
		desc = "Smart list Enter",
	})
	vim.keymap.set("i", "<CR>", "<Plug>(touchup-smart-enter)", {
		buffer = bufnr,
		desc = "Smart list Enter",
	})
end

return M
