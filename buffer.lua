
-- Desktox, graphics stuff by @viluon

local buffer = {}

local buffer_methods = {}
local buffer_metatable = {}

-- Constants
local TRANSPARENT = 0x0

-- Error messages
local unable_to_set_optional_argument = "Unable to set optional argument "

--- Resize the buffer
-- @param width		(Optional) The desired new width, defaults to self.width
-- @param height	(Optional) The desired new height, defaults to self.height
-- @param colour	(Optional) The colour to set any new pixels to, defaults to white
-- @return self
function buffer_methods:resize( width, height, colour )
	local insert = table.insert
	local remove = table.remove

	local self_width = self.width
	local self_height = self.height
	local n_self = #self

	colour = colour or colours.white
	width = width or self_width
	height = height or self_height

	-- Loop through all lines
	for y = math.min( self_height, height ) - 1, 0, -1 do
		if width > self_width then
			local line_offset = y * self_width

			-- Insert pixels at the end of the line
			for x = 0, width - self_width - 1 do
				insert( self, line_offset, colour )
				n_self = n_self + 1
			end

		elseif width < self_width then
			local line_offset = y * width

			-- Drop the pixels exceeding new width
			for x = 0, self_width - width - 1 do
				remove( self, line_offset, colour )
				n_self = n_self - 1
			end			
		end
	end

	if height > self_height then
		-- Insert blank lines
		for i = n_self, width * height - 1 do
			self[ i ] = colour
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
		for x = 0, self.width - 1 do
			self[ y * w + x ] = fn( self, x, y, clone[ y * w + x ] )
		end
	end

	return self, clone
end

--- Clone the buffer into a new object
-- @param data		(Optional) The data of the new clone, defaults to self
-- @return buffer	The new buffer, a clone of self
function buffer_methods:clone( data )
	local clone = buffer.new( self.x, self.y, self.width, self.height, self.parent )

	-- Clone the pixel data
	for i, pixel in ipairs( data or self ) do
		clone[ i ] = pixel
	end

	return clone
end

--- Render the buffer to another buffer
-- @param target	(Optional) The buffer to render to, defaults to self.parent
-- @param x			(Optional) The x coordinate to render self at, 0-based, defaults to self.x
-- @param y			(Optional) The y coordinate to render self at, 0-based, defaults to self.y
-- @param start_x	(Optional) The x coordinate on self to start rendering from, 0-based, defaults to 0
-- @param start_y	(Optional) The y coordinate on self to start rendering from, 0-based, defaults to 0
-- @param end_x		(Optional) The x coordinate on self to stop rendering at, 0-based, defaults to self.width - 1
-- @param end_y		(Optional) The y coordinate on self to stop rendering at, 0-based, defaults to self.height - 1
-- @return self
function buffer_methods:render( target, x, y, start_x, start_y, end_x, end_y )
	target = target or self.parent or error( unable_to_set_optional_argument .. "'target': self.parent is nil", 2 )
	x      = x      or self.x      or error( unable_to_set_optional_argument .. "'x': self.x is nil", 2 )
	y      = y      or self.y      or error( unable_to_set_optional_argument .. "'y': self.y is nil", 2 )

	start_x = start_x or 0
	start_y = start_y or 0
	end_x = end_x or self.width - 1
	end_y = end_y or self.height - 1

	-- Loop through all coordinates
	for _y = start_y, end_y do
		local target_offset = ( _y + y ) * target.width + x
		local local_offset  = _y * self.width

		for _x = start_x, end_x do
			local pixel = self[ local_offset + _x ]

			-- Ignore transparent colour
			if pixel ~= TRANSPARENT then
				-- Set the pixel in target
				target[ target_offset + _x ] = pixel
			end
		end
	end

	return self
end

--- Render the buffer to a CraftOS window object
-- @param target	The window to render to
-- @param x			(Optional) The x coordinate, 1-based, defaults to self.x + 1
-- @param y			(Optional) The y coordinate, 1-based, defaults to self.y + 1
-- @return self
function buffer_methods:render_to_window( target, x, y )
	x = x or self.x
	y = y or self.y

	-- Render each pixel separately
	--TODO: Rewrite with window.blit()
	for _y = 0, self.height - 1 do
		for _x = 0, self.width - 1 do
			target.setCursorPos( _x + x + 1, _y + y + 1 )

			if not self[ _y * self.width + _x ] then
				error( "No pixel at " .. _x .. ":" .. _y, 2 )
			end

			target.setBackgroundColour( self[ _y * self.width + _x ] )
			target.write( " " )
		end
	end

	return self
end

--- Create a new buffer
-- @param x			(Optional) The x coordinate of the buffer in parent, 0-based, defaults to 0
-- @param y			(Optional) The y coordinate of the buffer in parent, 0-based, defaults to 0
-- @param width		(Optional) The width of the buffer, defaults to 0
-- @param height	(Optional) The height of the buffer, defaults to 0
-- @param parent	This buffer's render target
-- @param colour	(Optional) The colour to prefill the buffer with, defaults to white
-- @return buffer	The new buffer
function buffer.new( x, y, width, height, parent, colour )
	local n = setmetatable( {}, buffer_metatable )
	colour = colour or colours.white

	width = width or 0
	height = height or 0

	-- Prefill the buffer with pixels of the chosen colour or white
	for y = 0, height - 1 do
		for x = 0, width - 1 do
			n[ y * width + x ] = colour
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

return buffer
