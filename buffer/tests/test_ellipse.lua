
local buffer = require "desktox.buffer"

local terminal = term.current()
local w, h = terminal.getSize()

local main = buffer.new( 0, 0, w, h )

main:draw_filled_ellipse( 25, 9, 0, 6, colours.green )

main:render_to_window( terminal )
