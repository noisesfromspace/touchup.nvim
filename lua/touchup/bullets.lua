local M = {}

local api = vim.api

local hl_map = {
  list_marker_minus = "TouchupBulletDash",
  list_marker_plus = "TouchupBulletPlus",
  list_marker_star = "TouchupBulletStar",
}

local query

---Count ancestor list nodes for nesting level
local function list_level(node)
  local n, p = 0, node:parent()
  while p do
    if p:type() == "list" then
      n = n + 1
    end
    p = p:parent()
  end
  return n
end

---@return boolean true if this list item is a task ([ ]/[x] or a custom state like [!])
local function is_task(node, line)
  for child in node:parent():iter_children() do
    local ct = child:type()
    if ct == "task_list_marker_unchecked" or ct == "task_list_marker_checked" then
      return true
    end
  end
  local _, _, _, c1 = node:range()
  return line:sub(c1 + 1):match("^%s*%[.%]") ~= nil
end

---Render list bullet icons for a range. Called from the decoration provider,
---so extmarks are ephemeral and root is the shared parse tree.
function M.render(ns, bufnr, icons, start_row, end_row, root)
  if not icons or #icons == 0 then
    return
  end

  if not query then
    query = vim.treesitter.query.parse(
      "markdown",
      "(list_item [(list_marker_minus) (list_marker_plus) (list_marker_star)] @bullet)"
    )
  end

  local lines = api.nvim_buf_get_lines(bufnr, start_row, end_row, false)

  for _, match in query:iter_matches(root, bufnr, start_row, end_row, { all = true }) do
    for _, nodes in pairs(match) do
      for _, node in ipairs(nodes) do
        local row, c0, _, c1 = node:range()
        if not is_task(node, lines[row - start_row + 1] or "") then
          -- The marker node of a first nested item can start in the
          -- indentation; align the icon to the actual marker char
          local text = vim.treesitter.get_node_text(node, bufnr)
          local mc0 = c0 + #(text:match("^%s*") or "")
          local icon = icons[(list_level(node) - 1) % #icons + 1]
          api.nvim_buf_set_extmark(bufnr, ns, row, mc0, {
            end_col = c1,
            virt_text = { { icon .. " ", hl_map[node:type()] or "TouchupBulletDash" } },
            virt_text_pos = "overlay",
            hl_mode = "combine",
            ephemeral = true,
          })
        end
      end
    end
  end
end

return M
