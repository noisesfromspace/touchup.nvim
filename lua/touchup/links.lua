local M = {}

local api = vim.api
local diag = require("touchup.diag")

---Route virt_text segment highlights through the diagnostic overlay so an LSP
---underline under a link still renders (overlay virt_text would otherwise
---replace the cell highlight). Segments advance in byte columns from `col`.
---@param bufnr integer
---@param row integer 0-based
---@param col integer 0-based byte column of the first segment
---@param segments table[] list of {string text, string hl}
---@return table[]
local function overlay_segments(bufnr, row, col, segments)
	local out = {}
	local cur = col
	for _, seg in ipairs(segments) do
		local text = seg[1]
		table.insert(out, { text, diag.overlay(bufnr, row, cur, seg[2], cur + #text) })
		cur = cur + #text
	end
	return out
end

local query
local image_query
local autolink_query

local format_hl = {
	strong_emphasis = "TouchupLinkLabelBold",
	emphasis = "TouchupLinkLabelItalic",
	strikethrough = "TouchupLinkLabelStrikethrough",
	code_span = "TouchupLinkLabelCode",
}

---Pure logic: build virt_text segments for a bare autolink (e.g. <http://link.com>).
---Exposed for testing.
---@param text string full node text
---@return table list of {string, string} pairs
function M.build_autolink_segments(text)
	if #text >= 2 and text:sub(1, 1) == "<" and text:sub(-1) == ">" then
		local url = text:sub(2, #text - 1)
		local segments = { { "<", "TouchupDim" } }
		if #url > 0 then
			table.insert(segments, { url, "TouchupLinkLabel" })
		end
		table.insert(segments, { ">", "TouchupDim" })
		return segments
	end
	return { { text, "TouchupLinkLabel" } }
end

---Pure logic: split a formatted inline node's text into (text, hl)
---segments. Exposed for testing.
---@param ntype string treesitter node type
---@param text string node text
---@return table list of {string, string} pairs
function M.split_formatting(ntype, text)
	local hl = format_hl[ntype] or "TouchupLinkLabel"

	local ds
	if ntype == "code_span" then
		ds = "`"
	elseif ntype == "strikethrough" then
		ds = "~"
	else
		ds = "*_"
	end

	local lead = #(text:match("^[" .. ds .. "]+") or "")
	local trail = #(text:match("[" .. ds .. "]+$") or "")
	local inner = #text - lead - trail

	local segments = {}
	if lead > 0 then
		table.insert(segments, { text:sub(1, lead), "TouchupDim" })
	end
	if inner > 0 then
		table.insert(segments, { text:sub(lead + 1, lead + inner), hl })
	end
	if trail > 0 and trail < #text then
		table.insert(segments, { text:sub(#text - trail + 1), "TouchupDim" })
	end
	return segments
end

---Pure logic: build virt_text segments for a link label that may
---contain formatted children. Exposed for testing.
---@param full string full text of the link_text node
---@param start_col number starting column of the node
---@param named table[] sorted named children, each {sc=col, ec=col, type=string, text=string}
---@return table virt_text segments
function M.build_label_segments(full, start_col, named)
	if #named == 0 then
		return { { full, "TouchupLinkLabel" } }
	end

	local segments = {}
	local pos = start_col
	for _, nc in ipairs(named) do
		if nc.sc > pos then
			table.insert(segments, {
				full:sub(pos - start_col + 1, nc.sc - start_col),
				"TouchupLinkLabel",
			})
		end
		local inner = M.split_formatting(nc.type, nc.text)
		for _, seg in ipairs(inner) do
			table.insert(segments, seg)
		end
		pos = nc.ec
	end
	local end_col = start_col + #full
	if end_col > pos then
		table.insert(segments, {
			full:sub(pos - start_col + 1),
			"TouchupLinkLabel",
		})
	end

	return segments
end

-- Thin wrappers that extract data from treesitter nodes.

local function format_node(node, bufnr)
	return M.split_formatting(node:type(), vim.treesitter.get_node_text(node, bufnr))
end

local function link_text_segments(node, bufnr)
	local full = vim.treesitter.get_node_text(node, bufnr)
	local _, sc = node:range()

	local named = {}
	for child in node:iter_children() do
		if child:named() then
			local _, csc, _, cec = child:range()
			table.insert(named, {
				sc = csc,
				ec = cec,
				type = child:type(),
				text = vim.treesitter.get_node_text(child, bufnr),
			})
		end
	end

	return M.build_label_segments(full, sc, named)
end

---Check whether a node at (row, col) is inside a heading or blockquote.
local function skip_node(bufnr, block_root, srow, scol)
	if not block_root then
		return false
	end
	local bn = vim.treesitter.get_node({
		buf = bufnr,
		pos = { srow, scol },
		ignore_injections = true,
	})
	while bn do
		local t = bn:type()
		if t == "atx_heading" or t == "setext_heading" or t == "block_quote" then
			return true
		end
		bn = bn:parent()
	end
	return false
end

---Style the children of a link/image node: the descriptive text
---gets underdotted, everything else is dimmed.
---@param label_type string "link_text" or "image_description"
local function style_node_children(ns, bufnr, node, label_type)
	for child in node:iter_children() do
		local cr, cc, _, ec = child:range()
		local t = child:type()
		if t == label_type then
			api.nvim_buf_set_extmark(bufnr, ns, cr, cc, {
				end_col = ec,
				virt_text = overlay_segments(bufnr, cr, cc, link_text_segments(child, bufnr)),
				virt_text_pos = "overlay",
				priority = 150,
				ephemeral = true,
			})
		elseif not child:named() or t == "link_destination" then
			local text = vim.treesitter.get_node_text(child, bufnr)
			api.nvim_buf_set_extmark(bufnr, ns, cr, cc, {
				end_col = ec,
				virt_text = { { text, diag.overlay(bufnr, cr, cc, "TouchupDim", ec) } },
				virt_text_pos = "overlay",
				priority = 150,
				ephemeral = true,
			})
		end
	end
end

---Style a bare URL autolink (e.g. <http://link.com>): dim < and >, style URL as TouchupLinkLabel.
local function style_autolink(ns, bufnr, node)
	local srow, scol, _, ecol = node:range()
	local text = vim.treesitter.get_node_text(node, bufnr)
	api.nvim_buf_set_extmark(bufnr, ns, srow, scol, {
		end_col = ecol,
		virt_text = overlay_segments(bufnr, srow, scol, M.build_autolink_segments(text)),
		virt_text_pos = "overlay",
		priority = 150,
		ephemeral = true,
	})
end

---Dim brackets, parens, and URL. Apply underdotted to the link
---text and bare URLs. Links inside headings and blockquotes are skipped.
---itrees is one tree per inline region in the buffer.
function M.render(ns, bufnr, start_row, end_row, itrees, block_root)
	if not itrees then
		return
	end

	if not query then
		query = vim.treesitter.query.parse("markdown_inline", "(inline_link) @link")
	end
	if not image_query then
		image_query = vim.treesitter.query.parse("markdown_inline", "(image) @img")
	end
	if not autolink_query then
		autolink_query = vim.treesitter.query.parse(
			"markdown_inline",
			"[(uri_autolink) (email_autolink)] @autolink"
		)
	end

	for _, tree in ipairs(itrees) do
		for _, node in query:iter_captures(tree:root(), bufnr, start_row, end_row) do
			local srow, scol = node:range()
			if not skip_node(bufnr, block_root, srow, scol) then
				style_node_children(ns, bufnr, node, "link_text")
			end
		end
	end

	for _, tree in ipairs(itrees) do
		for _, node in image_query:iter_captures(tree:root(), bufnr, start_row, end_row) do
			local srow, scol = node:range()
			if not skip_node(bufnr, block_root, srow, scol) then
				style_node_children(ns, bufnr, node, "image_description")
			end
		end
	end

	for _, tree in ipairs(itrees) do
		for _, node in autolink_query:iter_captures(tree:root(), bufnr, start_row, end_row) do
			local srow, scol = node:range()
			if not skip_node(bufnr, block_root, srow, scol) then
				style_autolink(ns, bufnr, node)
			end
		end
	end
end

return M
