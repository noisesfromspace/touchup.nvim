local M = {}

local hl_map = {
  list_marker_minus = "TouchupBulletDash",
  list_marker_plus = "TouchupBulletPlus",
  list_marker_star = "TouchupBulletStar",
}

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

---@return boolean true if this list item has a task/checkbox marker
local function has_task(marker_node)
  local parent = marker_node:parent()
  if not parent then
    return false
  end
  for child in parent:iter_children() do
    local ct = child:type()
    if ct == "task_list_marker_unchecked" or ct == "task_list_marker_checked" then
      return true
    end
  end
  return false
end

---@return boolean true if text after marker looks like a checkbox ([.])
local function peek_checkbox(bufnr, row, c1)
  local line = (vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false) or { "" })[1]
  return line:sub(c1 + 1):match("^%s*%[.%]") ~= nil
end

-- Lazy-initialized query (parsed on first render call)
local bullet_query

---Render list bullet icons for visible range
function M.render(ns, bufnr, icons, start_row, end_row, root)
  if not icons or #icons == 0 then
    return
  end

  if not bullet_query then
    local ts = vim.treesitter
    local parse = ts.query and ts.query.parse or ts.parse_query
    if not parse then return end
    local ok, q = pcall(parse, "markdown", "(list_item [(list_marker_minus) (list_marker_plus) (list_marker_star)] @bullet)")
    if not ok then return end
    bullet_query = q
  end

  -- Use shared root if provided, otherwise parse our own
  if not root then
    local parser = vim.treesitter.get_parser(bufnr, "markdown", {})
    if not parser then return end
    local trees = parser:parse()
    root = trees and trees[1] and trees[1]:root()
  end
  if not root then return end

  for _, match, _ in bullet_query:iter_matches(root, bufnr, start_row, end_row, { all = true }) do
      for id, nodes in pairs(match) do
        if not vim.startswith(bullet_query.captures[id], "_") then
          for _, node in ipairs(nodes) do
            local row, c0, _, c1 = node:range()
            -- Skip bullet icon for checkbox items (checkboxes module handles them)
            if not has_task(node) and not peek_checkbox(bufnr, row, c1) then
              local level = list_level(node)
              local icon = icons[(level - 1) % #icons + 1]
              local text = vim.treesitter.get_node_text(node, bufnr)
              local lead = #text:match("^%s*")
              local hl = hl_map[node:type()] or "TouchupBulletDash"
              pcall(vim.api.nvim_buf_set_extmark, bufnr, ns, row, c0, {
                end_col = c1,
                virt_text = { { string.rep(" ", lead) .. icon .. " ", hl } },
                virt_text_pos = "overlay",
                hl_mode = "combine",
                ephemeral = true,
              })
            end
          end
        end
      end
    end
end

return M
