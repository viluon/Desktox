
local buffer = dofile( "buffer.lua" )

local w, h = term.getSize()

local terminal = term.current()

local main_buf = buffer.new( 0, 0, w, h )
local edit_buf = buffer.new( 0, 0, math.floor( w / 2 ), math.floor( h / 2 ), main_buf )
local overlay_buf = buffer.new( 0, 0, 12, 8, main_buf ):clear( -1, colours.green, "\0" )

local main_win = main_buf:get_window_interface( terminal )
local edit_win = edit_buf:get_window_interface( terminal )
edit_win.setBackgroundColour( colours.black )
edit_win.clear()

local file = io.open( "/rom/programs/fun/adventure", "r" )
local contents = file:read( "*a" )
file:close()

local adventure = coroutine.create( loadstring( contents, "adventure" ) )

local coros = {
	adventure;
}

local last_click_x = 0
local last_click_y = 0

while true do
	local ev = { os.pullEvent() }

	for i, coro in ipairs( coros ) do
		term.redirect( edit_win )
		local ok, err = coroutine.resume( coro, unpack( ev ) )
		if not ok then
			term.redirect( terminal )
			error( err, 0 )
		end
	end

	if ev[ 1 ] == "mouse_scroll" then
		edit_buf:scroll( ev[ 2 ], edit_win.getBackgroundColour() )

	elseif ev[ 1 ] == "mouse_click" then
		last_click_x = ev[ 3 ] - overlay_buf.x
		last_click_y = ev[ 4 ] - overlay_buf.y

	elseif ev[ 1 ] == "mouse_drag" then
		overlay_buf.x = ev[ 3 ] - last_click_x
		overlay_buf.y = ev[ 4 ] - last_click_y

	elseif ev[ 1 ] == "char" and ev[ 2 ]:lower() == "q" then
		break
	end

	main_buf:clear()

	main_win.setCursorPos( 20, 14 )
	main_win.write( "Hello world!" )

	edit_buf:render()
	overlay_buf:render()
	main_buf:render_to_window( terminal )
end
