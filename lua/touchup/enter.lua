local M = {}

local api = vim.api

---Continue a list item on <CR>: "- item" -> "- ", "1. item" -> "2. ", a
---checkbox item always continues unchecked. <CR> on an empty item exits the
---list. Outside list items this falls through to a plain <CR>.
---Buffer edits are deferred with vim.schedule: changing text during expr
---mapping evaluation is not allowed (E565).
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
		return "<CR>"
	end

	if line:sub(#prefix + 1) == "" then
		-- Empty item: exit the list
		vim.schedule(function()
			api.nvim_set_current_line("")
			api.nvim_win_set_cursor(0, { row, 0 })
		end)
		return ""
	end

	local cont = prefix:gsub("%[.%]", "[ ]", 1)
	cont = cont:gsub("^(%s*)(%d+)([.)])", function(s, n, d)
		return s .. (tonumber(n) + 1) .. d
	end, 1)

	local before, rest = line:sub(1, col), line:sub(col + 1)
	vim.schedule(function()
		api.nvim_set_current_line(before)
		api.nvim_buf_set_lines(0, row, row, false, { cont .. rest })
		api.nvim_win_set_cursor(0, { row + 1, #cont + #rest })
	end)
	return ""
end

---Setup smart list Enter keymap for a markdown buffer
---@param bufnr integer
function M.setup(bufnr)
	vim.keymap.set("i", "<CR>", smart_enter, {
		buffer = bufnr,
		expr = true,
		desc = "Smart list Enter",
	})
end

return M
