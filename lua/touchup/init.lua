local M = {}

local api, treesitter = vim.api, vim.treesitter

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

  -- Decoration provider
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

      -- Parse treesitter once, share across all modules
      local parser = vim.treesitter.get_parser(bufnr, "markdown", {})
      local trees = parser and parser:parse()
      local root = trees and trees[1] and trees[1]:root()

      if cfg.bullets.enabled then
        bullets.render(NAMESPACE, bufnr, cfg.bullets.icons, topline, botline, root)
      end

      if cfg.code_blocks.enabled then
        codeblocks.render(NAMESPACE, bufnr, topline, botline, root)
      end

      checkboxes.render(NAMESPACE, bufnr, topline, botline, root)
    end,
    on_line = function(_, _, bufnr, row)
      if vim.bo[bufnr].filetype ~= "markdown" then
        return false
      end

      if cfg.bullets.enabled then
        bullets.render(NAMESPACE, bufnr, cfg.bullets.icons, row, row + 1)
      end
      checkboxes.render(NAMESPACE, bufnr, row, row + 1)
    end,
  })
end

return M
