
local buffer = require( "desktox.buffer" )
local button = require( "desktox.gui.element.button" )

local old_term = term.current()
local w, h = old_term.getSize()

local main_buffer = buffer.new( 0, 0, w, h )

local btn = button.new( 2, 2, 10, 3, main_buffer, colours.blue, colours.white, "Hello!" )

btn:draw()

main_buffer( old_term )
