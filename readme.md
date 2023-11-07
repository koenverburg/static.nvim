# Static.nvim

> This repo holds some functionality that is treesitter or lsp powered

**Dislaimer this is an opinionated plugin**

## Getting started

Clone the project
```bash
git clone https://github.com/koenverburg/static.nvim.git
```

Then cd into the directory and launch nvim using the following command

```bash
nvim --cmd "set rtp+=$(pwd)"
```

After this you can call the plugin with the following command
This will setup start the following treesitter based actions
- Early exit
- Highlight named imports
- Highlight default exports
- Score of cyclomatic complexity


```lua
require('static').setup()
```

```lua
-- Folding using Treesitter
normal("<leader>fi", "<cmd>lua require 'static.treesitter'.fold_imports()<cr>")
normal("<leader>fr", "<cmd>lua require('static.treesitter').region()<cr>")

```
