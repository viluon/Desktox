
local buffer = require "desktox-buffer"

local w, h = term.getSize()

local terminal = term.current()

local main_buf = buffer.new( 0, 0, w, h )


main_buf
:write( 3, 2, "Woop", "invalid background colour", colours.black )
:repair()
:render_to_window( terminal )
