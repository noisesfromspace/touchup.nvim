local M = {}

function M.check()
  vim.health.start("touchup")

  -- Neovim version (decoration providers and treesitter highlight defaults)
  if vim.fn.has("nvim-0.10") == 1 then
    vim.health.ok("Neovim " .. vim.version().major .. "." .. vim.version().minor)
  else
    vim.health.error("Neovim 0.10+ required (decoration provider and treesitter API)")
    return
  end

  -- Markdown parser
  local has_md = pcall(vim.treesitter.language.add, "markdown")
  if has_md then
    local ok, msg = pcall(function()
      vim.treesitter.get_parser(vim.api.nvim_create_buf(false, true), "markdown")
    end)
    if ok then
      vim.health.ok("markdown parser found")
    else
      vim.health.warn("markdown parser installed but failed to create parser: " .. tostring(msg))
    end
  else
    vim.health.error("markdown parser not installed (run :TSInstall markdown)")
  end

  -- Markdown inline parser
  local has_inline = pcall(vim.treesitter.language.add, "markdown_inline")
  if has_inline then
    vim.health.ok("markdown_inline parser found")
  else
    vim.health.warn(
      "markdown_inline parser not installed (needed for emphasis marker dimming; run :TSInstall markdown_inline)"
    )
  end

  -- Load modules
  local ok, err = pcall(require, "touchup")
  if ok then
    vim.health.ok("all modules load")
  else
    vim.health.error("module load failed: " .. tostring(err))
  end
end

return M
