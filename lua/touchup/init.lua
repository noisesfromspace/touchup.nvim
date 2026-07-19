local M = {}

local api = vim.api

local config = require("touchup.config")
local hl = require("touchup.hl")
local bullets = require("touchup.bullets")
local codeblocks = require("touchup.codeblocks")
local checkboxes = require("touchup.checkboxes")
local enter = require("touchup.enter")

local NAMESPACE = api.nvim_create_namespace("touchup")
local ticks = {}

---@param user? table
function M.setup(user)
  local cfg = config.merge(user)
  hl.setup()

  -- Smart Enter
  if cfg.enter.enabled then
    api.nvim_create_autocmd("FileType", {
      pattern = "markdown",
      callback = function(args)
        enter.setup(args.buf)
      end,
    })
  end

  -- Decoration provider: parse treesitter once per window redraw, share the
  -- tree across all modules. on_win alone covers every drawn line, so no
  -- on_line callback is needed.
  api.nvim_set_decoration_provider(NAMESPACE, {
    on_start = function(_, tick)
      local buf = api.nvim_get_current_buf()
      if ticks[buf] == tick then
        return false
      end
      ticks[buf] = tick
      return true
    end,
    on_win = function(_, _, bufnr, topline, botline)
      if vim.bo[bufnr].filetype ~= "markdown" then
        return false
      end

      local parser = vim.treesitter.get_parser(bufnr, "markdown", {})
      local trees = parser and parser:parse()
      local root = trees and trees[1] and trees[1]:root()
      if not root then
        return false
      end

      if cfg.bullets.enabled then
        bullets.render(NAMESPACE, bufnr, cfg.bullets.icons, topline, botline, root)
      end

      if cfg.code_blocks.enabled then
        codeblocks.render(NAMESPACE, bufnr, topline, botline, root)
      end

      if cfg.checkboxes.enabled then
        checkboxes.render(NAMESPACE, bufnr, topline, botline, root)
      end
    end,
  })
end

return M
