local M = {}

local api = vim.api

-- Obsidian-style checkbox states
local icons = {
  -- unchecked renders as a plain space (no icon)
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

local query

---Render checkbox state icons for a range. Called from the decoration provider,
---so extmarks are ephemeral and root is the shared parse tree.
function M.render(ns, bufnr, start_row, end_row, root)
  if not query then
    query = vim.treesitter.query.parse(
      "markdown",
      "[(task_list_marker_unchecked) (task_list_marker_checked)] @checkbox"
    )
  end

  local lines = api.nvim_buf_get_lines(bufnr, start_row, end_row, false)

  -- Treesitter states: [ ] and [x]
  for _, node in query:iter_captures(root, bufnr, start_row, end_row) do
    local row, c0 = node:range()
    local ch = (lines[row - start_row + 1] or ""):sub(c0 + 2, c0 + 2)
    local cfg = icons[ch]
    if cfg then
      api.nvim_buf_set_extmark(bufnr, ns, row, c0 + 1, {
        end_col = c0 + 2,
        virt_text = { { cfg.text, cfg.hl } },
        virt_text_pos = "overlay",
        ephemeral = true,
      })
    end
  end

  -- Custom states ([!], [<], ...) that treesitter doesn't parse as task markers.
  -- The match ends at ']', so the state char is at e-1 (1-based).
  for i, line in ipairs(lines) do
    local _, e, ch = line:find("^%s*[-*+]%s+%[(.)%]")
    if ch and not (ch == " " or ch == "x" or ch == "X") then
      local cfg = icons[ch]
      if cfg then
        local row = start_row + i - 1
        -- Custom states parse as shortcut links; kill the link underline.
        -- Priority 200 beats treesitter (100) and LSP semantic tokens (125).
        api.nvim_buf_set_extmark(bufnr, ns, row, e - 3, {
          end_col = e,
          hl_group = "TouchupCheckboxBracket",
          priority = 200,
          ephemeral = true,
        })
        api.nvim_buf_set_extmark(bufnr, ns, row, e - 2, {
          end_col = e - 1,
          virt_text = { { cfg.text, cfg.hl } },
          virt_text_pos = "overlay",
          ephemeral = true,
        })
      end
    end
  end
end

return M
