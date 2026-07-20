local M = {}

local api = vim.api

local query

---Dim emphasis, strikethrough and code delimiters (**, *, ~~, `) for a range.
---Delimiters live at the edges of their span nodes in the injected
---markdown_inline tree; dimming only changes color, never conceals.
function M.render(ns, bufnr, start_row, end_row, inline_root)
  if not inline_root then
    return
  end

  if not query then
    query = vim.treesitter.query.parse(
      "markdown_inline",
      "[(strong_emphasis) (emphasis) (strikethrough) (code_span)] @span"
    )
  end

  for _, node in query:iter_captures(inline_root, bufnr, start_row, end_row) do
    local srow, scol, erow, ecol = node:range()
    if srow == erow then
      local text = vim.treesitter.get_node_text(node, bufnr)
      local lead = #(text:match("^[*_~`]+") or "")
      local trail = #(text:match("[*_~`]+$") or "")
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

return M
