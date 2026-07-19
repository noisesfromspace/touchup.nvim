# touchup.nvim

Tiny markdown tweaks that don't shift your layout. List bullets get depth-aware icons, checkboxes get state indicators, code blocks get a background. Everything uses overlays: icons sit on top of markers, your text **never** jumps out of sight.

No hidden URLs, no resized headings, no conceal jumping. Tables and alignment are the formatter's job. Pair this with [mdformat](https://github.com/hukkin/mdformat) and [mdformat-space-control](https://github.com/jdmonaco/mdformat-space-control) for table support.

## What it does

- **List bullets** get icons that change with nesting depth (✸ ✿ ✦ ✧), "We have org mode at home".jpg
- **Checkboxes** show obsidian-style state icons inside [ ] without concealing brackets or jumping text.
- **Code blocks** get a subtle background.
- **Hitting Enter** on a list item auto-continues at the same level (checkboxes continue unchecked). Press Enter on an empty item to exit.
- **H1 and H2** get underline styling without hiding the # markers.
- **Block quotes** are transformed to cursive.

<img width="1283" height="925" alt="screenshot_2026-07-15_16:31:41" src="https://github.com/user-attachments/assets/b4184109-1c16-4b00-944d-aa2639cd9f7a" />

## Install

```lua
{ "noisesfromspace/touchup.nvim", opts = {} }
```

## Config

```lua
require("touchup").setup({
  bullets = { icons = { "✸", "✿", "✦", "✧" } },
  code_blocks = { enabled = true },
  checkboxes = { enabled = true },
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
