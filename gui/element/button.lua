
-- Desktox
--  A set of graphics libraries for ComputerCraft by @viluon <viluon@espiv.net>

--   desktox.gui.button
--    The Desktox GUI library - the button element

--    This Source Code Form is subject to the terms of the Mozilla Public
--    License, v. 2.0. If a copy of the MPL was not distributed with this
--    file, You can obtain one at http://mozilla.org/MPL/2.0/.

local handler = require( "desktox.handler" )
local text    = require( "desktox.gui.lib.text" )

local button = {}
local button_methods = {}
local button_metatable = {}

-- Utility functions
local round = require( "desktox.utils" ).round
local max   = require( "desktox.utils" ).max

--- Draw the button to a buffer.
-- @param target	(Optional) The target buffer, defaults to self.parent
-- @param x			(Optional) The x coordinate to draw the button at, defaults to self.x1
-- @param y			(Optional) The y coordinate to draw the button at, defaults to self.y1
-- @return self
function button_methods:draw( target, x, y )
	target = target or self.parent
	x = x or self.x1
	y = y or self.y1

	local self_width  = self.width
	local self_height = self.height
	local bg = self.active and self.active_background_colour or self.background_colour
	local fg = self.active and self.active_foreground_colour or self.foreground_colour

	target:draw_filled_rectangle( x, y, self_width, self_height, bg, fg, " " )
	target:write( x, y + round( ( self_height - 1 ) / 2 ), text.align_centre( self.text, self_width ), bg, fg )

	return self
end

--- Create a new button, using one point, width and height.
-- @param x					The x coordinate of the button
-- @param y					The y coordinate of the button
-- @param width				The width of the button
-- @param height			The height of the button
-- @param parent			The parent container
-- @param background_colour	The background colour of the button
-- @param foreground_colour	The foreground colour of the button
-- @param text				The text displayed on the button
-- @return Tail call of button.new_from_points, resulting in the new button
-- @see button.new_from_points
function button.new( x, y, width, height, parent, background_colour, foreground_colour, text, existing_table )
	return button.new_from_points( x, y, x + width - 1, y + height - 1, parent, background_colour, foreground_colour, text, existing_table )
end

--- Create a new button using two points.
-- @param x1				The x coordinate of the first point
-- @param y1				The y coordinate of the first point
-- @param x2				The x coordinate of the second point
-- @param y2				The y coordinate of the second point
-- @param parent			The parent container
-- @param background_colour	The background colour of the button
-- @param foreground_colour	The foreground colour of the button
-- @param text				The text displayed on the button
-- @return The new button
function button.new_from_points( x1, y1, x2, y2, parent, background_colour, foreground_colour, text, existing_table )
	-- Starting values must be smaller than ending ones
	x2, x1 = max( x1, x2 )
	y2, y1 = max( y1, y2 )

	local n = {}

	n.x1 = x1
	n.y1 = y1
	n.x2 = x2
	n.y2 = y2

	n.width  = x2 - x1 + 1
	n.height = y2 - y1 + 1

	n.parent = parent

	n.background_colour = background_colour
	n.foreground_colour = foreground_colour
	n.text = text

	n.handler = handler.new_from_points( x1, y1, x2, y2 )
	n.callbacks = n.handler.callbacks
	n.active = false

	-- Copy the button methods to the new instance
	for k, fn in pairs( button_methods ) do
		n[ k ] = fn
	end

	return n
end

return button
