
local buffer = require "desktox-buffer"

local w, h = term.getSize()

local terminal = term.current()

local main_buf = buffer.new( 0, 0, w, h )
local edit_buf = buffer.new( 2, 2, math.floor( w / 2 ), math.floor( h / 2 ), main_buf )
local overlay_buf = buffer.new( 0, 0, 12, 8, main_buf ):clear( -2, colours.blue, "x" )

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
local info_text = ""

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
		last_click_x = ev[ 3 ] - overlay_buf.x1
		last_click_y = ev[ 4 ] - overlay_buf.y1

		local x = last_click_x - 1
		local y = last_click_y - 1
		local pixel = overlay_buf[ y * overlay_buf.width + x ]

		if pixel then
			info_text = x .. ":" .. y .. " = { " .. pixel[ 1 ] .. "; " .. pixel[ 2 ] .. "; '" .. pixel[ 3 ] .. "' }"
		else
			info_text = "unable to fetch pixel data"
		end

	elseif ev[ 1 ] == "mouse_drag" then
		overlay_buf.x1 = ev[ 3 ] - last_click_x
		overlay_buf.y1 = ev[ 4 ] - last_click_y

	elseif ev[ 1 ] == "char" and ev[ 2 ]:lower() == "q" then
		break
	end

	main_buf:clear()

	main_buf:write( 19, 13, "Hello world!", nil, colours.blue )

	edit_buf:render()
	overlay_buf:render()

	main_buf:write( 0, 0, info_text, colours.black, colours.orange )
	main_buf:render_to_window( terminal )
end

buffer.close_log()
