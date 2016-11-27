
local handler = require "desktox.handler"
local buffer  = require "desktox.buffer"

local terminal = term.current()
local w, h = terminal.getSize()

local main_buffer  = buffer .new( 0, 0, w, h )
local main_handler = handler.new( 0, 0, w, h )
main_handler.name  = "main_handler"

function main_handler.callbacks:char( ... )
	terminal.setCursorPos( 1, 1 )
	error( table.concat( { ... } ), 0 )
	if char == 'q' then
		error()
	end
end

function main_handler.callbacks:terminate()
	error()
end

local container_handler = handler.new( 1, 1, 20, 12 )
container_handler.name  = "container_handler"

local container_buffer  = buffer .new( 1, 1, 20, 12, main_buffer )
	:draw_rect( 0, 0, 20, 12, 1, colours.blue )

local button_handler = handler.new( 1, 1, 8, 3 )
button_handler.name  = "button_handler"

local button_buffer  = buffer .new( 1, 1, 8, 3, container_buffer )
	:clear( colours.green )

local label_handler = handler.new( 5, 6, 12, 1 )
label_handler.name  = "label_handler"

local label_buffer  = buffer .new( 5, 6, 12, 1, container_buffer )
	:write( 0, 0, "Hello world!", colours.lightBlue, colours.black )

main_handler:adopt(
	container_handler
		:adopt( button_handler )
		:adopt( label_handler )
)

function button_handler.callbacks:mouse_scroll( direction, x, y )
	button_buffer:clear( 2 ^ math.random( 1, 15 ) )
end

local swap 
function label_handler.callbacks:mouse_click( btn, x, y )
	swap = not swap

	if swap then
		label_buffer:write( 0, 0, "Wello horld!", colours.red, colours.white )
	else
		label_buffer:write( 0, 0, "Hello world!", colours.lightBlue, colours.black )
	end
end

function container_handler.callbacks:on_select( event )
	container_buffer:draw_rect( 0, 0, 20, 12, 1, colours.blue, colours.white, ":" )
end

function container_handler.callbacks:on_deselect( event )
	container_buffer:draw_rect( 0, 0, 20, 12, 1, colours.blue )
end

while true do
	local event = main_handler:handle_and_return( coroutine.yield() )

	main_buffer
		:clear()
		:write( 0, 0, tostring( event ) )

	-- Do the drawing
	label_buffer    :render()
	button_buffer   :render()
	container_buffer:render()

	main_buffer:render_to_window( terminal )
end
