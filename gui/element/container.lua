
-- Desktox
--  A set of graphics libraries for ComputerCraft by @viluon <viluon@espiv.net>

--   desktox.gui.container
--    The Desktox GUI library - the container element

--    This Source Code Form is subject to the terms of the Mozilla Public
--    License, v. 2.0. If a copy of the MPL was not distributed with this
--    file, You can obtain one at http://mozilla.org/MPL/2.0/.

local handler = require( "desktox.handler" )
local buffer  = require( "desktox.buffer" )

local max = require( "desktox.utils" ).max

local container = {}
local container_methods = {}
local container_metatable = {}

--- Create a new container using two points.
-- @param x1	description
-- @param y1	description
-- @param x2	description
-- @param y2	description
-- @return The new container
function container.new_from_points( x1, y1, x2, y2 )
	local n = {}

	x1 = x1 or 0
	y1 = y1 or 0
	x2 = x2 or 0
	y2 = y2 or 0

	-- Starting values must be smaller than ending ones
	x2, x1 = max( x1, x2 )
	y2, y1 = max( y1, y2 )

	local width  = x2 - x1 + 1
	local height = y2 - y1 + 1

	n.x1 = x1
	n.y1 = y1
	n.x2 = x2
	n.y2 = y2

	n.width  = width
	n.height = height

	n.buffer = buffer.new_from_points( x1, y1, x2, y2 )

	return n
end
