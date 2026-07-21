-- touchup.nvim test runner -- pure logic, no parsers or pty needed
--
-- Run: nvim --headless --clean '+lua vim.opt.rtp:prepend(".")' -l tests/run.lua

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
ok(cfg.headings == nil, "headings config removed")

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
-- enter (smart_enter callback)
-- ---------------------------------------------------------------------------
suite("enter")
local api = vim.api

-- Get the buffer-local <CR> callback by creating a markdown buffer
local enter_buf = api.nvim_create_buf(false, true)
api.nvim_set_current_buf(enter_buf)
vim.bo[enter_buf].filetype = "markdown"
local enter_cb = assert(vim.fn.maparg("<CR>", "i", false, true).callback, "enter callback not found")

local orig_cursor = api.nvim_win_get_cursor

---@param lines string[]
---@param cursor integer[]  {row, col} 1-based, 0-based
---@return string? ret, string[] lines
local function invoke(lines, cursor)
  local b = api.nvim_create_buf(false, true)
  api.nvim_set_current_buf(b)
  vim.bo[b].filetype = "markdown"  -- filetype detection won't fire in --clean
  api.nvim_exec_autocmds("FileType", { pattern = "markdown" })
  api.nvim_buf_set_lines(b, 0, -1, false, lines)
  api.nvim_win_get_cursor = function()
    return cursor
  end
  local ok_ret, ret = pcall(enter_cb)
  api.nvim_win_get_cursor = orig_cursor
  vim.wait(50, function() return false end)  -- flush vim.schedule
  if not ok_ret then
    return "ERROR: " .. tostring(ret), {}
  end
  return ret, api.nvim_buf_get_lines(b, 0, -1, false)
end

local function case(name, want_ret, want_lines, lines, cursor)
  local ret, got = invoke(lines, cursor)
  ok(ret == want_ret and vim.deep_equal(got, want_lines),
    name .. (ret ~= want_ret and (" | ret=" .. vim.inspect(ret)) or "")
    .. (not vim.deep_equal(got, want_lines) and (" | lines=" .. vim.inspect(got)) or ""))
end

case("plain item continues", "", { "- one", "- " }, { "- one" }, { 1, 5 })
case("checked -> unchecked", "", { "- [x] done", "- [ ] " }, { "- [x] done" }, { 1, 10 })
case("custom state -> [ ]", "", { "- [!] imp", "- [ ] " }, { "- [!] imp" }, { 1, 9 })
case("empty item exits", "", { "" }, { "- " }, { 1, 2 })
case("empty checkbox exits", "", { "" }, { "- [ ] " }, { 1, 6 })
case("non-list passthrough", "<CR>", { "hello" }, { "hello" }, { 1, 5 })
case("cursor in prefix", "<CR>", { "- one" }, { "- one" }, { 1, 1 })
case("mid-item split", "", { "- o", "- ne" }, { "- one" }, { 1, 3 })
case("nested keeps indent", "", { "  - a", "  - " }, { "  - a" }, { 1, 6 })
case("**bold NOT a list", "<CR>", { "**something**" }, { "**something**" }, { 1, 14 })
case("bold inside list", "", { "- **bold**", "- " }, { "- **bold**" }, { 1, 10 })
case("** mid not continued", "<CR>", { "**something**" }, { "**something**" }, { 1, 3 })

-- ---------------------------------------------------------------------------
print(string.format("\n%d/%d passed, %d failed", checks - failures, checks, failures))
if failures > 0 then
  os.exit(1)
end
