local M = {}

local api = vim.api

-- Label highlight per comment type word (the `thinking` in
-- `<!-- pitel:thinking`). Types without an entry use TouchupCommentBlockLabel.
local type_hl = {
	thinking = "TouchupCommentBlockThinking",
	error = "TouchupCommentBlockError",
	tool = "TouchupCommentBlockTool",
	ui = "TouchupCommentBlockUi",
	usage = "TouchupCommentBlockUsage",
}

---Comment type word from the first line of an html_block:
---`<!-- pitel:thinking` -> "thinking", `<!-- note` -> "note".
---Returns the type (without `pitel:` prefix) plus the start/end columns
---of the label text, or nil for closers (`<!-- /pitel:tool`) and
---non-comment lines.
function M.type_of(line)
	local e, word = select(2, line:find("^%s*<!%-%-%s*(pitel:%a+)"))
	if not word then
		e, word = select(2, line:find("^%s*<!%-%-%s*(%a+)"))
	end
	if not word then
		return nil
	end
	-- Anchored find returns match start as 1, so derive the label start
	-- from the match end and the captured word length.
	return (word:gsub("^pitel:", "")), e - #word + 1, e
end

---Find the closing `<!-- /pitel:tool` line of a tool region.
---lines: full buffer lines (1-based), opener: 1-based opener line.
---Returns the 1-based closer line, or nil. Capped at the next `# @role`
---heading OUTSIDE a fenced code block or legacy `<!-- pitel:ui` comment
---(fenced results can contain `# @user` lines; a ``` inside a comment is
---not a fence) so an unclosed region cannot swallow the buffer.
local function fence_run(line)
	local ws = line:match("^%s*")
	if #ws > 3 then
		return nil
	end
	local rest = line:sub(#ws + 1)
	local c = rest:sub(1, 1)
	if c ~= "`" and c ~= "~" then
		return nil
	end
	local n = 0
	while rest:sub(n + 1, n + 1) == c do
		n = n + 1
	end
	if n < 3 then
		return nil
	end
	return c, n, rest:sub(n + 1)
end

function M.find_tool_end(lines, opener)
	local fence -- open fence: { char, n }
	local in_comment = false -- legacy `<!-- pitel:ui … -->` comment
	for i = opener + 1, #lines do
		local l = lines[i]
		if in_comment then
			if l:match("^%-%->%s*$") then
				in_comment = false
			end
		elseif fence then
			-- inside a fenced block: literal until a matching closer
			local c, n, tail = fence_run(l)
			if c == fence.char and n >= fence.n and tail:match("^%s*$") then
				fence = nil
			end
		elseif l:match("^%s*<!%-%-%s*/pitel:tool") then
			return i
		elseif l:match("^# @%a+%s*$") then
			return nil
		elseif l:match("^%s*<!%-%-%s*pitel:ui%s*$") then
			in_comment = true -- legacy multi-line ui: raw until `-->`
		else
			local c, n = fence_run(l)
			if c then
				fence = { char = c, n = n }
			end
		end
	end
	return nil
end

-- CommonMark starts an HTML block (type 2) at any `<!--`, so a wordless
-- block and a `<!-- /pitel:tool -->` closer are blocks too; they simply
-- carry no label.
local COMMENT = "^%s*<!%-%-"

---Last line covered by a comment block that starts on line i (1-based).
---A single-line comment ends on its own line; a multi-line one ends on the
---first line containing `-->`. The agent always emits that closer alone on
---a line, and neutralizes `-->` inside comment text, so the first `-->`
---reliably ends the block.
local function comment_end(lines, i, n)
	if lines[i]:find("%-%->") then
		return i
	end
	for j = i + 1, n do
		if lines[j]:find("%-%->") then
			return j
		end
	end
	return n
end

---Comment-region spans for a buffer's lines, in document order.
---
---Pure logic over the line list (1-based `lines`, as find_tool_end takes),
---so it is unit-testable without a parser. Each span is
---`{ srow, erow, ctype, lstart, lend }` where `srow` is the 0-based row of
---the block's first line (an extmark row) and `erow` is the 1-based index
---of its last covered line, which is at the same time the exclusive
---0-based end row — for a tool region that is its `<!-- /pitel:tool`
---closer.
---
---A single forward pass: markers inside a fenced code block are literal
---(a `cat` of a tool result can contain `<!-- pitel:tool`), a tool region
---is one span covering its header, result and ui subsection, and a legacy
---`<!-- pitel:ui` comment inside it is part of that span rather than a
---block of its own.
function M.spans(lines)
	local list = {}
	local n = #lines
	local fence -- open fence: { char, n }
	local i = 1
	while i <= n do
		local l = lines[i]
		if fence then
			local c, k, tail = fence_run(l)
			if c == fence.char and k >= fence.n and tail:match("^%s*$") then
				fence = nil
			end
		elseif l:match(COMMENT) then
			local ctype, lstart, lend = M.type_of(l)
			local erow
			if ctype == "tool" then
				erow = M.find_tool_end(lines, i) or comment_end(lines, i, n)
			else
				erow = comment_end(lines, i, n)
			end
			list[#list + 1] = { i - 1, erow, ctype, lstart, lend }
			i = erow
		else
			local c, k = fence_run(l)
			if c then
				fence = { char = c, n = k }
			end
		end
		i = i + 1
	end
	return list
end

---Span cache, keyed by buffer. Rebuilding the list is an O(buffer) pass,
---and typing bumps changedtick on every keystroke, so a rebuild per change
---was a rebuild per keystroke (~6ms on a large session). Like the tree cache
---in init.lua, spans are rebuilt once the buffer has been quiet for IDLE_MS,
---serving the last list in the meantime: freshly typed prose adds no spans,
---and a mid-buffer edit is only transiently stale for that window.
local cache = {} -- bufnr -> { tick, n, list }
local refresh_timers = {} -- bufnr -> timer
local IDLE_MS = 1500

--- Pure cache decision, separated from the provider so it is unit-testable:
--- how to source the spans for a redraw.
---   "first"  no cached list: build now (one-time cold cost on open)
---   "reuse"  buffer unchanged since the last build: use the cached list
---   "defer"  buffer changed: serve the cached list and rebuild when idle
function M._span_decision(entry, tick, n)
	if not entry then
		return "first"
	end
	if entry.tick == tick and entry.n == n then
		return "reuse"
	end
	return "defer"
end

--- Rebuild the span list for a buffer.
local function rebuild_spans(bufnr)
	local n = api.nvim_buf_line_count(bufnr)
	cache[bufnr] = {
		tick = api.nvim_buf_get_changedtick(bufnr),
		n = n,
		list = M.spans(api.nvim_buf_get_lines(bufnr, 0, n, false)),
	}
end

--- Rebuild once the buffer has been stable for IDLE_MS. Each keystroke pushes
--- the rebuild out, so it fires once when typing pauses, not per keystroke.
local function schedule_spans(bufnr)
	local t = refresh_timers[bufnr]
	if t then
		t:stop()
		t:close()
	end
	refresh_timers[bufnr] = vim.defer_fn(function()
		refresh_timers[bufnr] = nil
		if not api.nvim_buf_is_valid(bufnr) then
			return
		end
		rebuild_spans(bufnr)
	end, IDLE_MS)
end

---Drop a buffer's cached spans and pending rebuild (called on BufDelete).
function M.clear(bufnr)
	cache[bufnr] = nil
	local t = refresh_timers[bufnr]
	if t then
		t:stop()
		t:close()
	end
	refresh_timers[bufnr] = nil
end

---Render HTML comment block backgrounds for the drawn range. Called from
---the decoration provider, so extmarks are ephemeral. A `<!-- pitel:tool`
---opener extends its background over the whole region (result text,
---pitel:ui subsection) up to its closer.
function M.render(ns, bufnr, start_row, end_row)
	local tick = api.nvim_buf_get_changedtick(bufnr)
	local n = api.nvim_buf_line_count(bufnr)
	local c = cache[bufnr]
	local action = M._span_decision(c, tick, n)
	if action == "first" then
		rebuild_spans(bufnr)
		c = cache[bufnr]
	elseif action == "defer" then
		schedule_spans(bufnr)
	end

	for _, s in ipairs(c.list) do
		local srow, erow, ctype, lstart, lend = s[1], s[2], s[3], s[4], s[5]
		if erow > start_row and srow < end_row then
			-- Clamp to the drawn range: ephemeral marks do not survive the
			-- redraw, so covering rows that are not being drawn only costs
			-- time. A region straddling the top of the window still gets its
			-- background (the mark starts at start_row).
			local a = srow < start_row and start_row or srow
			local b = erow > end_row and end_row or erow
			api.nvim_buf_set_extmark(bufnr, ns, a, 0, {
				end_row = b,
				hl_group = "TouchupCommentBlock",
				hl_eol = true,
				ephemeral = true,
			})

			-- Color the type word on the opener line, admonition-style.
			-- Only meaningful when the opener is drawn.
			if ctype and srow >= start_row and srow < end_row then
				api.nvim_buf_set_extmark(bufnr, ns, srow, lstart - 1, {
					end_col = lend,
					hl_group = type_hl[ctype] or "TouchupCommentBlockLabel",
					priority = 150,
					ephemeral = true,
				})
			end
		end
	end
end

return M
