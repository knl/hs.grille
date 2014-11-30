# Mjolnir.grille

A module for moving/resizing your windows along a virtual and
horizontal grid(s), using a fluent interface (see Usage below).

`mjolnir.grille` was based on `mjolnir.sd.grid` (can't find it
anymore) and
[mjolnir.bg.grid](https://github.com/BrianGilbert/mjolnir.bg.grid)
modules, but went through significant modifications to suit my
workflows. For example, it allows one to use multiple grids
at the same time and uses a fluent interface, so the intentions are
more readable.

The grid is an partition of your screen; by default it is 3x3, that is, 3 cells wide by 3 cells tall.

Grid cells are just a table with keys: x, y, w, h

For a grid of 2x2:

* a cell {x=0, y=0, w=1, h=1} will be in the upper-left corner
* a cell {x=1, y=0, w=1, h=1} will be in the upper-right corner
* and so on...

## Usage

    local grid = require "mjolnir.grille"

    -- default grid is 3x3
    local grid33 = grid:new(3, 3)
    local grid42 = grid:new(4, 2)

    local cmdalt  = {"cmd", "alt"}
    local scmdalt  = {"cmd", "alt", "shift"}
    local ccmdalt = {"ctrl", "cmd", "alt"}

     -- move windows as per grid segments
     hotkey.bind(cmdalt, 'LEFT', grid33:focused():left():move())
     hotkey.bind(cmdalt, 'RIGHT', grid33:focused():right():move())

     -- resize windows to grid
     hotkey.bind(scmdalt, 'LEFT', grid33:focused():thinner():resize())
     hotkey.bind(scmdalt, 'RIGHT', grid33:focused():wider():resize())

     -- on a 3x3 grid make a 2x3 window and place it on left
     hotkey.bind(cmdalt, 'h', grid33:focused():wide(2):tallest():leftmost():place())

     -- on a 3x3 grid make a 1x3 window and place it rightmost
     hotkey.bind(cmdalt, 'j', grid33:focused():tallest():rightmost():place())

*NOTE*: One must start with `grid:focused()` or `grid:window('title')`
and end with a command `move()`, `place()`, `resize()`, or `act()`
(they are all synonyms for the same action). This chain of command
will return a function that one can pass to hotkey.bind.
