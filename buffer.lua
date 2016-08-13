
-- Desktox, graphics stuff by @viluon
-- In case you'd forget, pixels are stored as { background_colour, text_colour, character }

local buffer = {}

local buffer_methods = {}
local buffer_metatable = {}

-- Constants
local TRANSPARENT_BACKGROUND = -1
local TRANSPARENT_FOREGROUND = -2
local TRANSPARENT_CHARACTER = "\0"

local DEFAULT_BACKGROUND = colours.white
local DEFAULT_FOREGROUND = colours.black
local DEFAULT_CHARACTER = " "

-- Utilities
local type = type
local pairs = pairs
local ipairs = ipairs
local tonumber = tonumber
local string = string
local math = math
local table = table
local colours = colours

local floor = math.floor

local colour_lookup = {
	[ colours.white ]          = "0";
	[ colours.orange ]         = "1";
	[ colours.magenta ]        = "2";
	[ colours.lightBlue ]      = "3";
	[ colours.yellow ]         = "4";
	[ colours.lime ]           = "5";
	[ colours.pink ]           = "6";
	[ colours.grey ]           = "7";
	[ colours.lightGrey ]      = "8";
	[ colours.cyan ]           = "9";
	[ colours.purple ]         = "a";
	[ colours.blue ]           = "b";
	[ colours.brown ]          = "c";
	[ colours.green ]          = "d";
	[ colours.red ]            = "e";
	[ colours.black ]          = "f";
	[ TRANSPARENT_BACKGROUND ] = "g";
	[ TRANSPARENT_FOREGROUND ] = "h";
}

-- Reverse lookup
for k, v in pairs( colour_lookup ) do
	colour_lookup[ v ] = k
end

-- Error messages
local unable_to_set_optional_argument = "Unable to set optional argument "

-- Utility functions

--- Get the maximum value out of a and b.
--	Unlike math.max, only supports 2 arguments,
--	but returns the second-in-value number as
--	the second value.
-- @param a	The first number to compare
-- @param b	The second number to compare
-- @return a and b, whichever is greater in value goes first.
local function max( a, b )
	if a > b then
		return a, b
	end

	return b, a
end

--- Rounds a number to a set amount of decimal places.
-- @param n			The number to round
-- @param places 	The number of decimal places to keep
-- @return The result
local function round( n, places )
	local mult = 10 ^ ( places or 0 )
	return floor( n * mult + 0.5 ) / mult
end

--- Resize the buffer.
-- @param width				(Optional) The desired new width, defaults to self.width
-- @param height			(Optional) The desired new height, defaults to self.height
-- @param background_colour	(Optional) The background colour to set any new pixels to, defaults to DEFAULT_BACKGROUND
-- @param foreground_colour	(Optional) The foreground colour to set any new pixels to, defaults to DEFAULT_FOREGROUND
-- @param character			(Optional) The character to set any new pixels to, defaults to DEFAULT_CHARACTER
-- @return self
function buffer_methods:resize( width, height, background_colour, foreground_colour, character )
	local insert = table.insert
	local remove = table.remove

	local self_width = self.width
	local self_height = self.height
	local n_self = #self

	colour = colour or DEFAULT_BACKGROUND
	width = width or self_width
	height = height or self_height

	local new_pixel = {
		background_colour or DEFAULT_BACKGROUND;
		foreground_colour or DEFAULT_FOREGROUND;
		character         or DEFAULT_CHARACTER;
	}

	-- Loop through all lines
	for y = math.min( self_height, height ) - 1, 0, -1 do
		if width > self_width then
			local line_offset = y * self_width

			-- Insert pixels at the end of the line
			for x = 0, width - self_width - 1 do
				insert( self, line_offset, new_pixel )
				n_self = n_self + 1
			end

		elseif width < self_width then
			local line_offset = y * width

			-- Drop the pixels exceeding new width
			for x = 0, self_width - width - 1 do
				remove( self, line_offset )
				n_self = n_self - 1
			end			
		end
	end

	if height > self_height then
		-- Insert blank lines
		for i = n_self, width * height - 1 do
			self[ i ] = new_pixel
		end

	elseif height < self_height then
		-- Drop extra lines
		for i = width * height - 1, n_self do
			self[ i ] = nil
		end
	end

	self.width = width
	self.height = height

	return self
end

--- Map the buffer with the given function.
-- @param fn				The function to map with, given arguments self, x, y, pixel
-- @return self, old_self	Self and the self state before mapping
function buffer_methods:map( fn )
	local w = self.width
	local clone = self:clone()

	-- Loop through all pixels
	for y = 0, self.height - 1 do
		for x = 0, w - 1 do
			self[ y * w + x ] = fn( self, x, y, clone[ y * w + x ] )
		end
	end

	return self, clone
end

--- Clone the buffer into a new object.
-- @param data		(Optional) The data of the new clone, defaults to self
-- @return buffer	The new buffer, a clone of self
function buffer_methods:clone( data )
	local clone = buffer.new( self.x, self.y, self.width, self.height, self.parent )

	-- Clone the pixel data
	for i, pixel in ipairs( data or self ) do
		clone[ i ] = {
			pixel[ 1 ];
			pixel[ 2 ];
			pixel[ 3 ];
		}
	end

	return clone
end

--- Render the buffer to another buffer.
-- @param target	(Optional) The buffer to render to, defaults to self.parent
-- @param x			(Optional) The x coordinate in target to render self at, 0-based, defaults to self.x
-- @param y			(Optional) The y coordinate in target to render self at, 0-based, defaults to self.y
-- @param start_x	(Optional) The x coordinate in self to start rendering from, 0-based, defaults to 0
-- @param start_y	(Optional) The y coordinate in self to start rendering from, 0-based, defaults to 0
-- @param end_x		(Optional) The x coordinate in self to stop rendering at, 0-based, defaults to self.width - 1
-- @param end_y		(Optional) The y coordinate in self to stop rendering at, 0-based, defaults to self.height - 1
-- @return self
function buffer_methods:render( target, x, y, start_x, start_y, end_x, end_y )
	target = target or self.parent or error( unable_to_set_optional_argument .. "'target': self.parent is nil", 2 )
	x      = x      or self.x      or error( unable_to_set_optional_argument .. "'x': self.x is nil", 2 )
	y      = y      or self.y      or error( unable_to_set_optional_argument .. "'y': self.y is nil", 2 )

	start_x = start_x or 0
	start_y = start_y or 0
	end_x = end_x or self.width - 1
	end_y = end_y or self.height - 1

	local false_parent = { parent = target }

	-- Loop through all coordinates
	for _y = start_y, end_y do
		local target_offset = ( _y + y ) * target.width + x
		local local_offset  = _y * self.width

		for _x = start_x, end_x do
			local index = target_offset + _x

			local pixel1,                         pixel2,                         pixel3
			    = self[ local_offset + _x ][ 1 ], self[ local_offset + _x ][ 2 ], self[ local_offset + _x ][ 3 ]

			-- Set the pixel in target, resolving transparency along the way
			if pixel1 < 0 or pixel2 < 0 or pixel3 == TRANSPARENT_CHARACTER then
				local local_parent = false_parent

				local background_colour = pixel1
				local foreground_colour = pixel2
				local character = pixel3

				local tracked_offset_x = x
				local tracked_offset_y = y

				-- Down into the rabbit hole we go. One parent level further with every iteration
				while background_colour < 0 do
					local_parent = local_parent.parent

					if not local_parent then
						-- We've reached the very bottom of the family stack, without luck
						background_colour = DEFAULT_BACKGROUND
						break
					end

					-- All buffers have a position, we have to keep track of that
					tracked_offset_x = tracked_offset_x + local_parent.x
					tracked_offset_y = tracked_offset_y + local_parent.y

					local actual_y = _y + tracked_offset_y
					local actual_x = _x + tracked_offset_x
					local p_width = local_parent.width
					local p_height = local_parent.height

					-- Check that we are within bounds
					if actual_x < 0 or actual_x > p_width - 1 or actual_y < 0 or actual_y > p_height - 1 then
						-- We can't get a pixel out of bounds of this parent, so we'll just roll with
						-- the default colour.
						--TODO: Would it be better if we'd look for any parent that *is* within bounds instead?
						--      Probably not, the result isn't visible anyway since that part of self is outside
						--		of the parent
						background_colour = DEFAULT_BACKGROUND
						break
					end

					background_colour = local_parent[ actual_y * p_width + actual_x ][ 1 ]
				end

				-- The same goes for foreground colour...
				local_parent = false_parent
				tracked_offset_x = x
				tracked_offset_y = y
				while foreground_colour < 0 do
					local_parent = local_parent.parent

					if not local_parent then
						foreground_colour = DEFAULT_FOREGROUND
						break
					end

					tracked_offset_x = tracked_offset_x + local_parent.x
					tracked_offset_y = tracked_offset_y + local_parent.y

					local actual_y = _y + tracked_offset_y
					local actual_x = _x + tracked_offset_x
					local p_width = local_parent.width
					local p_height = local_parent.height

					if actual_x < 0 or actual_x > p_width - 1 or actual_y < 0 or actual_y > p_height - 1 then
						foreground_colour = DEFAULT_FOREGROUND
						break
					end

					foreground_colour = local_parent[ actual_y * p_width + actual_x ][ 2 ]
				end

				-- ...And finally for the character.
				local_parent = false_parent
				tracked_offset_x = x
				tracked_offset_y = y
				while character == TRANSPARENT_CHARACTER do
					local_parent = local_parent.parent

					if not local_parent then
						character = DEFAULT_CHARACTER
						break
					end

					tracked_offset_x = tracked_offset_x + local_parent.x
					tracked_offset_y = tracked_offset_y + local_parent.y

					local actual_y = _y + tracked_offset_y
					local actual_x = _x + tracked_offset_x
					local p_width = local_parent.width
					local p_height = local_parent.height

					if actual_x < 0 or actual_x > p_width - 1 or actual_y < 0 or actual_y > p_height - 1 then
						character = DEFAULT_CHARACTER
						break
					end

					character = local_parent[ actual_y * p_width + actual_x ][ 3 ]
				end

				-- Now that we're certain we have non-transparent data, store them in a pixel
				-- We *could* use -1 and -2 indices, but there will be a lot of cases where
				-- one or both of them aren't used. Because creating arrays is faster
				-- (array creation can utilise SETLIST while table creation can only use
				-- SETTABLE) and this assignment has to be done for *all cases*, we'll limit
				-- the math to the target[ index ] assignment down below.
				local underneath = {
					background_colour;
					foreground_colour;
					character;
				}

				-- Assign the proper data to the rendered pixel
				target[ index ] = {
					pixel1 > 0 and pixel1 or underneath[ -pixel1 ];
					pixel2 > 0 and pixel2 or underneath[ -pixel2 ];
					pixel3 == TRANSPARENT_CHARACTER and underneath[ 3 ] or pixel3;
				}
			else
				-- That was quick! This is a speed up for the large number of cases
				-- in which no transparency is used
				target[ index ] = {
					pixel1;
					pixel2;
					pixel3;
				}
			end
		end
	end

	return self
end

--- Render the buffer to a CraftOS window object.
-- @param target	The window to render to
-- @param x			(Optional) The x coordinate in target to render self at, 1-based, defaults to self.x + 1
-- @param y			(Optional) The y coordinate in target to render self at, 1-based, defaults to self.y + 1
-- @return self
function buffer_methods:render_to_window( target, x, y )
	x = x or self.x + 1
	y = y or self.y + 1

	local scp, blit = target.setCursorPos, target.blit

	-- Go through all lines of the buffer
	for i, line in ipairs( self:cook_lines() ) do
		scp( x, y + i - 1 )
		blit( line[ 3 ], line[ 2 ], line[ 1 ] )
	end

	return self
end

--- Cook the buffer data into an array of blitable lines.
-- @param start_x	(Optional) The x coordinate to start reading data at, 0-based, defaults to 0
-- @param start_y	(Optional) The y coordinate to start reading data at, 0-based, defaults to 0
-- @param end_x		(Optional) The x coordinate to end reading data at, 0-based, defaults to self.width - 1
-- @param end_y		(Optional) The y coordinate to end reading data at, 0-based, defaults to self.height - 1
-- @return lines An array of lines, where every line = { background_colours, foreground_colours, text }
function buffer_methods:cook_lines( start_x, start_y, end_x, end_y )
	local lines = {}
	local i = 1

	local w, h = self.width, self.height

	start_x = start_x or 0
	start_y = start_y or 0
	end_x = end_x or w - 1
	end_y = end_y or h - 1

	-- Go through all lines
	for y = start_y, end_y do
		local line = { "", "", "" }
		local line_offset = y * w

		-- Add the pixel data to the end of the line
		for x = start_x, end_x do
			local pixel = self[ line_offset + x ]

			if not pixel then
				error( x .. ":" .. y )
			end

			line[ 1 ] = line[ 1 ] .. colour_lookup[ pixel[ 1 ] ]
			line[ 2 ] = line[ 2 ] .. colour_lookup[ pixel[ 2 ] ]
			line[ 3 ] = line[ 3 ] .. pixel[ 3 ]
		end

		lines[ i ] = line
		i = i + 1
	end

	return lines
end

--- Get a CraftOS window-like interface for interaction with the buffer.
--	The window is a valid term object, which means that the CraftOS term
--	can be term.redirect()ed to it. Functions without a return value,
--	unlike those in the native API, return the window object, enabling
--	method chaining.
-- @param parent	The parent terminal, such as term.current() or a window
-- @param x			(Optional) The x coordinate of the window object in parent, 1-based, defaults to 1
-- @param y			(Optional) The y coordinate of the window object in parent, 1-based, defaults to 1
-- @param width		(Optional) The width of the window object, defaults to self.width. If different from self.width, buffer will be resized
-- @param height	(Optional) The height of the window object, defaults to self.height. If different from self.height, buffer will be resized
-- @param visible	(Optional) Whether the window is visible (i.e. changes are propagated to parent in real time), defaults to false
-- @param is_colour	(Optional) Whether the window supports colour (will only display monochromatic colours otherwise),
--					defaults to parent.isColour()
-- @return window	CraftOS-like window object
function buffer_methods:get_window_interface( parent, x, y, width, height, visible, is_colour )
	--TODO: Make parent optional (win.redirect?) or at least let it be a buffer
	local win = {}

	x = x or 1
	y = y or 1
	width = width or self.width
	height = height or self.height
	-- Visibility defaults to false
	visible = visible ~= nil and true or false
	-- Colour defaults to parent.isColour()
	if is_colour == nil then
		is_colour = parent.isColour()
	end

	-- Retrieve information from parent
	local cursor_blink = parent.getCursorBlink and parent.getCursorBlink() or false
	local cursor_x, cursor_y = parent.getCursorPos()
	cursor_x = cursor_x + x - 1
	cursor_y = cursor_y + y - 1

	local background_colour = parent.getBackgroundColour()
	local text_colour = parent.getTextColour()

	function win.write( text )
		local x = cursor_x

		local line_offset = ( cursor_y - 1 ) * width - 1
		local sub = string.sub

		for i = 1, #text do
			if x > width then
				break
			end

			-- A -1 for x is included in line_offset
			self[ line_offset + x ] = { background_colour, text_colour, sub( text, i, i ) }
			x = x + 1
		end

		cursor_x = x
	end

	function win.blit( text, text_colours, background_colours )
		self:blit( cursor_x - 1, cursor_y - 1, text, text_colours, background_colours )
		return win
	end

	function win.clear()
		self:clear( background_colour )
		return win
	end

	function win.clearLine()
		self:clear_line( cursor_y - 1 )
		return win
	end

	function win.getCursorPos()
		return cursor_x, cursor_y
	end

	function win.setCursorPos( new_x, new_y )
		new_x = tonumber( new_x ) or error( "Expected number for 'new_x'", 2 )
		new_y = tonumber( new_y ) or error( "Expected number for 'new_y'", 2 )

		cursor_x, cursor_y = new_x, new_y
	end

	function win.setCursorBlink( bool )
		cursor_blink = bool

		return win
	end

	function win.isColor()
		return is_colour
	end

	function win.getSize()
		return width, height
	end

	function win.scroll( n )
		self:scroll( n, background_colour )
		return win
	end

	function win.setTextColor( colour )
		text_colour = colour
		return win
	end

	function win.getTextColor()
		return text_colour
	end

	function win.setBackgroundColor( colour )
		background_colour = colour
		return win
	end

	function win.getBackgroundColor()
		return background_colour
	end

	function win.setTextScale( scale )
		-- Scale is ignored for now
		return win
	end

	function win.setVisible( visibility )
		if visible ~= visibility then
			visible = visibility
			if visible then
				win.redraw()
			end
		end

		return win
	end

	function win.redraw()
		if visible then
			self:render_to_window( parent, x - 1, y - 1 )
		end

		return win
	end

	function win.restoreCursor()
		parent.setCursorBlink( cursor_blink )
		parent.setTextColor( text_colour )

		if cursor_x >= 1 and cursor_y >= 1 and cursor_x <= width and cursor_y <= height then
			parent.setCursorPos( cursor_x + x - 1, cursor_y + y - 1 )
		else
			parent.setCursorPos( 0, 0 )
		end

		return win
	end

	function win.getPosition()
		return x, y
	end

	function win.reposition( new_x, new_y, new_w, new_h )
		new_x = tonumber( new_x ) or error( "Expected number for 'new_x'", 2 )
		new_y = tonumber( new_y ) or error( "Expected number for 'new_y'", 2 )

		x = new_x
		y = new_y

		if tonumber( new_w ) and tonumber( new_h ) then
			self:resize( new_w, new_h, background_colour )

			width = new_w
			height = new_h
		end

		if visible then
			win.redraw()
		end

		return win
	end

	-- Proper language!
	win.isColour            = win.isColor
	win.setTextColour       = win.setTextColor
	win.getTextColour       = win.getTextColor
	win.setBackgroundColour = win.setBackgroundColor
	win.getBackgroundColour = win.getBackgroundColor

	return win
end

--- Scroll the buffer contents.
-- @param lines		The number of lines to scroll
-- @param colour	(Optional) The colour to fill any empty pixels with, defaults to DEFAULT_BACKGROUND
-- @return self
function buffer_methods:scroll( lines, colour )
	lines = tonumber( lines ) or error( "Expected number for 'lines'", 2 )
	colour = tonumber( colour ) or DEFAULT_BACKGROUND

	local n_self = #self
	local width, height = self.width, self.height
	local new_pixel = { colour, DEFAULT_FOREGROUND, DEFAULT_CHARACTER }

	if lines > 0 then
		local remove = table.remove

		-- Drop the pixels that will go off screen (scrolling upwards)
		-- Because 0 doesn't belong into a proper Lua array, we'll set
		-- the last pixel as the 0th index
		local last_removed
		for i = 0, lines * width - 1 do
			last_removed = remove( self, 1 )
			n_self = n_self - 1
		end

		self[ 0 ] = last_removed

		-- Fill the extra pixels
		for i = n_self, width * height - 1 do
			self[ i ] = new_pixel
		end

	elseif lines < 0 then
		local insert = table.insert

		-- Drop the pixels that will go off screen (scrolling downwards)
		-- Note that lines is negative
		for i = n_self + lines * width, n_self - 1 do
			self[ i ] = nil
			n_self = n_self - 1
		end

		-- Insert new pixels at the top of the buffer
		-- Again, 0 isn't a proper array element, so we'll
		-- set it separately
		for i = 1, -lines * width do
			insert( self, i, new_pixel )
		end

		-- 0 is now one line lower
		self[ width ] = self[ 0 ]
		self[ 0 ] = new_pixel
	end

	return self
end

--- Clear the buffer.
-- @param background_colour	(Optional) The background colour to clear with, defaults to DEFAULT_BACKGROUND
-- @param foreground_colour	(Optional) The foreground colour to clear with, defaults to DEFAULT_FOREGROUND
-- @param character			(Optional) The character to clear with, defaults to DEFAULT_CHARACTER
-- @return self
function buffer_methods:clear( background_colour, foreground_colour, character )
	local n_self = #self

	local clear_pixel = {
		background_colour or DEFAULT_BACKGROUND;
		foreground_colour or DEFAULT_FOREGROUND;
		character         or DEFAULT_CHARACTER;
	}

	-- Go through all pixels and set them to the clear pixel
	for i = 0, n_self do
		self[ i ] = clear_pixel
	end

	return self
end

--- Clear a line of the buffer.
-- @param y					The y coordinate indicating the line to clear, 0-based
-- @param background_colour	(Optional) The background colour to clear with, defaults to DEFAULT_BACKGROUND
-- @param foreground_colour	(Optional) The foreground colour to clear with, defaults to DEFAULT_FOREGROUND
-- @param character			(Optional) The character to clear with, defaults to DEFAULT_CHARACTER
-- @param start_x			(Optional) The x coordinate to start clearing on, 0-based, defaults to 0
-- @param end_x				(Optional) The x coordinate to stop clearing on, 0-based, defaults to self.width - 1
-- @return self
function buffer_methods:clear_line( y, background_colour, foreground_colour, character, start_x, end_x )
	y = tonumber( y ) or error( "Expected number for 'y'", 2 )

	if y < 0 or y > self.height then
		return self
	end

	local clear_pixel = {
		background_colour or DEFAULT_BACKGROUND;
		foreground_colour or DEFAULT_FOREGROUND;
		character         or DEFAULT_CHARACTER;
	}

	local w = self.width

	start_x = tonumber( start_x ) or 0
	end_x = tonumber( end_x ) or w - 1

	-- Go through all pixels on this line and set them to clear_pixel
	for x = start_x, end_x do
		self[ y * w + x ] = clear_pixel
	end

	return self
end

--- Clear a column of the buffer.
-- @param x					The x coordinate indicating the column to clear, 0-based
-- @param background_colour	(Optional) The background colour to clear with, defaults to DEFAULT_BACKGROUND
-- @param foreground_colour	(Optional) The foreground colour to clear with, defaults to DEFAULT_FOREGROUND
-- @param character			(Optional) The character to clear with, defaults to DEFAULT_CHARACTER
-- @param start_y			(Optional) The y coordinate to start clearing on, 0-based, defaults to 0
-- @param end_y				(Optional) The y coordinate to stop clearing on, 0-based, defaults to self.height - 1
-- @return self
function buffer_methods:clear_column( x, background_colour, foreground_colour, character, start_y, end_y )
	x = tonumber( x ) or error( "Expected number for 'x'", 2 )

	local w = self.width

	if x < 0 or x > w then
		return self
	end

	local clear_pixel = {
		background_colour or DEFAULT_BACKGROUND;
		foreground_colour or DEFAULT_FOREGROUND;
		character         or DEFAULT_CHARACTER;
	}

	start_y = tonumber( start_y ) or 0
	end_y = tonumber( end_y ) or self.height - 1

	-- Go through all pixels in this column and set them to clear_pixel
	for y = start_y, end_y do
		self[ y * w + x ] = clear_pixel
	end

	return self
end

--- Write text to the buffer using the specified colours.
--	text, background_colours and foreground_colours have to
--	be of the same length
-- @param x						The x coordinate to write at, 0-based
-- @param y						The y coordinate to write at, 0-based
-- @param text					The text to write
-- @param background_colours	The background colours to use, in paint format (characters)
-- @param foreground_colours	The foreground colours to use, in paint format (characters)
-- @return self
function buffer_methods:blit( x, y, text, background_colours, foreground_colours )
	--TODO: Checks that all arguments are of the correct format

	local offset = y * self.width + x
	local sub = string.sub

	for i = 1, #text do
		self[ offset + i - 1 ] = {
			colour_lookup[ sub( background_colours, i, i ) ];
			colour_lookup[ sub( foreground_colours, i, i ) ];
			sub( text, i, i );
		}
	end

	return self
end

--- Draw a filled, solid colour rectangle using two points.
--	The order of the two points does not matter, i.e. 2:2, 1:1 is the same
--	as 1:1, 2:2
-- @param start_x			The x coordinate to start drawing at, 0-based
-- @param start_y			The y coordinate to start drawing at, 0-based
-- @param end_x				The x coordinate to end drawing at, 0-based
-- @param end_y				The y coordinate to end drawing at, 0-based
-- @param background_colour	(Optional) The background colour to fill the rectangle (including borders) with, defaults to DEFAULT_BACKGROUND
-- @param foreground_colour	(Optional) The foreground colour to fill the rectangle (including borders) with, defaults to DEFAULT_FOREGROUND
-- @param character			(Optional) The character to fill the rectangle (including borders) with, defaults to DEFAULT_CHARACTER
-- @return self
function buffer_methods:draw_filled_rectangle_using_points( start_x, start_y, end_x, end_y, background_colour, foreground_colour, character )
	local w = self.width

	-- Starting values must be smaller than ending ones
	end_x, start_x = max( start_x, end_x )
	end_y, start_y = max( start_y, end_y )

	local new_pixel = {
		background_colour or DEFAULT_BACKGROUND;
		foreground_colour or DEFAULT_FOREGROUND;
		character         or DEFAULT_CHARACTER;
	}

	-- Go through all pixels of this rectangle and set them to new_pixel
	for y = start_y, end_y do
		for x = start_x, end_x do
			self[ y * w + x ] = new_pixel
		end
	end

	return self
end

--- Draw a filled, solid colour rectangle using one point, width and height.
-- @param x					The x coordinate to start drawing at, 0-based
-- @param y					The y coordinate to start drawing at, 0-based
-- @param width				The width of the rectangle
-- @param height			The height of the rectangle
-- @param background_colour	(Optional) The background colour to fill the rectangle (including borders) with, defaults to DEFAULT_BACKGROUND
-- @param foreground_colour	(Optional) The foreground colour to fill the rectangle (including borders) with, defaults to DEFAULT_FOREGROUND
-- @param character			(Optional) The character to fill the rectangle (including borders) with, defaults to DEFAULT_CHARACTER
-- @return self
function buffer_methods:draw_filled_rectangle( x, y, width, height, background_colour, foreground_colour, character )
	local w = self.width
	local end_x = x + width - 1

	local new_pixel = {
		background_colour or DEFAULT_BACKGROUND;
		foreground_colour or DEFAULT_FOREGROUND;
		character         or DEFAULT_CHARACTER;
	}

	-- Go through all pixels of this rectangle and set them to new_pixel
	for y = y, y + height - 1 do
		for x = x, end_x do
			self[ y * w + x ] = new_pixel
		end
	end

	return self
end

--- Draw a solid colour rectangle border using two points.
-- @param start_x			The x coordinate to start drawing at, 0-based
-- @param start_y			The y coordinate to start drawing at, 0-based
-- @param end_x				The x coordinate to end drawing at, 0-based
-- @param end_y				The y coordinate to end drawing at, 0-based
-- @param border_width		(Optional) The width of the border (larger values extending to the centre)
-- @param background_colour	(Optional) The background colour to fill the rectangle border with, defaults to DEFAULT_BACKGROUND
-- @param foreground_colour	(Optional) The foreground colour to fill the rectangle border with, defaults to DEFAULT_FOREGROUND
-- @param character			(Optional) The character to fill the rectangle border with, defaults to DEFAULT_CHARACTER
-- @return self
function buffer_methods:draw_rectangle_using_points( start_x, start_y, end_x, end_y, border_width,
                                                     background_colour, foreground_colour, character )
	local w = self.width
	border_width = border_width or 1

	-- Starting values must be smaller than ending ones
	end_x, start_x = max( start_x, end_x )
	end_y, start_y = max( start_y, end_y )

	-- Go through all lines and columns of this rectangle and clear them with the desired data
	-- (clear_line and clear_column will handle defaults for us)
	for i = 0, border_width - 1 do
		self:clear_line( start_y + i, background_colour, foreground_colour, character, start_x + i, end_x - i )
	end

	for i = 0, border_width - 1 do
		self:clear_line( end_y - i, background_colour, foreground_colour, character, start_x + i, end_x - i )
	end

	-- Columns have a little less work, so that corners aren't painted twice
	for i = 0, border_width - 1 do
		self:clear_column( start_x + i, background_colour, foreground_colour, character, start_y + i + 1, end_y - i - 1 )
	end

	for i = 0, border_width - 1 do
		self:clear_column( end_x - i, background_colour, foreground_colour, character, start_y + i + 1, end_y - i - 1 )
	end

	return self
end

--- Draw a solid colour rectangle border using one point, width and height.
-- @param x					The x coordinate to start drawing at, 0-based
-- @param y					The y coordinate to start drawing at, 0-based
-- @param width				The width of the rectangle
-- @param height			The height of the rectangle
-- @param border_width		(Optional) The width of the border (larger values extending to the centre)
-- @param background_colour	(Optional) The background colour to fill the rectangle border with, defaults to DEFAULT_BACKGROUND
-- @param foreground_colour	(Optional) The foreground colour to fill the rectangle border with, defaults to DEFAULT_FOREGROUND
-- @param character			(Optional) The character to fill the rectangle border with, defaults to DEFAULT_CHARACTER
-- @return Tail call of self:draw_rectangle_using_points(), resulting in self
function buffer_methods:draw_rectangle( x, y, width, height, border_width, background_colour, foreground_colour, character )
	return self
	:draw_rectangle_using_points( x, y, x + width - 1, y + height - 1, border_width, background_colour, foreground_colour, character )
end

--- Draw a circle outline using the centre point and radius, without corrections for CC rectangular pixels.
-- @param centre_x			The x coordinate of the circle's centre
-- @param centre_y			The y coordinate of the circle's centre
-- @param radius			The radius of the circle
-- @param background_colour	(Optional) The background colour to fill the circle outline with, defaults to DEFAULT_BACKGROUND
-- @param foreground_colour	(Optional) The foreground colour to fill the circle outline with, defaults to DEFAULT_FOREGROUND
-- @param character			(Optional) The character to fill the circle outline with, defaults to DEFAULT_CHARACTER
-- @return self
function buffer_methods:draw_circle_raw( centre_x, centre_y, radius, background_colour, foreground_colour, character )
	local w = self.width

	local new_pixel = {
		background_colour or DEFAULT_BACKGROUND;
		foreground_colour or DEFAULT_FOREGROUND;
		character         or DEFAULT_CHARACTER;
	}

	local x = radius
	local y = 0
	local err = 0

	-- Generate points for the first octant, going counterclockwise
	-- and mirroring them to other octants
	while x >= y do
		self[ ( centre_y + y ) * w + centre_x + x ] = new_pixel
		self[ ( centre_y + x ) * w + centre_x + y ] = new_pixel
		self[ ( centre_y + x ) * w + centre_x - y ] = new_pixel
		self[ ( centre_y + y ) * w + centre_x - x ] = new_pixel
		self[ ( centre_y - y ) * w + centre_x - x ] = new_pixel
		self[ ( centre_y - x ) * w + centre_x - y ] = new_pixel
		self[ ( centre_y - x ) * w + centre_x + y ] = new_pixel
		self[ ( centre_y - y ) * w + centre_x + x ] = new_pixel

		y = y + 1
		err = err + 1 + 2 * y

		if 2 * ( err - x ) + 1 > 0 then
			x = x - 1
			err = err + 1 - 2 * x
		end
	end

	return self
end

--- Draw a circle outline using the centre point and radius, with corrections for CC rectangular pixels.
-- @param centre_x			The x coordinate of the circle's centre
-- @param centre_y			The y coordinate of the circle's centre
-- @param radius			The radius of the circle
-- @param background_colour	(Optional) The background colour to fill the circle outline with, defaults to DEFAULT_BACKGROUND
-- @param foreground_colour	(Optional) The foreground colour to fill the circle outline with, defaults to DEFAULT_FOREGROUND
-- @param character			(Optional) The character to fill the circle outline with, defaults to DEFAULT_CHARACTER
-- @return self
function buffer_methods:draw_circle( centre_x, centre_y, radius, background_colour, foreground_colour, character )
	--TODO: Add corrections!
	local w = self.width

	local new_pixel = {
		background_colour or DEFAULT_BACKGROUND;
		foreground_colour or DEFAULT_FOREGROUND;
		character         or DEFAULT_CHARACTER;
	}

	local x = radius
	local y = 0
	local err = 0

	-- Generate points for the first octant, going counterclockwise
	-- and mirroring them to other octants
	while x >= y do
		self[ ( centre_y + y ) * w + centre_x + x ] = new_pixel
		self[ ( centre_y + x ) * w + centre_x + y ] = new_pixel
		self[ ( centre_y + x ) * w + centre_x - y ] = new_pixel
		self[ ( centre_y + y ) * w + centre_x - x ] = new_pixel
		self[ ( centre_y - y ) * w + centre_x - x ] = new_pixel
		self[ ( centre_y - x ) * w + centre_x - y ] = new_pixel
		self[ ( centre_y - x ) * w + centre_x + y ] = new_pixel
		self[ ( centre_y - y ) * w + centre_x + x ] = new_pixel

		y = y + 1
		err = err + 1 + 2 * y

		if 2 * ( err - x ) + 1 > 0 then
			x = x - 1
			err = err + 1 - 2 * x
		end
	end

	return self
end

--- Create a new buffer.
-- @param x					(Optional) The x coordinate of the buffer in parent, 0-based, defaults to 0
-- @param y					(Optional) The y coordinate of the buffer in parent, 0-based, defaults to 0
-- @param width				(Optional) The width of the buffer, defaults to 0
-- @param height			(Optional) The height of the buffer, defaults to 0
-- @param parent			This buffer's render target
-- @param background_colour	(Optional) The background colour to prefill the buffer with, defaults to DEFAULT_BACKGROUND
-- @param foreground_colour	(Optional) The foreground colour to prefill the buffer with, defaults to DEFAULT_FOREGROUND
-- @param character			(Optional) The character to prefill the buffer with, defaults to DEFAULT_CHARACTER
-- @param no_prefill		(Optional) Disable prefilling of the buffer, defaults to false
-- @return buffer			The new buffer
function buffer.new( x, y, width, height, parent, background_colour, foreground_colour, character, no_prefill )
	local n = setmetatable( {}, buffer_metatable )

	width = width or 0
	height = height or 0

	local new_pixel = {
		background_colour or DEFAULT_BACKGROUND;
		foreground_colour or DEFAULT_FOREGROUND;
		character         or DEFAULT_CHARACTER;
	}

	if not no_prefill then
		-- Prefill the buffer with new_pixel
		for y = 0, height - 1 do
			for x = 0, width - 1 do
				n[ y * width + x ] = new_pixel
			end
		end
	end

	-- Copy the buffer methods to this instance
	for k, fn in pairs( buffer_methods ) do
		n[ k ] = fn
	end

	n.x = x or 0
	n.y = y or 0
	n.width = width
	n.height = height
	n.parent = parent

	-- Metadata
	n.__type = "buffer"

	return n
end

buffer.clone = buffer_methods.clone

--- Syntactic sugar for both :render() and :render_to_window().
--	Will attempt to decide which of the 2 methods to use, based
--	on self.parent and given arguments. Defaults to
--	:render_to_window(). Should be *avoided* for best performance.
-- @param target	The buffer or window to render to
-- @param ...		Any arguments passed to :render() or :render_to_window()
-- @return Tail call of :render() or :render_to_window()
function buffer_metatable:__call( target, ... )
	if self.parent or ( type( target ) == "table" and target.__type == "buffer" ) then
		return self:render( target, ... )
	else
		return self:render_to_window( target, ... )
	end
end

return buffer
