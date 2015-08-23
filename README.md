# Vim mode module for Textadept

Basic vim modal editing mode for the Textadept text editor. It uses the modal keybinding feature.

## Features

At the moment this plugin is not feature complete, I mostly add new bindings whenever I find myself using one that is not yet implmented.

But it has:

- Basic movement (h/j/k/l, w/b/e, $/^/0, etc.)
- Basic editing (a/A, o/O, x, dd, dw, db, d$, d^, etc.)
- Basic quickmarks (ma-z and 'a-z), atm its shared among all buffers.
- Very basic ex mode (:w and :q works)

See `src/vim.lua` for full keybindings.

## Usage

Download `src/vim.lua` to `~/.textadept` and add this line to your `init.lua`:

```lua
require('vim')
```
