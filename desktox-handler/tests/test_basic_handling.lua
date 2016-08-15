
local handler = require "desktox-handler"
local buffer  = require "desktox-buffer"

local terminal = term.current()
local w, h = terminal.getSize()

local main_buffer   = buffer .new( 0, 0, w, h )
local event_handler = handler.new( 0, 0, w, h )
local rect_handler  = handler.new( 4, 2, 6, 4 )

local colour = colours.green

function rect_handler.callbacks:mouse_click()
	colour = 2 ^ math.random( 0, 15 )
end

event_handler:adopt( rect_handler )

while true do
	event_handler:handle_raw( os.pullEvent() )

	main_buffer
		:clear()
		-- Do the drawing
		:draw_filled_rect( 4, 2, 6, 4, colour )
		:render_to_window( terminal )
end
