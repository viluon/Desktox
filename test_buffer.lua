
local buffer = dofile "buffer.lua"

local b1 = buffer.new( 1, 1, 10, 10 )
local b2 = buffer.new( 2, 1, 4, 2, b1, -2 )

b2
:resize( 5, 4, colours.blue )
:render( nil, nil, nil )

b1:render_to_window( term.current() )

local w, h = term.getSize()
local main_buffer = buffer.new( 0, 0, w, h )
local window = buffer.new( 3, 3, 10, 10, main_buffer, -2 )

local last_click_x = 0
local last_click_y = 0

while true do
	local ev = { os.pullEvent() }

	if ev[ 1 ] == "mouse_click" then
		last_click_x = ev[ 3 ] - window.x
		last_click_y = ev[ 4 ] - window.y

	elseif ev[ 1 ] == "mouse_drag" then
		window.x = ev[ 3 ] - last_click_x
		window.y = ev[ 4 ] - last_click_y

	elseif ev[ 1 ] == "char" and ev[ 2 ]:lower() == "q" then
		break
	end

	main_buffer:clear()
	window:render()
	main_buffer:render_to_window( term.current() )
end
