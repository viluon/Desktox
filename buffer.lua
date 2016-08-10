
-- Desktox, graphics stuff by @viluon

local buffer = {}

local buffer_methods = {}
local buffer_metatable = {}

--- Resize the buffer
-- @param width		The desired new width
-- @param height	The desired new height
-- @return self
function buffer_methods:resize( width, height )
	local insert = table.insert()
	local black = colours.black

	-- Loop through all lines, inserting black pixels at the end
	for y = 1, self.height do
		--TODO
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
-- @param data		(Optional) The data of the new clone
-- @return buffer	The new buffer, a clone of self
function buffer_methods:clone( data )
	local clone = buffer.new( self.x, self.y, self.width, self.height, self.parent )

	-- Clone the pixel data
	for i, pixel in ipairs( data or self ) do
		clone[ i ] = pixel
	end

	return clone
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

	-- Prefill the buffer with pixels of the chosen colour or white
	for y = 0, height - 1 do
		for x = 0, width - 1 do
			n[ y * width + x ] = colour or colours.white
		end
	end

	return n
end

return buffer
