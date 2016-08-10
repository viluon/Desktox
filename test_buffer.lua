
local buffer = dofile "buffer.lua"

local b = buffer.new( 1, 1, 5, 3 )

b:render_to_window( term.current() )
 :resize( 10, 7, colours.green )
 :render_to_window( term.current() )
