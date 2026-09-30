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
			commentblocks.clear(args.buf)
		end,
	})

	-- Decoration provider: on_win covers every drawn line, so no on_line
	-- callback is needed. Tree-sitter owns the incremental parse cache; parse()
	-- updates it after edits and is a cheap no-op when the buffer is unchanged.
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

			local trees = parser:parse()
			local root = trees and trees[1] and trees[1]:root()
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
				-- Inline trees are needed only for the two inline renderers. Asking the
				-- child parser to parse here keeps them synchronized with this redraw.
				local inline = parser:children().markdown_inline
				local itrees = inline and inline:parse()

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
