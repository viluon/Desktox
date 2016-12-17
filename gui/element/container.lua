
-- Desktox
--  A set of graphics libraries for ComputerCraft by @viluon <viluon@espiv.net>

--   desktox.gui.button
--    The Desktox GUI library - the button element

--    This Source Code Form is subject to the terms of the Mozilla Public
--    License, v. 2.0. If a copy of the MPL was not distributed with this
--    file, You can obtain one at http://mozilla.org/MPL/2.0/.

local handler = require( "desktox.handler" )
local buffer  = require( "desktox.buffer" )
local text    = require( "desktox.gui.lib.text" )

local container = {}
local container_methods = {}

--- Create a new container using one point, width, and height.
-- @param x description
-- @param y description
-- @param width description
-- @param height description
-- @param parent description
-- @param background_colour description
-- @param foreground_colour description
-- @param text description
-- @return The new container object
function container.new( x, y, width, height, parent, background_colour, foreground_colour, text )
	local n = {}

	-- Copy the container methods into this instance
	for name, method in pairs( container_methods ) do
		n[ name ] = method
	end

	return n
end
