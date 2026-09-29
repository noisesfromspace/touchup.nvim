local M = {}

local api = vim.api

local config = require("touchup.config")
local hl = require("touchup.hl")
local bullets = require("touchup.bullets")
local codeblocks = require("touchup.codeblocks")
local commentblocks = require("touchup.commentblocks")
local checkboxes = require("touchup.checkboxes")
local markers = require("touchup.markers")
local quotes = require("touchup.quotes")
local admonitions = require("touchup.admonitions")
local links = require("touchup.links")
local enter = require("touchup.enter")

local NAMESPACE = api.nvim_create_namespace("touchup")
local GROUP = api.nvim_create_augroup("Touchup", { clear = true })
local attached = {}

-- Treesitter tree cache, keyed by buffer. The tree is re-parsed at most once
-- per buffer change, and only after the buffer has been quiet for IDLE_MS: a
-- reply streaming in is a stream of small edits, and a whole-document reparse
-- per chunk is what made holding j/k lag mid-stream (a 24k-line session
-- re-parse costs tens to hundreds of ms, depending on which block the tail is
-- inside). Serving the last tree while the buffer changes is safe for a
-- streamed tail append (the tree simply has no nodes for the new lines); a
-- mid-buffer edit is only transiently stale for that IDLE_MS window.
local parse_cache = {} -- bufnr -> { tick, root, itrees }
local refresh_timers = {} -- bufnr -> timer
-- 1.5s: long enough that ordinary typing pauses don't trigger a full
-- re-parse (250ms fired between words), short enough that a streamed reply
-- settles promptly once it stops.
local IDLE_MS = 1500

--- Pure cache decision, separated from the provider so it is unit-testable:
--- how to source the tree for a redraw.
---   "first"  no cached tree: parse now (one-time cold cost on open)
---   "reuse"  buffer unchanged since the last parse: use the cached tree
---   "defer"  buffer changed: serve the cached tree and re-parse when idle
function M._tree_decision(entry, tick)
	if not entry then
		return "first"
	end
	if entry.tick == tick then
		return "reuse"
	end
	return "defer"
end

--- Re-parse the whole buffer and refresh the markdown_inline injections. This
--- is the expensive part, so it runs only on first parse and after the buffer
--- has been idle, never on every redraw. parse(true) (rather than a bare
--- parse()) is what forces a full parse and gives the inline child its trees.
local function full_reparse(bufnr, parser)
	local trees = parser:parse(true)
	local root = trees and trees[1] and trees[1]:root()
	if not root then
		return nil
	end
	local inline = parser:children().markdown_inline
	local itrees = inline and inline:parse(true)
	return { tick = api.nvim_buf_get_changedtick(bufnr), root = root, itrees = itrees }
end

--- Schedule a re-parse once the buffer has been stable for IDLE_MS. Each edit
--- that keeps arriving (a streaming reply) pushes the re-parse further out, so
--- it fires once when the stream pauses, not once per chunk.
local function schedule_reparse(bufnr, parser)
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
		local ok, c = pcall(full_reparse, bufnr, parser)
		if ok and c then
			parse_cache[bufnr] = c
		end
	end, IDLE_MS)
end

---@param user? table
function M.setup(user)
	local cfg = config.merge(user)
	hl.setup()

	-- Smart Enter
	if cfg.enter.enabled then
		api.nvim_create_autocmd("FileType", {
			group = GROUP,
			pattern = cfg.filetypes,
			callback = function(args)
				if attached[args.buf] then
					return
				end
				attached[args.buf] = true
				enter.setup(args.buf)
			end,
		})
	end

	-- Clean up tracking state when a buffer is deleted. No pattern:
	-- BufDelete matches buffer names, not filetypes, so a filetype pattern
	-- would silently never fire.
	api.nvim_create_autocmd("BufDelete", {
		group = GROUP,
		callback = function(args)
			attached[args.buf] = nil
			parse_cache[args.buf] = nil
			local t = refresh_timers[args.buf]
			if t then
				t:stop()
				t:close()
			end
			refresh_timers[args.buf] = nil
			commentblocks.clear(args.buf)
		end,
	})

	-- Decoration provider: on_win covers every drawn line, so no on_line
	-- callback is needed. The tree is cached and re-parsed only on a buffer
	-- change after an idle gap (see full_reparse), not on every redraw.
	api.nvim_set_decoration_provider(NAMESPACE, {
		on_win = function(_, _, bufnr, topline, botline)
			if not vim.tbl_contains(cfg.filetypes, vim.bo[bufnr].filetype) then
				return false
			end

			-- get_parser throws if the markdown grammar isn't installed
			local ok, parser = pcall(vim.treesitter.get_parser, bufnr, "markdown")
			if not ok then
				return false
			end

			local tick = api.nvim_buf_get_changedtick(bufnr)
			local c = parse_cache[bufnr]
			local action = M._tree_decision(c, tick)

			local root, itrees
			if action == "reuse" then
				root, itrees = c.root, c.itrees
			elseif action == "first" then
				c = full_reparse(bufnr, parser)
				parse_cache[bufnr] = c
				root = c and c.root
				itrees = c and c.itrees
			else -- "defer"
				root, itrees = c.root, c.itrees
				schedule_reparse(bufnr, parser)
			end

			if not root then
				return false
			end

			-- botline is the last drawn line, inclusive; render ranges are exclusive
			local last = botline + 1

			if cfg.bullets.enabled then
				bullets.render(NAMESPACE, bufnr, cfg.bullets.icons, topline, last, root)
			end

			if cfg.code_blocks.enabled then
				codeblocks.render(NAMESPACE, bufnr, topline, last, root)
			end

			if cfg.comment_blocks.enabled then
				commentblocks.render(NAMESPACE, bufnr, topline, last)
			end

			if cfg.checkboxes.enabled then
				checkboxes.render(NAMESPACE, bufnr, cfg.checkboxes.icons, topline, last, root)
			end

			if cfg.quotes.enabled then
				quotes.render(NAMESPACE, bufnr, topline, last, root)
			end

			if cfg.admonitions.enabled then
				admonitions.render(NAMESPACE, bufnr, topline, last, root)
			end

			-- When conceallevel > 0, Vim visually removes formatting characters
			-- (*, _, `, ~) which shifts visual column positions relative to
			-- buffer positions. This breaks extmark column coordinates used by
			-- links and markers.
			local winid = vim.fn.win_findbuf(bufnr)[1]
			local conceal = winid and vim.wo[winid].conceallevel or 0

			if conceal == 0 then
				if cfg.links.enabled then
					links.render(NAMESPACE, bufnr, topline, last, itrees, root)
				end

				if cfg.markers.enabled then
					markers.render(NAMESPACE, bufnr, topline, last, itrees, root)
				end
			end
		end,
	})
end

return M
