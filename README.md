# touchup.nvim

Tiny markdown tweaks that don't shift your layout. List bullets get depth-aware icons, checkboxes get state indicators, code blocks get a background. Everything uses overlays: icons sit on top of markers, your text **never** jumps out of sight.

No hidden URLs, no resized headings, no conceal jumping. Tables and alignment are the formatter's job. Pair this with [mdformat](https://github.com/hukkin/mdformat) and [mdformat-space-control](https://github.com/jdmonaco/mdformat-space-control) for table support.

## What it does

- **List bullets** get icons that change with nesting depth (✸ ✿ ✦ ✧). Checkbox and numbered lists stay as-is.
- **Checkboxes** show state icons inside [ ] without concealing brackets or jumping text.
- **Code blocks** get a subtle background.
- **Hitting Enter** on a list item auto-continues at the same level. Press Enter on an empty item to exit.
- **H1 and H2** get underline styling without hiding the # markers.
- **Block quotes** keep whatever your colorscheme gives them.

## Install

```lua
{ "noisesfromspace/touchup.nvim", opts = {} }
```

## Config

```lua
require("touchup").setup({
  bullets = { icons = { "✸", "✿", "✦", "✧" } },
  code_blocks = { enabled = true },
  headings = { h1 = { bold = true, underline = true }, h2 = { underline = true } },
  enter = { enabled = true },
})
```

## The rest of the stack

| Tool                                                                         | Does                                             |
| ---------------------------------------------------------------------------- | ------------------------------------------------ |
| [markdown-oxide](https://github.com/Feel-ix-343/markdown-oxide)              | LSP: completions, diagnostics, symbol navigation |
| [mdformat](https://github.com/hukkin/mdformat)                               | Formats markdown consistently                    |
| [mdformat-space-control](https://github.com/jdmonaco/mdformat-space-control) | Keeps lists tight, no random blank lines         |
| [conform.nvim](https://github.com/stevearc/conform.nvim)                     | Runs mdformat on save                            |
