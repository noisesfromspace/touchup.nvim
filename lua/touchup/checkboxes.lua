local M = {}

local icons = {
  [" "] = { text = "󰄰", hl = "TouchupCheckboxUnchecked" },
  ["x"] = { text = "󰗠", hl = "TouchupCheckboxChecked" },
  ["X"] = { text = "󰗠", hl = "TouchupCheckboxChecked" },
  ["/"] = { text = "󱎖", hl = "TouchupCheckboxPending" },
  [">"] = { text = "", hl = "TouchupCheckboxCancelled" },
  ["<"] = { text = "󰃖", hl = "TouchupCheckboxCancelled" },
  ["-"] = { text = "󰍶", hl = "TouchupCheckboxCancelled" },
  ["?"] = { text = "󰋗", hl = "TouchupCheckboxPending" },
  ["!"] = { text = "󰀦", hl = "TouchupCheckboxImportant" },
  ["*"] = { text = "󰓎", hl = "TouchupCheckboxPending" },
  ['"'] = { text = "󰸥", hl = "TouchupCheckboxCancelled" },
  ["l"] = { text = "󰆋", hl = "TouchupCheckboxProgress" },
  ["b"] = { text = "󰃀", hl = "TouchupCheckboxProgress" },
  ["i"] = { text = "󰰄", hl = "TouchupCheckboxChecked" },
  ["S"] = { text = "", hl = "TouchupCheckboxChecked" },
  ["I"] = { text = "󰛨", hl = "TouchupCheckboxPending" },
  ["p"] = { text = "", hl = "TouchupCheckboxChecked" },
  ["c"] = { text = "", hl = "TouchupCheckboxUnchecked" },
  ["f"] = { text = "󱠇", hl = "TouchupCheckboxUnchecked" },
  ["k"] = { text = "", hl = "TouchupCheckboxPending" },
  ["w"] = { text = "", hl = "TouchupCheckboxProgress" },
  ["u"] = { text = "󰔵", hl = "TouchupCheckboxChecked" },
  ["d"] = { text = "󰔳", hl = "TouchupCheckboxUnchecked" },
}

local parse = vim.treesitter.query and vim.treesitter.query.parse or vim.treesitter.parse_query
local query

function M.render(ns, bufnr, start_row, end_row, root)
  if not query then
    local parse = vim.treesitter.query and vim.treesitter.query.parse or vim.treesitter.parse_query
    query = parse("markdown", "[(task_list_marker_unchecked) (task_list_marker_checked)] @checkbox")
  end

  if not root then
    local parser = vim.treesitter.get_parser(bufnr, "markdown", {})
    if not parser then return end
    local trees = parser:parse(); root = trees and trees[1] and trees[1]:root()
  end
  if not root then return end

  -- Treesitter: [ ] and [x]
  for _, node in query:iter_captures(root, bufnr, start_row, end_row) do
      local row, c0, _, c1 = node:range()
      local lines = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)
      local ch = (lines and lines[1] and lines[1]:sub(c0 + 2, c0 + 2)) or " "
      local cfg = icons[ch]
      if cfg then
        pcall(vim.api.nvim_buf_set_extmark, bufnr, ns, row, c0 + 1, {
          end_col = c0 + 2,
          virt_text = { { cfg.text, cfg.hl } },
          virt_text_pos = "overlay",
          ephemeral = true,
        })
      end
    end

  -- Line scan: custom states ([!], [<], etc.) — overlay icon, kill link underline on brackets
  for row = start_row, end_row do
    local lines = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)
    local line = lines and lines[1] or ""
    local _, _, ch = line:find("^%s*[-*+]%s+%[(.)%]")
    if ch and not (ch == " " or ch == "x" or ch == "X") then
      local cb0 = line:find("%[") -- 1-based position of [
      if cb0 then
        local cfg = icons[ch]
        if cfg then
          -- Icon on middle char
          pcall(vim.api.nvim_buf_set_extmark, bufnr, ns, row, cb0, {
            end_col = cb0 + 1,
            virt_text = { { cfg.text, cfg.hl } },
            virt_text_pos = "overlay",
            ephemeral = true,
          })
        end
      end
    end
  end
end

return M
