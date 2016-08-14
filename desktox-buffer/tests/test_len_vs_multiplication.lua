
local buffer = require "desktox-buffer"

--- Clear the buffer.
-- @param background_colour	(Optional) The background colour to clear with, defaults to DEFAULT_BACKGROUND
-- @param foreground_colour	(Optional) The foreground colour to clear with, defaults to DEFAULT_FOREGROUND
-- @param character			(Optional) The character to clear with, defaults to DEFAULT_CHARACTER
-- @return self
function buffer.methods:clear2( background_colour, foreground_colour, character )
	local n_self = self.width * self.height - 1

	local clear_pixel = {
		tonumber( background_colour ) or DEFAULT_BACKGROUND;
		tonumber( foreground_colour ) or DEFAULT_FOREGROUND;
		character                     or DEFAULT_CHARACTER;
	}

	-- Go through all pixels and set them to the clear pixel
	for i = 0, n_self do
		self[ i ] = clear_pixel
	end

	return self
end

local w, h = term.getSize()

local terminal = term.current()

local main_buf = buffer.new( 0, 0, w, h )

local times = 20000

local start_time = os.clock()
for i = 1, times do
	main_buf:clear()
end
print( "stock clear", os.clock() - start_time )

sleep()

start_time = os.clock()
for i = 1, times do
	main_buf:clear2()
end
print( "clear2", os.clock() - start_time )
