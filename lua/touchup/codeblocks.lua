local M = {}

local api = vim.api

local query

---Render code block backgrounds for a range. Called from the decoration provider,
---so extmarks are ephemeral and root is the shared parse tree.
function M.render(ns, bufnr, start_row, end_row, root)
  if not query then
    query = vim.treesitter.query.parse("markdown", "(fenced_code_block) @block")
  end

  for _, node in query:iter_captures(root, bufnr, start_row, end_row) do
    local srow, _, erow = node:range()
    api.nvim_buf_set_extmark(bufnr, ns, srow, 0, {
      end_row = erow,
      hl_group = "TouchupCodeBlock",
      hl_eol = true,
      ephemeral = true,
    })
  end
end

return M
