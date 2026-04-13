# c3.nvim

Neovim plugin for the [C3 programming language](https://c3-lang.org).

## Features

- **Filetype detection:** Native support for `.c3`, `.c3i`, and `.c3t`.
- **LSP:** Auto-detects, downloads, and runs [tonis2/lsp](https://github.com/tonis2/lsp).
- **Tree-Sitter:** Auto-compiles [tree-sitter-c3](https://github.com/c3lang/tree-sitter-c3), with basic syntax fallback.
- **Formatting:** Provides `:C3Format` and `:Format` wrappers for [c3fmt](https://github.com/lmichaudel/c3fmt).

## Dependencies

- `git` and a C compiler (`cc`, `gcc`, `clang`, or `zig cc`) to compile the tree-sitter parser.
- `curl` and `unzip` (or `tar`) to download the LSP binary.
- `curl` to auto-download the `c3fmt` binary.

## Installation

### lazy.nvim
```lua
{
  "c3lang/c3.nvim",
  config = true,
}
```

### vim-plug
```vim
Plug 'c3lang/c3.nvim'
```

### packer.nvim
```lua
use {
  'c3lang/c3.nvim',
  config = function()
    require("c3").setup()
  end
}
```

## Configuration

Settings are optional. Default values:

```lua
require("c3").setup({
  format_on_save = false, -- Auto-format via BufWritePre
  format_cmd = "c3fmt",   -- Executable in PATH
  lsp_cmd = "c3lsp",      -- Executable in PATH
  highlighting = {
    enable_treesitter = true,
  }
})
```
