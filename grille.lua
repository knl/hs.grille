--- === mjolnir.grille ===
---
--- A module for moving/resizing your windows along a virtual and horizontal grid(s).
---
--- mjolnir.grille is based on mjolnir.sd.grid and mjolnir.bg.grid modules, but allows multiple grids and has
--- an interface that is more tailored to my workflows.
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
---    hotkey.bind(cmdalt, 'LEFT', grid33:pushwindow_left)
---    hotkey.bind(cmdalt, 'RIGHT', grid33:pushwindow_right)
---
---    -- resize windows to grid
---    hotkey.bind(scmdalt, 'LEFT', grid33:resizewindowThinner)
---    hotkey.bind(scmdalt, 'RIGHT', grid33:resizeWindowWider)
---
---    -- use the other grid
---    hotkey.bind(cmdalt, 'h', function()
---        local win = window.focusedwindow()
---        local f = {x = 0, y = 0, w = 1, h = grid42:height}
---        grid22:set(win, f, win:screen())
---      end)
---
---    hotkey.bind(cmdalt, 'j', function()
---        local win = window.focusedwindow()
---        local f = {x = 1, y = 0, w = 1, h = grid42:height}
---        grid22:set(win, f, win:screen())
---      end)
---
---    hotkey.bind(ccmdalt, 'LEFT', grid42:pushWindowLeft)
---    hotkey.bind(ccmdalt, 'RIGHT', grid42:pushWindowRight)
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

--- mjolnir.grille.pushwindow_left()
--- Function
--- Moves the focused window one cell to the left.
function Grille:pushwindow_left()
  self:adjust_focused_window(function(f) f.x = math.max(f.x - 1, 0) end)
end

--- mjolnir.grille.pushwindow_right()
--- Function
--- Moves the focused window one cell to the right.
function Grille:pushwindow_right()
  self:adjust_focused_window(function(f) f.x = math.min(f.x + 1, self.width - f.w) end)
end

--- mjolnir.grille.resizewindow_wider()
--- Function
--- Resizes the focused window's right side to be one cell wider.
function Grille:resizewindow_wider()
  self:adjust_focused_window(function(f) f.w = math.min(f.w + 1, self.width - f.x) end)
end

--- mjolnir.grille.resizewindow_thinner()
--- Function
--- Resizes the focused window's right side to be one cell thinner.
function Grille:resizewindow_thinner()
  self:adjust_focused_window(function(f) f.w = math.max(f.w - 1, 1) end)
end

--- mjolnir.grille.resizewindow_fullwidth()
--- Function
--- Resizes the focused window to be the full width of the screen
function Grille:resizewindow_fullwidth()
  self:adjust_focused_window(function(f) f.w = self.width end)
end

--- mjolnir.grille.pushwindow_down()
--- Function
--- Moves the focused window to the bottom half of the screen.
function Grille:pushwindow_down()
  self:adjust_focused_window(function(f) f.y = math.min(f.y + 1, self.height - f.h) end)
end

--- mjolnir.grille.pushwindow_up()
--- Function
--- Moves the focused window to the top half of the screen.
function Grille:pushwindow_up()
  self:adjust_focused_window(function(f) f.y = math.max(f.y - 1, 0) end)
end

--- mjolnir.grille.resizewindow_shorter()
--- Function
--- Resizes the focused window so its height is 1 grid count less.
function Grille:resizewindow_shorter()
  self:adjust_focused_window(function(f) f.y = f.y - 0; f.h = math.max(f.h - 1, 1) end)
end

--- mjolnir.grille.resizewindow_taller()
--- Function
--- Resizes the focused window so its height is 1 grid count higher.
function Grille:resizewindow_taller()
  self:adjust_focused_window(function(f) f.y = f.y - 0; f.h = math.min(f.h + 1, self.height - f.y) end)
end

--- mjolnir.grille.resizewindow_fullheight()
--- Function
--- Resizes the focused window so its height is the full height of the screen
function Grille:resizewindow_fullheight()
  self:adjust_focused_window(function(f) f.h = self.height end)
end

function Grille:test()
   print ("My w = " .. tostring(self.width) .. " h = " .. tostring(self.height))
end

return grille
