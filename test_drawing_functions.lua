
local buffer = dofile( "buffer.lua" )

local w, h = term.getSize()

local terminal = term.current()

local main_buf = buffer.new( 0, 0, w, h )
local edit_buf = buffer.new( 0, 0, math.floor( w / 2 ), math.floor( h / 2 ), main_buf )

edit_buf:draw_filled_rectangle( 2, 2, 8, 5, colours.green ):map(
	function( self, x, y, pixel )
		return {
			math.random() > 0.5 and pixel[ 1 ] or -1;
			pixel[ 2 ];
			pixel[ 3 ];
		}
	end
)()


main_buf( terminal )

os.pullEvent( "mouse_click" )
