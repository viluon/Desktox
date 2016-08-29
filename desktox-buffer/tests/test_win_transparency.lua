
local buffer = require "desktox-buffer"

local w, h = term.getSize()

local terminal = term.current()

local main_buf  = buffer.new( 0, 0, w, h )           :clear( colours.green, colours.grey, "x" )
local child_buf = buffer.new( 1, 1, 10, 5, main_buf ):clear( -1, -2, "#" )

main_buf:render_to_window( terminal )
