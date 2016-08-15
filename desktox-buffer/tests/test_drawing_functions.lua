
local buffer = require "desktox-buffer"

local w, h = term.getSize()

local terminal = term.current()

local main_buf = buffer.new( 0, 0, w, h )
local edit_buf = buffer.new( 0, 0, math.floor( w / 2 ), math.floor( h / 2 ), main_buf )


main_buf
:draw_circle( 22, 9, 1, colours.green )
:draw_circle( 10, 7, 8, colours.blue )
:draw_circle( 40, 12, 6, colours.red )
--[[
:draw_rectangle_using_points( 1, 1, 20, 9, 2, colours.green )
:draw_rectangle_using_points( 30, 5, 36, 11, 1, colours.orange )
:draw_rectangle_using_points( 4, 11, 10, 17, 3, colours.blue )
--]]

main_buf( terminal )

os.pullEvent( "mouse_click" )
