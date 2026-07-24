# touchup.nvim

Markdown improvements that don't move your text around.

Most markdown plugins make notes prettier by hiding things: URLs collapse, multiple heading symbols turn into single icons, `**` markers vanish until the cursor lands on them. touchup goes the other way. Icons, backgrounds and colors are drawn on top of the text you typed, so the buffer never reflows and nothing jumps when you move the cursor.

![screenshot](example.png)

## What it does

- List bullets get icons that change with nesting depth (✸ ✿ ✦ ✧). _"We have org mode at home".jpg_
- Checkboxes show obsidian-style state icons inside the brackets: `[x]`, `[ ]`, `[!]`, `[>]` and more.
- Code blocks and block quotes get a subtle background. Quotes also render in cursive.
- `**`, `~~` and backtick markers are dimmed, not hidden.
- Link brackets, parens and URLs are dimmed so labels read like prose.
- GFI admonitions (`[!NOTE]`, `[!WARNING]`, etc.) get type-colored labels.
- H1 and H2 get underlines. The `#` markers stay where they are.
- Enter continues a list item (a checkbox item continues unchecked). Enter on an empty item exits the list.

## What it won't do

- Conceal URLs, syntax markers or anything else you typed.
- Format tables. Alignment is a formatter's job.
- Completions, diagnostics or wiki links. This is for a LSP server.
- Support anything other than Markdown

Needs the `markdown` and `markdown_inline` treesitter parsers.

## Install

```lua
{ "noisesfromspace/touchup.nvim", opts = {} }
```

## Config

Everything below is the default; pass only what you want to change.

```lua
require("touchup").setup({
  filetypes = { "markdown" },
  bullets = { enabled = true, icons = { "✸", "✿", "✦", "✧" } },
  checkboxes = {
    enabled = true,
    -- Obsidian-style checkbox states. Standard `[ ]`/`[x]` are handled via
    -- treesitter; every other key is matched by a regex fallback against
    -- `- [<char>]` / `* [<char>]` / `+ [<char>]`.
    icons = {
      ["x"] = { text = "󰗠", hl = "TouchupCheckboxChecked" },
      ["X"] = { text = "󰗠", hl = "TouchupCheckboxChecked" },
      ["/"] = { text = "󱎖", hl = "TouchupCheckboxPending" },
      [">"] = { text = "", hl = "TouchupCheckboxCancelled" },
      ["<"] = { text = "󰃖", hl = "TouchupCheckboxCancelled" },
      ["-"] = { text = "󰍶", hl = "TouchupCheckboxCancelled" },
      ["?"] = { text = "󰋗", hl = "TouchupCheckboxPending" },
      ["!"] = { text = "󰀦", hl = "TouchupCheckboxImportant" },
      ["*"] = { text = "󰓎", hl = "TouchupCheckboxPending" },
      ['"'] = { text = "󰸥", hl = "TouchupCheckboxCancelled" },
      ["l"] = { text = "󰆋", hl = "TouchupCheckboxProgress" },
      ["b"] = { text = "󰃀", hl = "TouchupCheckboxProgress" },
      ["i"] = { text = "󰰄", hl = "TouchupCheckboxChecked" },
      ["S"] = { text = "", hl = "TouchupCheckboxChecked" },
      ["I"] = { text = "󰛨", hl = "TouchupCheckboxPending" },
      ["p"] = { text = "", hl = "TouchupCheckboxChecked" },
      ["c"] = { text = "", hl = "TouchupCheckboxUnchecked" },
      ["f"] = { text = "󱠇", hl = "TouchupCheckboxUnchecked" },
      ["k"] = { text = "", hl = "TouchupCheckboxPending" },
      ["w"] = { text = "", hl = "TouchupCheckboxProgress" },
      ["u"] = { text = "󰔵", hl = "TouchupCheckboxChecked" },
      ["d"] = { text = "󰔳", hl = "TouchupCheckboxUnchecked" },
    },
  },
  code_blocks = { enabled = true },
  markers = { enabled = true },
  quotes = { enabled = true },
  enter = { enabled = true },
})
```

`checkboxes.icons` is merged per key: pass only the states you want to change or
add and the rest keep their default icon.

```lua
require("touchup").setup({
  checkboxes = {
    icons = {
      ["x"] = { text = "✔", hl = "MyChecked" }, -- restyle an existing state
      ["z"] = { text = "💤", hl = "MyCustom" }, -- add a brand-new one: [z]
    },
  },
})
```

Unchecked (`[ ]`) always renders as a plain space and isn't customizable.

All highlight groups are defined with `default = true`, so your colorscheme wins. Override any `Touchup*` group if you want different colors.

## The rest of the stack

touchup only decorates. This is the setup it is built to sit next to:

| Tool                                                            | Does                                             |
| --------------------------------------------------------------- | ------------------------------------------------ |
| [markdown-oxide](https://github.com/Feel-ix-343/markdown-oxide) | LSP: completions, diagnostics, symbol navigation |
| [mdformat](https://github.com/hukkin/mdformat)                  | Formats markdown, including tables               |
| [conform.nvim](https://github.com/stevearc/conform.nvim)        | Runs mdformat on save                            |
