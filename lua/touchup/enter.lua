local M = {}

---Setup smart list Enter keymap for a markdown buffer
---@param bufnr integer
function M.setup(bufnr)
  vim.keymap.set("i", "<CR>", function()
    local cursor = vim.api.nvim_win_get_cursor(0)
    local row, col = cursor[1], cursor[2]
    local line = vim.api.nvim_get_current_line()
    local indent, marker = line:match("^(%s*)([-*+])")
    if not indent then
      local keys = vim.api.nvim_replace_termcodes("<CR>", true, false, true)
      return vim.api.nvim_feedkeys(keys, "n", false)
    end
    local marker_end = #indent + 2
    local after = line:sub(marker_end + 1)
    if after == "" and col >= marker_end then
      vim.api.nvim_set_current_line("")
      vim.api.nvim_win_set_cursor(0, { row, 0 })
    elseif col > marker_end then
      local before = line:sub(1, col)
      local rest = line:sub(col + 1)
      vim.api.nvim_set_current_line(before)
      local new_line = indent .. marker .. " " .. rest
      vim.api.nvim_buf_set_lines(0, row, row, false, { new_line })
      vim.api.nvim_win_set_cursor(0, { row + 1, #new_line })
      vim.schedule(function()
        local p = vim.treesitter.get_parser(0, "markdown")
        if p then
          p:parse()
        end
      end)
    else
      local new_line = indent .. marker .. " "
      vim.api.nvim_buf_set_lines(0, row, row, false, { new_line })
      vim.api.nvim_win_set_cursor(0, { row + 1, #new_line })
      vim.schedule(function()
        local p = vim.treesitter.get_parser(0, "markdown")
        if p then
          p:parse()
        end
      end)
    end
  end, { buffer = bufnr, desc = "Smart list Enter" })
end

return M
