
local buffer = require "desktox.buffer"

local terminal = term.current()
local w, h = terminal.getSize()

local main = buffer.new( 0, 0, w, h )

local x, y   = w / 2, h / 2
local limit  = 10000
local colour = colours.green

local start = os.clock()
for i = 1, limit do
	main:draw_filled_ellipse( x, y, w, h, colour )
end

local time = os.clock() - start
print( "Finished drawing " .. limit .. " ellipses in " .. time .. " seconds" )
print( "Average " .. limit / time .. " ellipses per second" )


--main:render_to_window( terminal )
