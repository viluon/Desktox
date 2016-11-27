
-- Desktox
--  A set of graphics libraries for ComputerCraft by @viluon <viluon@espiv.net>

--   desktox-buffer
--    The Desktox buffer library

--    This Source Code Form is subject to the terms of the Mozilla Public
--    License, v. 2.0. If a copy of the MPL was not distributed with this
--    file, You can obtain one at http://mozilla.org/MPL/2.0/.

-- In case you'd forget, pixels are stored as { background_colour, foreground_colour, character }

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
local setmetatable = setmetatable
local type = type
local pairs = pairs
local ipairs = ipairs
local tonumber = tonumber
local error = error

local string = string
local math = math
local table = table
local colours = colours

local floor = math.floor
local max = math.max
local min = math.min
local abs = math.abs

local sub = string.sub

local _colour_lookup = {
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

	-- Transparency
	[ TRANSPARENT_BACKGROUND ] = "g";
	[ TRANSPARENT_FOREGROUND ] = "h";
}

-- Weird LuaJ bug workaround here
local colour_lookup = {}
-- Reverse lookup
for k, v in pairs( _colour_lookup ) do
	colour_lookup[ k ] = v
	colour_lookup[ v ] = k
end

-- Error messages
local unable_to_set_optional_argument = "Unable to set optional argument "

-- Utility functions

local max   = require( "desktox-utils" ).max
local round = require( "desktox-utils" ).round

--local log, close_log = require( "desktox-utils" ).open_log_file( "/log.txt" )

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
	local n_self = self.length

	colour = colour or DEFAULT_BACKGROUND
	width = width or self_width
	height = height or self_height

	local new_pixel = {
		tonumber( background_colour ) or DEFAULT_BACKGROUND;
		tonumber( foreground_colour ) or DEFAULT_FOREGROUND;
		character                     or DEFAULT_CHARACTER;
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
	self.length = width * height - 1

	return self
end

--- Map the buffer with the given function.
-- @param fn				The function to map with, given arguments self, x, y, pixel
-- @return self, old_self	Self and the self state before mapping
function buffer_methods:map( fn )
	if type( fn ) ~= "function" then
		error( "Expected function as 'fn'", 2 )
	end

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
	local clone = buffer.new_from_points( self.x1, self.y1, self.x2, self.y2, self.parent )

	-- Clone the pixel data
	if data and type( data ) == "table" then
		for i, pixel in ipairs( data ) do
			clone[ i ] = {
				pixel[ 1 ];
				pixel[ 2 ];
				pixel[ 3 ];
			}
		end
	else
		for pixel, x, y, index in self:iter() do
			clone[ index ] = {
				pixel[ 1 ];
				pixel[ 2 ];
				pixel[ 3 ];
			}
		end
	end

	return clone
end

--- Render the buffer to another buffer.
-- @param target	(Optional) The buffer to render to, defaults to self.parent
-- @param x			(Optional) The x coordinate in target to render self at, 0-based, defaults to self.x1
-- @param y			(Optional) The y coordinate in target to render self at, 0-based, defaults to self.y1
-- @param start_x	(Optional) The x coordinate in self to start rendering from, 0-based, defaults to 0
-- @param start_y	(Optional) The y coordinate in self to start rendering from, 0-based, defaults to 0
-- @param end_x		(Optional) The x coordinate in self to stop rendering at, 0-based, defaults to self.width - 1
-- @param end_y		(Optional) The y coordinate in self to stop rendering at, 0-based, defaults to self.height - 1
-- @return self
function buffer_methods:render( target, x, y, start_x, start_y, end_x, end_y )
	target = target or self.parent or error( unable_to_set_optional_argument .. "'target': self.parent is nil", 2 )
	x      = x      or self.x1     or error( unable_to_set_optional_argument .. "'x': self.x1 is nil", 2 )
	y      = y      or self.y1     or error( unable_to_set_optional_argument .. "'y': self.y1 is nil", 2 )

	local self_width = self.width
	local target_width = target.width

	start_x = start_x or 0
	start_y = start_y or 0
	end_x = end_x or self_width - 1
	end_y = end_y or self.height - 1

	-- Respect borders of the parent
	start_x = max( start_x, -x )
	start_y = max( start_y, -y )
	end_x   = min( end_x, target_width  - x - 1 )
	end_y   = min( end_y, target.height - y - 1 )

	-- Will be explained further down
	local false_parent = { parent = target }

	-- Loop through all coordinates
	for _y = start_y, end_y do
		-- Cache the line position for both the target buffer and us
		local target_offset = ( _y + y ) * target_width + x
		local local_offset  = _y * self_width

		for _x = start_x, end_x do
			-- index is where we should store the resultant pixel in target
			local index = target_offset + _x
			-- pixel is the data from our buffer
			local pixel = self[ local_offset + _x ]

			-- Cache the contents for faster access
			local pixel1, pixel2, pixel3 = pixel[ 1 ], pixel[ 2 ], pixel[ 3 ]

			-- Set the pixel in target, resolving transparency along the way
			if pixel1 < 0 or pixel2 < 0 or pixel3 == TRANSPARENT_CHARACTER then
				local local_parent = false_parent

				local background_colour = pixel1
				local foreground_colour = pixel2
				local character = pixel3

				local tracked_offset_x = x
				local tracked_offset_y = y

				-- Not only we have to get to the non-transparent colour
				-- when the background_colour is transparent, we also have
				-- to resolve the colour if the *foreground* uses it

				if background_colour < 0 or pixel2 == TRANSPARENT_BACKGROUND then
					local tracked_colour = -1

					-- Down into the rabbit hole we go. One parent level further with every iteration.
					-- We have to let the loop run at least once, for the TRANSPARENT_BACKGROUND to resolve
					repeat
						-- This wouldn't work the first time (when the loop starts), that's
						-- why we defined local_parent to be the false_parent
						local_parent = local_parent.parent

						if not local_parent then
							-- We've reached the very bottom of the family stack, without luck
							background_colour = DEFAULT_BACKGROUND
							break
						end

						-- All buffers have a position, we have to keep track of that
						tracked_offset_x = tracked_offset_x + local_parent.x1
						tracked_offset_y = tracked_offset_y + local_parent.y1

						local actual_y = _y + tracked_offset_y
						local actual_x = _x + tracked_offset_x
						local p_width  = local_parent.width
						local p_height = local_parent.height

						-- Check that we are within bounds
						-- We could subtract a 1 in the local definition above, but if actual_x < 0 then the operation
						-- doesn't even happen :P
						if actual_x < 0 or actual_x > p_width - 1 or actual_y < 0 or actual_y > p_height - 1 then
							-- We can't get a pixel out of bounds of this parent, so we'll just roll with
							-- the default colour.
							--TODO: Would it be better if we'd look for any parent that *is* within bounds instead?
							--      Probably not, the result isn't visible anyway since that part of self is outside
							--      of the parent
							background_colour = DEFAULT_BACKGROUND
							break
						end

						background_colour = local_parent[ actual_y * p_width + actual_x ][ -tracked_colour ]
						tracked_colour = background_colour

					until background_colour > 0
				end

				-- The same goes for foreground colour...
				if foreground_colour < 0 or pixel1 == TRANSPARENT_FOREGROUND then
					local_parent = false_parent
					tracked_offset_x = x
					tracked_offset_y = y

					local tracked_colour = -2

					repeat
						local_parent = local_parent.parent

						if not local_parent then
							foreground_colour = DEFAULT_FOREGROUND
							break
						end

						tracked_offset_x = tracked_offset_x + local_parent.x1
						tracked_offset_y = tracked_offset_y + local_parent.y1

						local actual_y = _y + tracked_offset_y
						local actual_x = _x + tracked_offset_x
						local p_width  = local_parent.width
						local p_height = local_parent.height

						if actual_x < 0 or actual_x > p_width - 1 or actual_y < 0 or actual_y > p_height - 1 then
							foreground_colour = DEFAULT_FOREGROUND
							break
						end

						foreground_colour = local_parent[ actual_y * p_width + actual_x ][ -tracked_colour ]
						tracked_colour = foreground_colour

					until foreground_colour > 0
				end

				-- ...And finally for the character.
				-- Note that a colour cannot be transparent to a character, so
				-- there's no extra branch here
				local_parent = false_parent
				tracked_offset_x = x
				tracked_offset_y = y

				while character == TRANSPARENT_CHARACTER do
					local_parent = local_parent.parent

					if not local_parent then
						character = DEFAULT_CHARACTER
						break
					end

					tracked_offset_x = tracked_offset_x + local_parent.x1
					tracked_offset_y = tracked_offset_y + local_parent.y1

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
-- @param x			(Optional) The x coordinate in target to render self at, 1-based, defaults to self.x1 + 1
-- @param y			(Optional) The y coordinate in target to render self at, 1-based, defaults to self.y1 + 1
-- @return self
function buffer_methods:render_to_window( target, x, y )
	x = x or ( self.x1 and self.x1 + 1 or error( unable_to_set_optional_argument .. "'x': self.x1 is nil", 2 ) )
	y = y and y - 1 or ( self.y1       or error( unable_to_set_optional_argument .. "'y': self.y1 is nil", 2 ) )

	local scp, blit = target.setCursorPos, target.blit

	-- Go through all lines of the buffer
	for i, line in ipairs( self:cook_lines() ) do
		-- A -1 for i is included in the y definition above
		scp( x, y + i )
		blit( line[ 3 ], line[ 2 ], line[ 1 ] )
	end

	return self
end

--- Cook the buffer data into an array of blitable lines.
-- @param target	(Optional) The target buffer to use for transparency resolution, defaults to self.parent
-- @param start_x	(Optional) The x coordinate to start reading data at, 0-based, defaults to 0
-- @param start_y	(Optional) The y coordinate to start reading data at, 0-based, defaults to 0
-- @param end_x		(Optional) The x coordinate to end reading data at, 0-based, defaults to self.width - 1
-- @param end_y		(Optional) The y coordinate to end reading data at, 0-based, defaults to self.height - 1
-- @return lines An array of lines, where every line = { background_colours, foreground_colours, text }
function buffer_methods:cook_lines( target, start_x, start_y, end_x, end_y )
	target = target or self.parent

	local lines = {}
	local i = 1

	local h = self.height

	local self_width = self.width
	-- This avoids attempts to something something nil while enabling a nil parent
	local target_width = target and target.width or 0

	start_x = start_x or 0
	start_y = start_y or 0
	end_x = end_x or self_width - 1
	end_y = end_y or h - 1

	if target then
		-- Respect borders of the target
		start_x = max( start_x, -self.x )
		start_y = max( start_y, -self.y )
		end_x   = min( end_x, target_width  - self.x - 1 )
		end_y   = min( end_y, target.height - self.y - 1 )
	end

	-- Will be explained further down
	-- (in case target is nil, transparency resolution will exit cleanly)
	local false_parent = { parent = target }

	-- Go through all lines
	for y = start_y, end_y do
		local line = { "", "", "" }
		local line_offset = y * self_width

		-- Cache the line position for both the target buffer and us
		local target_offset = y * target_width
		local local_offset  = y * self_width

		for x = start_x, end_x do
			-- index is where we should store the resultant pixel in target
			local index = target_offset + x
			-- pixel is the data from our buffer
			local pixel = self[ local_offset + x ]

			-- Cache the contents for faster access
			local pixel1, pixel2, pixel3 = pixel[ 1 ], pixel[ 2 ], pixel[ 3 ]

			-- Set the pixel in target, resolving transparency along the way
			if pixel1 < 0 or pixel2 < 0 or pixel3 == TRANSPARENT_CHARACTER then
				local local_parent = false_parent

				local background_colour = pixel1
				local foreground_colour = pixel2
				local character = pixel3

				local tracked_offset_x = x
				local tracked_offset_y = y

				-- Not only we have to get to the non-transparent colour
				-- when the background_colour is transparent, we also have
				-- to resolve the colour if the *foreground* uses it

				if background_colour < 0 or pixel2 == TRANSPARENT_BACKGROUND then
					local tracked_colour = -1

					-- Down into the rabbit hole we go. One parent level further with every iteration.
					-- We have to let the loop run at least once, for the TRANSPARENT_BACKGROUND to resolve
					repeat
						-- This wouldn't work the first time (when the loop starts), that's
						-- why we defined local_parent to be the false_parent
						local_parent = local_parent.parent

						if not local_parent then
							-- We've reached the very bottom of the family stack, without luck
							-- Note that this also happens in case the target is nil, as
							-- is frequent for top-level buffers
							background_colour = DEFAULT_BACKGROUND
							break
						end

						-- All buffers have a position, we have to keep track of that
						tracked_offset_x = tracked_offset_x + local_parent.x1
						tracked_offset_y = tracked_offset_y + local_parent.y1

						local actual_y = y + tracked_offset_y
						local actual_x = x + tracked_offset_x
						local p_width  = local_parent.width
						local p_height = local_parent.height

						-- Check that we are within bounds
						-- We could subtract a 1 in the local definition above, but if actual_x < 0 then the operation
						-- doesn't even happen :P
						if actual_x < 0 or actual_x > p_width - 1 or actual_y < 0 or actual_y > p_height - 1 then
							-- We can't get a pixel out of bounds of this parent, so we'll just roll with
							-- the default colour.
							--TODO: Would it be better if we'd look for any parent that *is* within bounds instead?
							--      Probably not, the result isn't visible anyway since that part of self is outside
							--      of the parent
							background_colour = DEFAULT_BACKGROUND
							break
						end

						background_colour = local_parent[ actual_y * p_width + actual_x ][ -tracked_colour ]
						tracked_colour = background_colour

					until background_colour > 0
				end

				-- The same goes for foreground colour...
				if foreground_colour < 0 or pixel1 == TRANSPARENT_FOREGROUND then
					local_parent = false_parent
					tracked_offset_x = x
					tracked_offset_y = y

					local tracked_colour = -2

					repeat
						local_parent = local_parent.parent

						if not local_parent then
							foreground_colour = DEFAULT_FOREGROUND
							break
						end

						tracked_offset_x = tracked_offset_x + local_parent.x1
						tracked_offset_y = tracked_offset_y + local_parent.y1

						local actual_y = y + tracked_offset_y
						local actual_x = x + tracked_offset_x
						local p_width  = local_parent.width
						local p_height = local_parent.height

						if actual_x < 0 or actual_x > p_width - 1 or actual_y < 0 or actual_y > p_height - 1 then
							foreground_colour = DEFAULT_FOREGROUND
							break
						end

						foreground_colour = local_parent[ actual_y * p_width + actual_x ][ -tracked_colour ]
						tracked_colour = foreground_colour

					until foreground_colour > 0
				end

				-- ...And finally for the character.
				-- Note that a colour cannot be transparent to a character, so
				-- there's no extra branch here
				local_parent = false_parent
				tracked_offset_x = x
				tracked_offset_y = y

				while character == TRANSPARENT_CHARACTER do
					local_parent = local_parent.parent

					if not local_parent then
						character = DEFAULT_CHARACTER
						break
					end

					tracked_offset_x = tracked_offset_x + local_parent.x1
					tracked_offset_y = tracked_offset_y + local_parent.y1

					local actual_y = y + tracked_offset_y
					local actual_x = x + tracked_offset_x
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
				-- the math to the lines concatenation down below.
				local underneath = {
					background_colour;
					foreground_colour;
					character;
				}

				-- Assign the proper data to the rendered pixel
				line[ 1 ] = line[ 1 ] .. colour_lookup[ pixel1 > 0 and pixel1 or underneath[ -pixel1 ] ]
				line[ 2 ] = line[ 2 ] .. colour_lookup[ pixel2 > 0 and pixel2 or underneath[ -pixel2 ] ]
				line[ 3 ] = line[ 3 ] .. ( pixel3 == TRANSPARENT_CHARACTER and underneath[ 3 ] or pixel3 )
			else
				-- That was quick! This is a speed up for the large number of cases
				-- in which no transparency is used
				line[ 1 ] = line[ 1 ] .. colour_lookup[ pixel1 ]
				line[ 2 ] = line[ 2 ] .. colour_lookup[ pixel2 ]
				line[ 3 ] = line[ 3 ] .. pixel3
			end
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
	width  = width  or self.width
	height = height or self.height
	-- Visibility defaults to false
	visible = visible and true or false

	-- Colour defaults to parent.isColour()
	if is_colour == nil then
		is_colour = parent.isColour()
	end

	-- Retrieve information from parent
	local cursor_blink = parent.getCursorBlink and parent.getCursorBlink() or false

	local background_colour = parent.getBackgroundColour()
	local text_colour = parent.getTextColour()

	local cursor_x = 1
	local cursor_y = 1

	function win.write( text )
		local x = cursor_x

		local line_offset = ( cursor_y - 1 ) * width - 1

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
-- @param lines				The number of lines to scroll
-- @param background_colour	(Optional) The background colour to fill any empty pixels with, defaults to DEFAULT_BACKGROUND
-- @param foreground_colour	(Optional) The foreground colour to fill any empty pixels with, defaults to DEFAULT_FOREGROUND
-- @param character			(Optional) The character to fill any empty pixels with, defaults to DEFAULT_CHARACTER
-- @return self
function buffer_methods:scroll( lines, background_colour, foreground_colour, character )
	lines = tonumber( lines ) or error( "Expected number for 'lines'", 2 )

	local n_self = self.length
	local width, height = self.width, self.height

	local new_pixel = { 
		tonumber( background_colour ) or DEFAULT_BACKGROUND;
		tonumber( foreground_colour ) or DEFAULT_FOREGROUND;
		character                     or DEFAULT_CHARACTER;
	}

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
	local clear_pixel = {
		tonumber( background_colour ) or DEFAULT_BACKGROUND;
		tonumber( foreground_colour ) or DEFAULT_FOREGROUND;
		character                     or DEFAULT_CHARACTER;
	}

	-- Go through all pixels and set them to the clear pixel
	for i = 0, self.length do
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
		tonumber( background_colour ) or DEFAULT_BACKGROUND;
		tonumber( foreground_colour ) or DEFAULT_FOREGROUND;
		character                     or DEFAULT_CHARACTER;
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
		tonumber( background_colour ) or DEFAULT_BACKGROUND;
		tonumber( foreground_colour ) or DEFAULT_FOREGROUND;
		character                     or DEFAULT_CHARACTER;
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
	x = tonumber( x ) or error( "Expected number for 'x'", 2 )
	y = tonumber( y ) or error( "Expected number for 'y'", 2 )

	local w = self.width

	local text_length = #text

	if text_length ~= #background_colours or text_length ~= #foreground_colours then
		error( "'text', 'background_colours', and 'foreground_colours' all have to be of the same length", 2 )
	end

	local offset = y * w + x - 1
	text_length  = min( text_length, w - x )

	for i = max( -x, 0 ) + 1, text_length do
		-- A -1 for i is included in offset
		self[ offset + i ] = {
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
function buffer_methods:draw_filled_rectangle_from_points( start_x, start_y, end_x, end_y, background_colour, foreground_colour, character )
	local w = self.width

	-- Starting values must be smaller than ending ones
	end_x, start_x = max( start_x, end_x )
	end_y, start_y = max( start_y, end_y )

	local new_pixel = {
		tonumber( background_colour ) or DEFAULT_BACKGROUND;
		tonumber( foreground_colour ) or DEFAULT_FOREGROUND;
		character                     or DEFAULT_CHARACTER;
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
		tonumber( background_colour ) or DEFAULT_BACKGROUND;
		tonumber( foreground_colour ) or DEFAULT_FOREGROUND;
		character                     or DEFAULT_CHARACTER;
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
function buffer_methods:draw_rectangle_from_points( start_x, start_y, end_x, end_y, border_width,
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
-- @return Tail call of self:draw_rectangle_from_points(), resulting in self
function buffer_methods:draw_rectangle( x, y, width, height, border_width, background_colour, foreground_colour, character )
	return self
	:draw_rectangle_from_points( x, y, x + width - 1, y + height - 1, border_width, background_colour, foreground_colour, character )
end

--- Draw a circle outline using the centre point and radius, without corrections for CC rectangular pixels.
-- @param centre_x			The x coordinate of the circle's centre, 0-based
-- @param centre_y			The y coordinate of the circle's centre, 0-based
-- @param radius			The radius of the circle
-- @param background_colour	(Optional) The background colour to fill the circle outline with, defaults to DEFAULT_BACKGROUND
-- @param foreground_colour	(Optional) The foreground colour to fill the circle outline with, defaults to DEFAULT_FOREGROUND
-- @param character			(Optional) The character to fill the circle outline with, defaults to DEFAULT_CHARACTER
-- @return self
function buffer_methods:draw_circle_raw( centre_x, centre_y, radius, background_colour, foreground_colour, character )
	local w = self.width

	local new_pixel = {
		tonumber( background_colour ) or DEFAULT_BACKGROUND;
		tonumber( foreground_colour ) or DEFAULT_FOREGROUND;
		character                     or DEFAULT_CHARACTER;
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
-- @param centre_x			The x coordinate of the circle's centre, 0-based
-- @param centre_y			The y coordinate of the circle's centre, 0-based
-- @param radius			The radius of the circle
-- @param background_colour	(Optional) The background colour to fill the circle outline with, defaults to DEFAULT_BACKGROUND
-- @param foreground_colour	(Optional) The foreground colour to fill the circle outline with, defaults to DEFAULT_FOREGROUND
-- @param character			(Optional) The character to fill the circle outline with, defaults to DEFAULT_CHARACTER
-- @return self
function buffer_methods:draw_circle( centre_x, centre_y, radius, background_colour, foreground_colour, character )
	local w = self.width
	local self_height = self.height

	local new_pixel = {
		tonumber( background_colour ) or DEFAULT_BACKGROUND;
		tonumber( foreground_colour ) or DEFAULT_FOREGROUND;
		character                     or DEFAULT_CHARACTER;
	}

	local x = radius
	local y = 0
	local err = 0

	-- Generate points for the first octant, going counterclockwise
	-- and mirroring them to other octants
	while x >= y do
		local this_point_y, this_point_x

		-- Segment
		this_point_y = ( centre_y + round( ( 2 / 3 ) * y ) )
		this_point_x = centre_x + x

		if this_point_y >= 0 and this_point_y < self_height and this_point_x >= 0 and this_point_x < w then
			self[ this_point_y * w + this_point_x ] = new_pixel
		end

		-- Segment
		this_point_y = ( centre_y + round( ( 2 / 3 ) * x ) )
		this_point_x = centre_x + y

		if this_point_y >= 0 and this_point_y < self_height and this_point_x >= 0 and this_point_x < w then
			self[ this_point_y * w + this_point_x ] = new_pixel
		end

		-- Segment
		this_point_y = ( centre_y + round( ( 2 / 3 ) * x ) )
		this_point_x = centre_x - y

		if this_point_y >= 0 and this_point_y < self_height and this_point_x >= 0 and this_point_x < w then
			self[ this_point_y * w + this_point_x ] = new_pixel
		end

		-- Segment
		this_point_y = ( centre_y + round( ( 2 / 3 ) * y ) )
		this_point_x = centre_x - x

		if this_point_y >= 0 and this_point_y < self_height and this_point_x >= 0 and this_point_x < w then
			self[ this_point_y * w + this_point_x ] = new_pixel
		end

		-- Segment
		this_point_y = ( centre_y - round( ( 2 / 3 ) * y ) )
		this_point_x = centre_x - x

		if this_point_y >= 0 and this_point_y < self_height and this_point_x >= 0 and this_point_x < w then
			self[ this_point_y * w + this_point_x ] = new_pixel
		end

		-- Segment
		this_point_y = ( centre_y - round( ( 2 / 3 ) * x ) )
		this_point_x = centre_x - y

		if this_point_y >= 0 and this_point_y < self_height and this_point_x >= 0 and this_point_x < w then
			self[ this_point_y * w + this_point_x ] = new_pixel
		end

		-- Segment
		this_point_y = ( centre_y - round( ( 2 / 3 ) * x ) )
		this_point_x = centre_x + y

		if this_point_y >= 0 and this_point_y < self_height and this_point_x >= 0 and this_point_x < w then
			self[ this_point_y * w + this_point_x ] = new_pixel
		end

		-- Segment
		this_point_y = ( centre_y - round( ( 2 / 3 ) * y ) )
		this_point_x = centre_x + x

		if this_point_y >= 0 and this_point_y < self_height and this_point_x >= 0 and this_point_x < w then
			self[ this_point_y * w + this_point_x ] = new_pixel
		end


		y = y + 1
		err = err + 1 + 2 * y

		if 2 * ( err - x ) + 1 > 0 then
			x = x - 1
			err = err + 1 - 2 * x
		end
	end

	return self
end

--- Draw a filled ellipse.
--	Sorry for the inconsistency here, this code has been borrowed
--	from Xenthera's graphics library
-- @param x	description
-- @param y	description
-- @param width	description
-- @param height	description
-- @param background_colour	description
-- @param foreground_colour	description
-- @param character	description
-- @return self
function buffer_methods:draw_filled_ellipse( x, y, width, height, background_colour, foreground_colour, character )
	local self_width  = self.width
	local self_height = self.height

	local hh = height * height
	local ww = width * width
	local hhww = hh * ww
	local x0 = width - 1
	local delta_x = 0

	local new_pixel = {
		tonumber( background_colour ) or DEFAULT_BACKGROUND;
		tonumber( foreground_colour ) or DEFAULT_FOREGROUND;
		character                     or DEFAULT_CHARACTER;
	}

	if y < self_height and y >= 0 then
		local offset = y * self_width

		for _x = max( x - width, 0 ), min( x + width, self_width - 1 ) do
			self[ offset + _x ] = new_pixel
		end
	end

	for _y = 0, height - 1 do
		x1 = x0 - ( delta_x - 1 )

		for i = x1, 0, -1 do
			if ( x1 * x1 * hh + _y * _y * ww <= hhww ) then
				break
			end

			x1 = x1 - 1
		end

		delta_x = x0 - x1
		x0 = x1

		local y_pos1 = y - _y
		local y_pos2 = y + _y

		if y_pos1 >= 0 and y_pos1 < self_height then
			y_pos1 = y_pos1 * self_width

			for _x = max( x - x0, 0 ), min( x + x0, self_width - 1 ) do
				self[ y_pos1 + _x ] = new_pixel
			end
		end

		if y_pos2 >= 0 and y_pos2 < self_height then
			y_pos2 = y_pos2 * self_width

			for _x = max( x - x0, 0 ), min( x + x0, self_width - 1 ) do
				self[ y_pos2 + _x ] = new_pixel
			end
		end
	end

	return self
end

--- Write text to the buffer.
-- @param x					The x coordinate to start writing at, 0-based
-- @param y					The y coordinate to start writing at, 0-based
-- @param text				The text to write
-- @param background_colour	(Optional) The background colour to use, defaults to DEFAULT_BACKGROUND
-- @param foreground_colour	(Optional) The foreground colour to use, defaults to DEFAULT_FOREGROUND
-- @return self
function buffer_methods:write( x, y, text, background_colour, foreground_colour )
	background_colour = background_colour or DEFAULT_BACKGROUND
	foreground_colour = foreground_colour or DEFAULT_FOREGROUND

	local width = self.width
	local line_offset = y * width + x - 1
	local last_pixel, last_char

	-- Go through the string, writing the new pixels
	for i = max( -x, 0 ) + 1, min( #text, width - x ) do
		local char = sub( text, i, i )

		-- Reduce memory usage whenever there are two identical characters
		if char ~= last_char then
			last_pixel = {
				background_colour;
				foreground_colour;
				char;
			}

			last_char = char
		end

		-- A -1 for i is included in line_offset
		local index = line_offset + i

		self[ index ] = last_pixel
	end

	return self
end

--- Fix errors in the buffer, such as missing pixels or unknown colours.
--	Fixes the following:
--	* Missing pixels
--	* Strings longer than one character for pixel[3]
--	* Missing or modified methods
--	* Missing length
--	* Missing x/y position
--	* Unknown colours
-- @param start_x			(Optional) The x coordinate to start repairing at, 0-based, defaults to 0
-- @param start_y			(Optional) The y coordinate to start repairing at, 0-based, defaults to 0
-- @param end_x				(Optional) The x coordinate to end repairing at, 0-based, defaults to self.width - 1
-- @param end_y				(Optional) The y coordinate to end repairing at, 0-based, defaults to self.height - 1
-- @param background_colour	(Optional) The background colour to replace a broken pixel with, defaults to DEFAULT_BACKGROUND
-- @param foreground_colour	(Optional) The foreground colour to replace a broken pixel with, defaults to DEFAULT_FOREGROUND
-- @param character			(Optional) The character to replace a broken pixel with, defaults to DEFAULT_CHARACTER
-- @return self, number of errors found
function buffer_methods:repair( start_x, start_y, end_x, end_y, background_colour, foreground_colour, character )
	start_x = start_x or 0
	start_y = start_y or 0

	end_x = end_x or ( self.width and self.width - 1 or error( "self.width is not present, buffer is unrepairable", 2 ) )
	end_y = end_y or ( self.height and self.height - 1 or error( "self.height is not present, buffer is unrepairable", 2 ) )

	background_colour = background_colour or DEFAULT_BACKGROUND
	foreground_colour = foreground_colour or DEFAULT_FOREGROUND
	character         = character         or DEFAULT_CHARACTER

	local w = self.width
	local n_errors = 0

	local new_pixel = {
		background_colour;
		foreground_colour;
		character;
	}

	-- Cache pixels that were already corrected
	local corrected_pixels = {}

	-- Go through all pixels in the to-be-repaired area
	for y = start_y, end_y do
		local line_offset = y * w

		for x = start_x, end_x do
			local pixel = self[ line_offset + x ]

			if type( pixel ) ~= "table" then
				-- The pixel is not here at all, set it to a blank pixel
				n_errors = n_errors + 1
				self[ line_offset + x ] = new_pixel

			elseif not corrected_pixels[ pixel ] then
				-- The pixel is here, check all data
				if type( pixel[ 1 ] ) ~= "number" or not colour_lookup[ pixel[ 1 ] ] then
					n_errors = n_errors + 1
					pixel[ 1 ] = background_colour
				end

				if type( pixel[ 2 ] ) ~= "number" or not colour_lookup[ pixel[ 2 ] ] then
					n_errors = n_errors + 1
					pixel[ 2 ] = foreground_colour
				end

				if type( pixel[ 3 ] ) ~= "string" or #pixel[ 3 ] ~= 1 then
					n_errors = n_errors + 1
					pixel[ 3 ] = character
				end

				corrected_pixels[ pixel ] = true
			end
		end
	end

	-- This will hopefully force the GC to free the memory ASAP
	corrected_pixels = nil

	-- Check that all methods of the buffer are present and were not
	-- modified, and reset those that aren't/were
	for name, fn in pairs( buffer_methods ) do
		if self[ name ] ~= fn then
			n_errors = n_errors + 1
			self[ name ] = fn
		end
	end

	if not self.length then
		self.length = self.width * self.height - 1
		n_errors = n_errors + 1
	end

	if not self.x1 then
		self.x1 = 0
		n_errors = n_errors + 1
	end

	if not self.y2 then
		self.y2 = 0
		n_errors = n_errors + 1
	end

	return self, n_errors
end

--- Iterate over the buffer.
-- @param start_x	(Optional) The x coordinate to start iterating from, 0-based, defaults to 0
-- @param start_y	(Optional) The y coordinate to start iterating from, 0-based, defaults to 0
-- @param end_x		(Optional) The x coordinate to end iterating at, 0-based, defaults to self.width - 1
-- @param end_y		(Optional) The y coordinate to end iterating at, 0-based, defaults to self.height - 1
-- @return fn An iterator function which, when called, returns the next pixel, its coordinates and its index
function buffer_methods:iter( start_x, start_y, end_x, end_y )
	local w = self.width

	local x = start_x - 1 or -1
	local y = start_y or 0

	end_x   = end_x   or self.width - 1
	end_y   = end_y   or self.height - 1

	local line_offset = y * w

	return function()
		x = x + 1

		if x >= end_x then
			y = y + 1

			if y >= end_y then
				return nil
			end

			line_offset = y * w
			x = 0
		end

		local index = line_offset + x

		return self[ index ], x, y, index
	end
end

-- Aliases
buffer_methods.render_to_term = buffer_methods.render_to_window

buffer_methods.draw_rect = buffer_methods.draw_rectangle
buffer_methods.draw_rect_from_points = buffer_methods.draw_rectangle_from_points
buffer_methods.draw_filled_rect = buffer_methods.draw_filled_rectangle
buffer_methods.draw_filled_rect_from_points = buffer_methods.draw_filled_rectangle_from_points

buffer_methods.iterate = buffer_methods.iter

--- Create a new buffer using one point, width and height.
-- @param x					(Optional) The x coordinate of the buffer in parent, 0-based, defaults to 0
-- @param y					(Optional) The y coordinate of the buffer in parent, 0-based, defaults to 0
-- @param width				(Optional) The width of the buffer, defaults to 0
-- @param height			(Optional) The height of the buffer, defaults to 0
-- @param parent			This buffer's render target
-- @param background_colour	(Optional) The background colour to prefill the buffer with, defaults to DEFAULT_BACKGROUND
-- @param foreground_colour	(Optional) The foreground colour to prefill the buffer with, defaults to DEFAULT_FOREGROUND
-- @param character			(Optional) The character to prefill the buffer with, defaults to DEFAULT_CHARACTER
-- @param no_prefill		(Optional) Disable prefilling of the buffer, defaults to false
-- @param existing_table	(Optional) Use this table for the object instead of creating a new one
-- @return Tail call of buffer.new_from_points(), resulting in the new buffer
-- @see buffer.new_from_points
function buffer.new( x, y, width, height, parent, background_colour, foreground_colour, character, no_prefill, existing_table )
	return buffer.new_from_points( x, y, x and ( x + width - 1 ) or 0, y and ( y + height - 1 ) or 0, parent,
		background_colour, foreground_colour, character, no_prefill, existing_table  )
end

--- Create a new buffer using two points.
-- @param x1				(Optional) The x coordinate of the first point of the buffer in parent, 0-based, defaults to 0
-- @param y1				(Optional) The y coordinate of the first point of the buffer in parent, 0-based, defaults to 0
-- @param x2				(Optional) The x coordinate of the second point of the buffer in parent, 0-based, defaults to 0
-- @param y2				(Optional) The y coordinate of the second point of the buffer in parent, 0-based, defaults to 0
-- @param parent			This buffer's render target
-- @param background_colour	(Optional) The background colour to prefill the buffer with, defaults to DEFAULT_BACKGROUND
-- @param foreground_colour	(Optional) The foreground colour to prefill the buffer with, defaults to DEFAULT_FOREGROUND
-- @param character			(Optional) The character to prefill the buffer with, defaults to DEFAULT_CHARACTER
-- @param no_prefill		(Optional) Disable prefilling of the buffer, defaults to false
-- @param existing_table	(Optional) Use this table for the object instead of creating a new one
-- @return buffer			The new buffer
function buffer.new_from_points( x1, y1, x2, y2, parent, background_colour, foreground_colour, character, no_prefill, existing_table )
	local n = setmetatable( existing_table or {}, buffer_metatable )

	x1 = x1 or 0
	y1 = y1 or 0
	x2 = x2 or 0
	y2 = y2 or 0

	-- Ending values must be larger than starting ones
	x2, x1 = max( x1, x2 )
	y2, y1 = max( y1, y2 )

	local width  = x2 - x1 + 1
	local height = y2 - y1 + 1

	local new_pixel = {
		tonumber( background_colour ) or DEFAULT_BACKGROUND;
		tonumber( foreground_colour ) or DEFAULT_FOREGROUND;
		character                     or DEFAULT_CHARACTER;
	}

	if not no_prefill then
		-- Prefill the buffer with new_pixel
		for y = 0, y2 do
			for x = 0, x2 do
				n[ y * width + x ] = new_pixel
			end
		end
	end

	-- Copy the buffer methods to this instance
	for k, fn in pairs( buffer_methods ) do
		n[ k ] = fn
	end

	n.x1 = x1
	n.y1 = y1
	n.x2 = x2
	n.y2 = y2

	n.width  = width
	n.height = height
	n.length = width * height - 1
	n.parent = parent

	-- Metadata
	n.__type = "desktox-buffer"

	return n
end

-- Imports
buffer.clone = buffer_methods.clone
buffer.repair = buffer_methods.repair

--- Syntactic sugar for both :render() and :render_to_window().
--	Will attempt to decide which of the 2 methods to use, based
--	on self.parent and given arguments. Defaults to
--	:render_to_window(). Should be *avoided* for best performance.
-- @param target	The buffer or window to render to
-- @param ...		Any arguments passed to :render() or :render_to_window()
-- @return Tail call of :render() or :render_to_window()
function buffer_metatable:__call( target, ... )
	if self.parent or ( type( target ) == "table" and target.__type == "desktox-buffer" ) then
		return self:render( target, ... )
	else
		return self:render_to_window( target, ... )
	end
end

-- Export the complete method table
buffer.methods = buffer_methods

-- Export logging functions
buffer.log = log
buffer.close_log = close_log

-- Export the default values
buffer.DEFAULT_BACKGROUND = DEFAULT_BACKGROUND
buffer.DEFAULT_FOREGROUND = DEFAULT_FOREGROUND
buffer.DEFAULT_CHARACTER  = DEFAULT_CHARACTER

return buffer
