local M = {}

local block_query, fence_query

---Render code block backgrounds + conceal ``` fences
function M.render(ns, bufnr, start_row, end_row, root)
  if not block_query then
    local ts = vim.treesitter
    local parse = ts.query and ts.query.parse or ts.parse_query
    if not parse then return end
    block_query = parse("markdown", "(fenced_code_block) @block")
    fence_query = parse("markdown", "(fenced_code_block_delimiter) @fence")
  end

  if not root then
    local parser = vim.treesitter.get_parser(bufnr, "markdown", {})
    if not parser then return end
    local trees = parser:parse(); root = trees and trees[1] and trees[1]:root()
  end
  if not root then return end

  for _, node in block_query:iter_captures(root, bufnr, start_row, end_row) do
      local srow, _, erow = node:range()
      pcall(vim.api.nvim_buf_set_extmark, bufnr, ns, srow, 0, {
        end_row = erow,
        hl_group = "TouchupCodeBlock",
        hl_eol = true,
        ephemeral = true,
      })
  end
  for _, node in fence_query:iter_captures(root, bufnr, start_row, end_row) do
      local row, c0, _, c1 = node:range()
      pcall(vim.api.nvim_buf_set_extmark, bufnr, ns, row, c0, {
        end_col = c1,
        conceal = "",
        ephemeral = true,
      })
  end
end

return M
