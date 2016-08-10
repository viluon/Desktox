
-- Desktox, graphics stuff by @viluon

local buffer = {}

local buffer_methods = {}
local buffer_metatable = {}

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
-- @param x			(Optional) The x coordinate, 0-based, defaults to self.x
-- @param y			(Optional) The y coordinate, 0-based, defaults to self.y
-- @return self
function buffer_methods:render( target )
	target = target or self.parent

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
			target.setBackgroundColour( self[ _y * self.width + _x ] )
			target.write( " " )
		end
	end

	return self
end

--- Create a new buffer
-- @param x			The x coordinate of the buffer in parent, 0-based
-- @param y			The y coordinate of the buffer in parent, 0-based
-- @param width		The width of the buffer
-- @param height	The height of the buffer
-- @param parent	This buffer's render target
-- @param colour	(Optional) The colour to prefill the buffer with, defaults to white
-- @return buffer	The new buffer
function buffer.new( x, y, width, height, parent, colour )
	local n = setmetatable( {}, buffer_metatable )
	colour = colour or colours.white

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

	n.x = x
	n.y = y
	n.width = width
	n.height = height
	n.parent = parent

	return n
end

buffer.clone = buffer_methods.clone

return buffer
