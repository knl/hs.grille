--- === mjolnir.grille ===
---
--- A module for moving/resizing your windows along a virtual and horizontal grid(s),
--- using a fluent interface (see Usage below).
---
--- mjolnir.grille was based on mjolnir.sd.grid and mjolnir.bg.grid modules, but went through
--- significant modifications to suit my workflows. For example, it allows one to use multiple grids
--- at the same time and uses a fluent interface, so the intentions are more readable.
---
--- The grid is an partition of your screen; by default it is 3x3, i.e. 3 cells wide by 3 cells tall.
---
--- Grid cells are just a table with keys: x, y, w, h
---
--- For a grid of 2x2:
---
--- * a cell {x=0, y=0, w=1, h=1} will be in the upper-left corner
--- * a cell {x=1, y=0, w=1, h=1} will be in the upper-right corner
--- * and so on...
---
--- Usage:
---   local grid = require "mjolnir.grille"
---
---   -- default grid is 3x3
---   local grid33 = grid:new(3, 3)
---   local grid42 = grid:new(4, 2)
---
---   local cmdalt  = {"cmd", "alt"}
---   local scmdalt  = {"cmd", "alt", "shift"}
---   local ccmdalt = {"ctrl", "cmd", "alt"}
---
---    == the code below needs to be reworked ==
---    -- move windows as per grid segments
---    hotkey.bind(cmdalt, 'LEFT', grid33:focused():left():move())
---    hotkey.bind(cmdalt, 'RIGHT', grid33:focused():right():move())
---
---    -- resize windows to grid
---    hotkey.bind(scmdalt, 'LEFT', grid33:focused():thinner():resize())
---    hotkey.bind(scmdalt, 'RIGHT', grid33:focused():wider():resize())
---
---    -- on a 3x3 grid make a 2x3 window and place it on left
---    hotkey.bind(cmdalt, 'h', grid33:focused():wide(2):tallest():leftmost():place())
---
---    -- on a 3x3 grid make a 1x3 window and place it rightmost
---    hotkey.bind(cmdalt, 'j', grid33:focused():tallest():rightmost():place())
---
---  defaults are:
---    1 cell wide, 1 cell tall, top-left corner, focused window
---
---  One must start with grid:focused() or grid:window('title') and end with a command move(),
---  place(), resize(), or act() (they are all synonyms for the same action). This chain of
---  command will return a function that one can pass to hotkey.bind.
---
---
--- [Github Page](https://github.com/knl/mjolnir.grille)
---
--- @author    Nikola Knezevic
--- @copyright 2014
--- @license   BSD
---
--- @module mjolnir.grille
local grille = {}

local appfinder = require "mjolnir.cmsj.appfinder"
local fnutils = require "mjolnir.fnutils"
local window = require "mjolnir.window"
local alert = require "mjolnir.alert"


-- class table
Grille = {}

local function round(num, idp)
  local mult = 10^(idp or 0)
  return math.floor(num * mult + 0.5) / mult
end

--- mjolnir.grille.new(width, height)
--- Function
--- Creates a new Grille object with given width and height. Default width and height are 3.
function grille.new(_width, _height)
  local self = {
    -- The number of vertical cells of the grid (default 3)
    height = math.max(_height or 3, 1),

    -- The number of horizontal cells of the grid
    width = math.max(_width or 3, 1),

    -- The margin between each window horizontally.
    xmargin = 0,

    -- The margin between each window vertically.
    ymargin = 0
  }

  setmetatable(self, { __index = Grille })
  return self
end

-- class table representing an action on a window
GrilleAction = {}

local function init_grille_action(g, title)
  return {
    -- title, '' to denote the focused one
    title = title,
    -- grid
    grid = g,
    -- location
    x = -1,
    y = -1,
    -- dimensions
    w = 0,
    h = 0,
    -- changes accrued in the methods
    dx = 0,
    dy = 0,
    dw = 0,
    dh = 0,
    -- 'mosts'
    _leftmost = false,
    _rightmost = false,
    _topmost = false,
    _bottommost = false,
  }
end

--- mjolnir.Grille:focused()
--- Function
--- Creates a new GrilleAction object for the focused window
function Grille:focused()
  _self = init_grille_action(self, '')
  setmetatable(_self, { __index = GrilleAction })
  return _self
end

--- mjolnir.Grille:window(title)
--- Function
--- Creates a new GrilleAction object for the main window of the app titled 'title'
function Grille:window(title)
  assert(title and title ~= '', 'Cannot find a window without a title')
  _self = init_grille_action(self, title)
  setmetatable(_self, { __index = GrilleAction })
  return _self
end

--- mjolnir.grille:get(win)
--- Function
--- Gets the cell this window is on
function Grille:get(win)
  local winframe = win:frame()
  local screenrect = win:screen():frame()
  local screenwidth = screenrect.w / self.width
  local screenheight = screenrect.h / self.height
  return {
    x = round((winframe.x - screenrect.x) / screenwidth),
    y = round((winframe.y - screenrect.y) / screenheight),
    w = math.max(1, round(winframe.w / screenwidth)),
    h = math.max(1, round(winframe.h / screenheight)),
  }
end

--- mjolnir.grille:set(win, grid, screen)
--- Function
--- Sets the cell this window should be on
function Grille:set(win, cell, screen)
  local screenrect = screen:frame()
  local screenwidth = screenrect.w / self.width
  local screenheight = screenrect.h / self.height
  local newframe = {
    x = (cell.x * screenwidth) + screenrect.x,
    y = (cell.y * screenheight) + screenrect.y,
    w = cell.w * screenwidth,
    h = cell.h * screenheight,
  }

  newframe.x = newframe.x + self.xmargin
  newframe.y = newframe.y + self.ymargin
  newframe.w = newframe.w - (self.xmargin * 2)
  newframe.h = newframe.h - (self.ymargin * 2)

  win:setframe(newframe)
end

--- mjolnir.grille:snap(win)
--- Function
--- Snaps the window into a cell
function Grille:snap(win)
  if win:isstandard() then
    self:set(win, self:get(win), win:screen())
  end
end

--- mjolnir.grille:fits_cell(win)
--- Function
--- Returns whether a window fits cells (doesn't need readjustments)
function Grille:fits_cell(win)
  local winframe = win:frame()
  local screenrect = win:screen():frame()
  local screenwidth = screenrect.w / self.width
  local screenheight = screenrect.h / self.height
  return ((winframe.x - screenrect.x) % screenwidth == 0)
         and ((winframe.y - screenrect.y) % screenheight == 0)
end

--- mjolnir.grille.adjust_focused_window(fn)
--- Function
--- Passes the focused window's cell to fn and uses the result as its new cell.
function Grille:adjust_focused_window(fn)
  local win = window.focusedwindow()
  local cell = self:get(win)
  fn(cell)
  self:set(win, cell, win:screen())
end

--- mjolnir.grille.maximize_window()
--- Function
--- Maximizes the focused window along the given cell.
function Grille:maximize_window()
  local win = window.focusedwindow()
  local cell = {x = 0, y = 0, w = self.width, h = grid.height}
  grid.set(win, cell, win:screen())
end

--- mjolnir.grille.pushwindow_nextscreen()
--- Function
--- Moves the focused window to the next screen, using its current cell on that screen.
function Grille:pushwindow_nextscreen()
  local win = window.focusedwindow()
  grid.set(win, grid.get(win), win:screen():next())
end

--- mjolnir.grille.pushwindow_prevscreen()
--- Function
--- Moves the focused window to the previous screen, using its current cell on that screen.
function Grille:pushwindow_prevscreen()
  local win = window.focusedwindow()
  grid:set(win, grid.get(win), win:screen():previous())
end

function GrilleAction:xpos(x)
  self.x = math.min(self.grid.width, math.max(0, x))
  return self
end

function GrilleAction:ypos(y)
  self.y = math.min(self.grid.height, math.max(0, y))
  return self
end

function GrilleAction:right()
  if self.x ~= -1 then
    self.x = math.min(self.grid.width-self.w, self.x+1)
  else
    self.dx = 1
  end
  return self
end

function GrilleAction:left()
  if self.x ~= -1 then
    self.x = math.max(0, self.x-1)
  else
    self.dx = -1
  end
  return self
end

function GrilleAction:up()
  if self.y ~= -1 then
    self.y = math.max(0, self.y-1)
  else
    self.dy = -1
  end
  return self
end

function GrilleAction:down()
  if self.y ~= -1 then
    self.y = math.min(self.grid.height-self.h, self.y+1)
  else
    self.dy = 1
  end
  return self
end

function GrilleAction:wide(w)
  self.w = math.min(self.grid.width, math.max(1, w or 1))
  return self
end

function GrilleAction:tall(h)
  self.h = math.min(self.grid.height, math.max(1, h or 1))
  return self
end

function GrilleAction:thinner(by)
  if self.w ~= 0 then
    self.w = math.min(self.grid.width, math.max(1, self.w - (by or 1)))
  else
    self.dw = -1 * math.max(1, by or 1)
  end
  return self
end

function GrilleAction:wider(by)
  if self.w ~= 0 then
    self.w = math.min(self.grid.width, math.max(1, self.w + (by or 1)))
  else
    self.dw = math.max(1, by or 1)
  end
  return self
end

function GrilleAction:taller(by)
  if self.h ~= 0 then
    self.h = math.min(self.grid.height, math.max(1, self.h + (by or 1)))
  else
    self.dh = math.max(1, by or 1)
  end
  return self
end

function GrilleAction:shorter(by)
  if self.h ~= 0 then
    self.h = math.min(self.grid.height, math.max(1, self.h - (by or 1)))
  else
    self.dh = -1 * math.max(1, by or 1)
  end
  return self
end

function GrilleAction:tallest()
  self.h = self.grid.height
  return self
end

function GrilleAction:widest()
  self.w = self.grid.width
  return self
end

function GrilleAction:leftmost()
  self.dx = 0
  self._leftmost = true
  return self
end

function GrilleAction:rightmost()
  self.dx = 0
  self._rightmost = true
  return self
end

function GrilleAction:topmost()
  self.dy = 0
  self._topmost = true
  return self
end

function GrilleAction:bottommost()
  self.dy = 0
  self._bottommost = true
  return self
end

function GrilleAction:act()
  return function()
    local f = {}
    local win = nil
    if title then
       local app = appfinder.app_from_name(title)
       win = app:mainwindow()
       -- alert.show(string.format('application title for %q is %q, main window %q', title, app:title(), window:title()))
    else
      win = window.focusedwindow()
    end

    local origf = self.grid:get(win)
    -- print(string.format("origf x=%d, y=%d, w=%d, h=%d", origf.x, origf.y, origf.w, origf.h))
    -- print(string.format("self x=%d, y=%d, w=%d, h=%d", self.x, self.y, self.w, self.h))
    -- print(string.format("self dx=%d, dy=%d, dw=%d, dh=%d", self.dx, self.dy, self.dw, self.dh))

    -- take defaults
    f.w = (self.w == 0) and origf.w or self.w
    f.h = (self.h == 0) and origf.h or self.h
    f.x = (self.x == -1) and origf.x or self.x
    f.y = (self.y == -1) and origf.y or self.y

    -- adjust width and height
    if self.dw ~= 0 then
      f.w = math.min(self.grid.width, math.max(1, f.w + self.dw))
    end
    if self.dh ~= 0 then
      f.h = math.min(self.grid.height, math.max(1, f.h + self.dh))
    end

    -- and positions
    if self._topmost then
       f.y = 0
    end
    if self._leftmost then
       f.x = 0
    end
    if self._rightmost then
       f.x = self.grid.width - f.w
    end
    if self._bottommost then
       f.y = self.grid.height - f.h
    end

    if self.dx ~= 0 then
      f.x = math.min(self.grid.width, math.max(0, f.x + self.dx))
    end
    if self.dy ~= 0 then
      f.y = math.min(self.grid.height, math.max(1, f.y + self.dy))
    end

    -- print(string.format("final f x=%d, y=%d, w=%d, h=%d", f.x, f.y, f.w, f.h))
    -- print(string.format("application is '%q'", win:title()))
    self.grid:set(win, f, win:screen())
  end
end

GrilleAction.resize = GrilleAction.act
GrilleAction.move = GrilleAction.act
GrilleAction.place = GrilleAction.act

return grille
