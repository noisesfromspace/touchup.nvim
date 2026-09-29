-- touchup.nvim test runner -- pure logic, no parsers or pty needed
--
-- Run: nvim --headless --clean '+lua vim.opt.rtp:prepend(".")' -l tests/run.lua

-- Disable JIT: CI kernel blocks mprotect (restricted kernel)

jit.off()

local failures = 0
local checks = 0

local function ok(cond, msg)
	checks = checks + 1
	if cond then
		print("  PASS " .. msg)
	else
		failures = failures + 1
		print("  FAIL " .. msg)
	end
end

local function suite(name)
	print(name)
end

-- ---------------------------------------------------------------------------
-- Setup
-- ---------------------------------------------------------------------------
vim.opt.rtp:prepend(".")
require("touchup").setup()

-- ---------------------------------------------------------------------------
-- config
-- ---------------------------------------------------------------------------
suite("config")
local config = require("touchup.config")
local cfg = config.merge({ bullets = { enabled = false } })
ok(cfg.bullets.enabled == false, "merge keeps user value")
ok(cfg.code_blocks.enabled == true, "code_blocks default enabled")
ok(cfg.checkboxes.enabled == true, "checkboxes default enabled")
ok(cfg.markers.enabled == true, "markers default enabled")
ok(cfg.quotes.enabled == true, "quotes default enabled")
ok(cfg.enter.enabled == true, "enter default enabled")
ok(cfg.links.enabled == true, "links default enabled")
ok(cfg.admonitions.enabled == true, "admonitions default enabled")
ok(cfg.comment_blocks.enabled == true, "comment_blocks default enabled")
ok(vim.deep_equal(cfg.filetypes, { "markdown" }), "filetypes default")
ok(cfg.headings == nil, "headings config removed")

-- checkboxes.icons: per-key merge (override existing state, add a new one,
-- leave every untouched default state alone)
local defaults = require("touchup.config").defaults
local icon_cfg = config.merge({
	checkboxes = {
		icons = {
			["x"] = { text = "X", hl = "MyChecked" },
			["z"] = { text = "Z", hl = "MyCustom" },
		},
	},
})
ok(icon_cfg.checkboxes.icons.x.text == "X" and icon_cfg.checkboxes.icons.x.hl == "MyChecked", "checkboxes.icons overrides an existing state")
ok(icon_cfg.checkboxes.icons.z.text == "Z" and icon_cfg.checkboxes.icons.z.hl == "MyCustom", "checkboxes.icons adds a brand-new state")
ok(
	vim.deep_equal(icon_cfg.checkboxes.icons["X"], defaults.checkboxes.icons["X"]),
	"checkboxes.icons leaves untouched states (uppercase X) at their default"
)
ok(
	vim.deep_equal(icon_cfg.checkboxes.icons["/"], defaults.checkboxes.icons["/"]),
	"checkboxes.icons leaves untouched states (/) at their default"
)
ok(icon_cfg.checkboxes.icons[" "] == nil, "checkboxes.icons has no entry for unchecked state")

-- ---------------------------------------------------------------------------
-- markers delimiter extraction (pure pattern logic)
-- ---------------------------------------------------------------------------
suite("markers delimiter patterns")
local function lead_trail(node_type, text)
	local ds
	if node_type == "code_span" then
		ds = "`"
	elseif node_type == "strikethrough" then
		ds = "~"
	else
		ds = "*_"
	end
	return #(text:match("^[" .. ds .. "]+") or ""), #(text:match("[" .. ds .. "]+$") or "")
end
local l, t
l, t = lead_trail("code_span", "`code`")
ok(l == 1 and t == 1, "code_span: `code` -> lead=1 trail=1")
l, t = lead_trail("code_span", "`**`")
ok(l == 1 and t == 1, "code_span: `**` -> lead=1 trail=1 (not 3)")
l, t = lead_trail("code_span", "`` ``")
ok(l == 2 and t == 2, "code_span: `` `` -> lead=2 trail=2")
l, t = lead_trail("strong_emphasis", "**bold**")
ok(l == 2 and t == 2, "strong_emphasis: **bold** -> lead=2 trail=2")
l, t = lead_trail("emphasis", "*italic*")
ok(l == 1 and t == 1, "emphasis: *italic* -> lead=1 trail=1")
l, t = lead_trail("strikethrough", "~~strike~~")
ok(l == 2 and t == 2, "strikethrough: ~~strike~~ -> lead=2 trail=2")
l, t = lead_trail("strong_emphasis", "__bold__")
ok(l == 2 and t == 2, "strong_emphasis: __bold__ -> lead=2 trail=2")
l, t = lead_trail("emphasis", "_italic_")
ok(l == 1 and t == 1, "emphasis: _italic_ -> lead=1 trail=1")

-- ---------------------------------------------------------------------------
-- links (split_formatting and build_label_segments)
-- ---------------------------------------------------------------------------
suite("links")
local links = require("touchup.links")

local function seg(name, want, got)
	ok(vim.deep_equal(got, want), name .. " | got=" .. vim.inspect(got))
end

-- split_formatting
seg(
	"strong_emphasis: **bold**",
	{ { "**", "TouchupDim" }, { "bold", "TouchupLinkLabelBold" }, { "**", "TouchupDim" } },
	links.split_formatting("strong_emphasis", "**bold**")
)
seg(
	"emphasis: *italic*",
	{ { "*", "TouchupDim" }, { "italic", "TouchupLinkLabelItalic" }, { "*", "TouchupDim" } },
	links.split_formatting("emphasis", "*italic*")
)
seg(
	"strikethrough: ~~strike~~",
	{ { "~~", "TouchupDim" }, { "strike", "TouchupLinkLabelStrikethrough" }, { "~~", "TouchupDim" } },
	links.split_formatting("strikethrough", "~~strike~~")
)
seg(
	"code_span: `code`",
	{ { "`", "TouchupDim" }, { "code", "TouchupLinkLabelCode" }, { "`", "TouchupDim" } },
	links.split_formatting("code_span", "`code`")
)
seg(
	"strong_emphasis: __bold__ (underscore)",
	{ { "__", "TouchupDim" }, { "bold", "TouchupLinkLabelBold" }, { "__", "TouchupDim" } },
	links.split_formatting("strong_emphasis", "__bold__")
)
seg(
	"code_span: triple backtick",
	{ { "```", "TouchupDim" }, { "code", "TouchupLinkLabelCode" }, { "```", "TouchupDim" } },
	links.split_formatting("code_span", "```code```")
)

-- build_label_segments
seg("plain text", { { "hello world", "TouchupLinkLabel" } }, links.build_label_segments("hello world", 0, {}))

seg(
	"bold mid-text",
	{
		{ "a ", "TouchupLinkLabel" },
		{ "**", "TouchupDim" },
		{ "bold", "TouchupLinkLabelBold" },
		{ "**", "TouchupDim" },
		{ " word", "TouchupLinkLabel" },
	},
	links.build_label_segments("a **bold** word", 0, {
		{ sc = 2, ec = 10, type = "strong_emphasis", text = "**bold**" },
	})
)

seg(
	"bold at start",
	{
		{ "**", "TouchupDim" },
		{ "start", "TouchupLinkLabelBold" },
		{ "**", "TouchupDim" },
		{ " text", "TouchupLinkLabel" },
	},
	links.build_label_segments("**start** text", 0, {
		{ sc = 0, ec = 9, type = "strong_emphasis", text = "**start**" },
	})
)

seg(
	"bold at end",
	{
		{ "text ", "TouchupLinkLabel" },
		{ "**", "TouchupDim" },
		{ "end", "TouchupLinkLabelBold" },
		{ "**", "TouchupDim" },
	},
	links.build_label_segments("text **end**", 0, {
		{ sc = 5, ec = 12, type = "strong_emphasis", text = "**end**" },
	})
)

seg("non-zero start_col", { { "link", "TouchupLinkLabel" } }, links.build_label_segments("link", 10, {}))

seg(
	"two formatting nodes",
	{
		{ "**", "TouchupDim" },
		{ "a", "TouchupLinkLabelBold" },
		{ "**", "TouchupDim" },
		{ " and ", "TouchupLinkLabel" },
		{ "*", "TouchupDim" },
		{ "b", "TouchupLinkLabelItalic" },
		{ "*", "TouchupDim" },
	},
	links.build_label_segments("**a** and *b*", 0, {
		{ sc = 0, ec = 5, type = "strong_emphasis", text = "**a**" },
		{ sc = 10, ec = 13, type = "emphasis", text = "*b*" },
	})
)

-- build_autolink_segments
seg(
	"autolink http",
	{ { "<", "TouchupDim" }, { "http://link.com", "TouchupLinkLabel" }, { ">", "TouchupDim" } },
	links.build_autolink_segments("<http://link.com>")
)
seg(
	"autolink email",
	{ { "<", "TouchupDim" }, { "user@example.com", "TouchupLinkLabel" }, { ">", "TouchupDim" } },
	links.build_autolink_segments("<user@example.com>")
)

-- ---------------------------------------------------------------------------
-- commentblocks (type extraction and tool region scan)
-- ---------------------------------------------------------------------------
suite("commentblocks")
local commentblocks = require("touchup.commentblocks")

local function type_is(want, line)
	local got = commentblocks.type_of(line)
	ok(got == want, ("type_of %q -> %s"):format(line, tostring(got)))
end
type_is("thinking", "<!-- pitel:thinking")
type_is("error", "<!-- pitel:error")
type_is("tool", '<!-- pitel:tool {"id":"call_1"} -->')
type_is("usage", "<!-- pitel:usage {} -->")
type_is("note", "<!-- note")
type_is("todo", "  <!-- todo: indent ok")
type_is(nil, "<!-- /pitel:tool -->")
type_is(nil, "plain text")
type_is(nil, "--> stray closer")

-- label span covers `pitel:thinking`, not the `<!--` prefix
local t, s, e = commentblocks.type_of("<!-- pitel:thinking")
ok(t == "thinking" and s == 6 and e == 19, "type_of returns pitel: label span")
local t2, s2, e2 = commentblocks.type_of("<!-- note")
ok(t2 == "note" and s2 == 6 and e2 == 9, "type_of returns generic label span")

local region = {
	"<!-- pitel:tool {\"id\":\"c1\",\"name\":\"edit\"} -->", -- 1
	"Successfully replaced 1 block(s) in main.go.",
	"<!-- pitel:ui",
	"```diff",
	"# not a heading, diff context",
	"-->",
	"<!-- /pitel:tool -->", -- 7
	"after",
}
ok(commentblocks.find_tool_end(region, 1) == 7, "find_tool_end finds closer")
ok(commentblocks.find_tool_end({ "<!-- pitel:tool {} -->", "# @user", "<!-- /pitel:tool -->" }, 1) == nil, "find_tool_end stops at heading")
ok(commentblocks.find_tool_end({ "<!-- pitel:tool {} -->", "```", "# @user", "```", "<!-- /pitel:tool -->" }, 1) == 5, "find_tool_end ignores heading inside fence")
ok(commentblocks.find_tool_end({ "<!-- pitel:tool {} -->", "result" }, 1) == nil, "find_tool_end unclosed -> nil")

-- spans: one forward pass over the lines, fence- and comment-aware. Shape is
-- "<srow>-<erow>:<ctype>" per span, erow being the 1-based last covered line.
local function shapes(lines)
	local out = {}
	for _, s in ipairs(commentblocks.spans(lines)) do
		out[#out + 1] = ("%d-%d:%s"):format(s[1], s[2], tostring(s[3]))
	end
	return table.concat(out, " ")
end

ok(shapes({}) == "", "no lines -> no spans")
ok(shapes({ "plain text" }) == "", "no comments -> no spans")
ok(
	shapes({ "<!-- pitel:tool {}", "result", "<!-- /pitel:tool -->" }) == "0-3:tool",
	"tool region is one span, header through closer"
)
ok(
	shapes({
		"<!-- pitel:tool",
		"{",
		'  "name": "write"',
		"}",
		"-->",
		"ok",
		"<!-- /pitel:tool -->",
	}) == "0-7:tool",
	"multi-line header: one span"
)
ok(
	shapes({ "<!-- pitel:thinking", "hmm", "-->" }) == "0-3:thinking",
	"thinking spans to its --> closer"
)
ok(shapes({ "<!-- pitel:usage {} -->" }) == "0-1:usage", "single-line comment is one line")
ok(
	shapes({ "<!-- pitel:tool {}", "<!-- pitel:ui", "```diff", "a", "-->", "<!-- /pitel:tool -->" })
		== "0-6:tool",
	"legacy ui comment is part of the region, not a span of its own"
)
ok(
	shapes({ "```", "<!-- pitel:tool {fake}", "# @user", "```", "<!-- pitel:tool {}", "<!-- /pitel:tool -->" })
		== "4-6:tool",
	"a marker inside a fence is literal content"
)
ok(
	shapes({ "<!-- /pitel:tool -->" }) == "0-1:nil",
	"a closer is a block, just without a label"
)
ok(shapes({ "<!-- note", "body", "-->", "text" }) == "0-3:note", "generic comment block")
ok(shapes({ "text", "<!-- hi -->", "text" }) == "1-2:hi", "single-line comment gets its label")
ok(shapes({ "text", "<!-- -->", "text" }) == "1-2:nil", "wordless comment is a block without a label")
ok(
	shapes({ "# @user", "", "<!-- pitel:tool {}", "unclosed" }) == "2-4:tool",
	"an unclosed region runs to the end of the buffer"
)

-- clear() drops a buffer's cached spans and pending rebuild (BufDelete)
commentblocks.clear(0)
ok(true, "clear(0) does not throw")

-- span cache decision (build once, defer rebuild to idle, like the tree cache)
ok(commentblocks._span_decision(nil, 1, 10) == "first", "no cached spans -> build now")
ok(commentblocks._span_decision({ tick = 1, n = 10 }, 1, 10) == "reuse", "unchanged -> reuse")
ok(commentblocks._span_decision({ tick = 1, n = 10 }, 2, 10) == "defer", "tick changed -> defer")
ok(commentblocks._span_decision({ tick = 1, n = 10 }, 1, 11) == "defer", "line count changed -> defer")

-- ---------------------------------------------------------------------------
-- tree cache decision (parse once per change, defer re-parse to idle)
-- ---------------------------------------------------------------------------
suite("tree cache")
local init = require("touchup")
ok(init._tree_decision(nil, 1) == "first", "no cached tree -> parse now")
ok(init._tree_decision({ tick = 1 }, 1) == "reuse", "unchanged tick -> reuse the tree")
ok(init._tree_decision({ tick = 1 }, 2) == "defer", "changed tick -> serve stale + reparse on idle")

-- ---------------------------------------------------------------------------
-- enter (smart_enter callback)
-- ---------------------------------------------------------------------------
suite("enter")
local api = vim.api

-- Get the <Plug> mapping callback by creating a markdown buffer
local enter_buf = api.nvim_create_buf(false, true)
api.nvim_set_current_buf(enter_buf)
vim.bo[enter_buf].filetype = "markdown"
local enter_cb = assert(
	vim.fn.maparg("<Plug>(touchup-smart-enter)", "i", false, true).callback,
	"<Plug> callback not found"
)

local orig_cursor = api.nvim_win_get_cursor
local orig_feedkeys = api.nvim_feedkeys

---@param lines string[]
---@param cursor integer[]  {row, col} 1-based, 0-based
---@return boolean fed_cr, string[] lines
local function invoke(lines, cursor)
	local b = api.nvim_create_buf(false, true)
	api.nvim_set_current_buf(b)
	vim.bo[b].filetype = "markdown"
	api.nvim_exec_autocmds("FileType", { pattern = "markdown" })
	api.nvim_buf_set_lines(b, 0, -1, false, lines)
	api.nvim_win_get_cursor = function()
		return cursor
	end

	-- Track whether feedkeys was called with <CR> (fallthrough)
	local fed_cr = false
	api.nvim_feedkeys = function(keys, mode, _)
		if keys:match("\r") or keys:match("\n") then
			fed_cr = true
		end
	end

	pcall(enter_cb)
	api.nvim_win_get_cursor = orig_cursor
	api.nvim_feedkeys = orig_feedkeys

	return fed_cr, api.nvim_buf_get_lines(b, 0, -1, false)
end

local function case(name, want_fed_cr, want_lines, lines, cursor)
	local fed_cr, got = invoke(lines, cursor)
	ok(
		vim.deep_equal(got, want_lines) and fed_cr == want_fed_cr,
		name
			.. (not vim.deep_equal(got, want_lines) and (" | lines=" .. vim.inspect(got)) or "")
			.. (fed_cr ~= want_fed_cr and (" | fed_cr=" .. tostring(fed_cr)) or "")
	)
end

case("plain item continues", false, { "- one", "- " }, { "- one" }, { 1, 5 })
case("checked -> unchecked", false, { "- [x] done", "- [ ] " }, { "- [x] done" }, { 1, 10 })
case("custom state -> [ ]", false, { "- [!] imp", "- [ ] " }, { "- [!] imp" }, { 1, 9 })
case("empty item exits", false, { "" }, { "- " }, { 1, 2 })
case("empty checkbox exits", false, { "" }, { "- [ ] " }, { 1, 6 })
case("non-list passthrough", true, { "hello" }, { "hello" }, { 1, 5 })
case("cursor in prefix", true, { "- one" }, { "- one" }, { 1, 1 })
case("mid-item split", false, { "- o", "- ne" }, { "- one" }, { 1, 3 })
case("nested keeps indent", false, { "  - a", "  - " }, { "  - a" }, { 1, 6 })
case("**bold NOT a list", true, { "**something**" }, { "**something**" }, { 1, 14 })
case("bold inside list", false, { "- **bold**", "- " }, { "- **bold**" }, { 1, 10 })
case("** mid not continued", true, { "**something**" }, { "**something**" }, { 1, 3 })
case("* bullet continues", false, { "* one", "* " }, { "* one" }, { 1, 7 })
case("* checked -> unchecked", false, { "* [x] done", "* [ ] " }, { "* [x] done" }, { 1, 12 })
case("* empty exits", false, { "" }, { "* " }, { 1, 2 })
case("* mid split", false, { "* o", "* ne" }, { "* one" }, { 1, 3 })
case("+ bullet continues", false, { "+ one", "+ " }, { "+ one" }, { 1, 7 })
case("+ checked -> unchecked", false, { "+ [x] done", "+ [ ] " }, { "+ [x] done" }, { 1, 12 })
case("numbered dot continues", false, { "1. one", "2. " }, { "1. one" }, { 1, 6 })
case("numbered paren continues", false, { "1) one", "2) " }, { "1) one" }, { 1, 6 })
case("numbered empty exits", false, { "" }, { "1. " }, { 1, 3 })
case("numbered nested", false, { "  5. a", "  6. " }, { "  5. a" }, { 1, 6 })
case("numbered mid split", false, { "1. o", "2. ne" }, { "1. one" }, { 1, 4 })
case("numbered checkbox", false, { "1. [x] done", "2. [ ] " }, { "1. [x] done" }, { 1, 11 })
case("multi-digit: 10. -> 11.", false, { "10. item", "11. " }, { "10. item" }, { 1, 10 })
case("multi-digit: 99. -> 100.", false, { "99. item", "100. " }, { "99. item" }, { 1, 10 })
-- Cursor inside checkbox marker: treated as prefix, falls through
case("cursor inside checkbox [", true, { "- [x] text" }, { "- [x] text" }, { 1, 3 })
case("cursor inside checkbox x", true, { "- [x] text" }, { "- [x] text" }, { 1, 4 })
case("cursor inside checkbox ]", true, { "- [x] text" }, { "- [x] text" }, { 1, 5 })
case("numbered cursor in prefix", true, { "1. one" }, { "1. one" }, { 1, 2 })
case("numbered not a list", true, { "99 bottles" }, { "99 bottles" }, { 1, 10 })
-- Multi-line: continuation on line 1 shouldn't lose line 2
case("multi-line: line 2 preserved", false, { "- a", "- ", "- b" }, { "- a", "- b" }, { 1, 3 })

-- ---------------------------------------------------------------------------
-- indent/dedent: renumber numbered list items
-- ---------------------------------------------------------------------------
suite("indent/dedent")
local shift_fn = require("touchup.enter")._renumber_after_shift

---@param name string
---@param want string   expected line after shift
---@param input string  line under cursor
---@param above string[] lines above the cursor
local function check_shift(name, want, input, above)
	local b = api.nvim_create_buf(false, true)
	api.nvim_set_current_buf(b)
	local all = vim.list_extend(vim.deepcopy(above), { input })
	api.nvim_buf_set_lines(b, 0, -1, false, all)
	api.nvim_win_set_cursor(0, { #all, 0 })
	api.nvim_set_current_buf(b)
	shift_fn()
	local got = api.nvim_buf_get_lines(b, #all - 1, #all, false)[1]
	ok(got == want, name .. " | want=" .. vim.inspect(want) .. " got=" .. vim.inspect(got))
end

-- indent: scan for sibling, else reset to 1
check_shift("indent: sibling 4. follows 3.", "   4. item", "   5. item", { "1. a", "   3. b" })
check_shift("indent: no sibling resets to 1", "   1. item", "   5. item", { "1. a" })
check_shift("indent: checkbox 5. [x] -> 1. [x]", "   1. [x] task", "   5. [x] task", { "1. a" })
check_shift("indent: * bullet unchanged", "   * item", "   * item", { "1. a" })
check_shift("indent: multi-digit 10. -> 1.", "   1. item", "   10. item", { "1. a" })

-- dedent: scan for sibling, else reset to 1
check_shift("dedent: sibling 2. follows 1.", "2. item", "1. item", { "1. first" })
check_shift("dedent: sibling 3. follows 2.", "3. item", "99. item", { "1. a", "2. b" })
check_shift("dedent: no sibling resets to 1", "1. item", "5. item", { "some text" })
check_shift("dedent: skips blank line to find sibling", "3. item", "5. item", { "1. a", "2. b", "" })
check_shift("dedent: skips deeper child, finds parent as sibling", "2. item", "5. item", { "1. parent", "  2. child" })
check_shift("dedent: checkbox follows sibling", "3. [x] task", "99. [x] task", { "1. a", "2. b" })
check_shift("dedent: + bullet unchanged", "+ item", "+ item", { "1. a" })
check_shift("dedent: bullet ignored, resets to 1", "1. item", "5. item", { "- bullet" })
check_shift("dedent: non-list resets to 1", "1. item", "5. item", { "plain text" })

-- ---------------------------------------------------------------------------
print(string.format("\n%d/%d passed, %d failed", checks - failures, checks, failures))
if failures > 0 then
	os.exit(1)
end
