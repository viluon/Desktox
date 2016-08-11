
local buffer = dofile "buffer.lua"

local b1 = buffer.new( 1, 1, 10, 10 )
local b2 = buffer.new( 2, 1, 4, 2, b1, 0 )

b2:resize( 5, 4, colours.blue ):render( nil, nil, nil, 1, 2 )

b1:render_to_window( term.current() )
