
local buffer = require "desktox.buffer"

local w, h = term.getSize()
local main = buffer.new( 0, 0, w, h )

main:clear_column( 51, colours.green, colours.black, ".", 1, 60 )

main:render_to_window( term.current() )

read()
