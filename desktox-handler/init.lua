
-- Desktox
--  A set of graphics libraries for ComputerCraft by @viluon <viluon@espiv.net>

--   desktox-handler
--    The Desktox event handling library

--    This Source Code Form is subject to the terms of the Mozilla Public
--    License, v. 2.0. If a copy of the MPL was not distributed with this
--    file, You can obtain one at http://mozilla.org/MPL/2.0/.

local handler = {}
local handler_methods = {}
local handler_metatable = {}
local handler_callbacks_metatable = {}

-- The 'owner' field of event_handler.callbacks,
-- has to be inaccesible from the outside
local owner = {}

-- Utilities
local setmetatable = setmetatable
local type = type
local unpack = unpack
local pairs = pairs
local ipairs = ipairs
local tostring = tostring
local tonumber = tonumber
local error = error

local insert = table.insert
local remove = table.remove

-- Events
--  Global events are passed to all children, regardless of which child is currently selected
--  Location events have on-screen location information tied to them
local global_events = {
	[ "alarm" ]             = true;
	[ "task_complete" ]     = true;
	[ "redstone" ]          = true;
	[ "disk" ]              = true;
	[ "disk_eject" ]        = true;
	[ "peripheral" ]        = true;
	[ "peripheral_detach" ] = true;
	[ "rednet_message" ]    = true;
	[ "modem_message" ]     = true;
	[ "monitor_resize" ]    = true;
	[ "term_resize" ]       = true;
	[ "turtle_inventory" ]  = true;
	-- You can drag something *out* of its borders,
	-- hence it must be global
	[ "mouse_drag" ]        = true;
}

--  Location settings, tell the handler where to look for coordinates in the event arguments
local x2y3 = {
	x = 2;
	y = 3;
	one_based = true;
}

local location_events = {
	[ "mouse_click" ]   = x2y3;
	[ "mouse_up" ]      = x2y3;
	[ "mouse_scroll" ]  = x2y3;
	[ "mouse_drag" ]    = x2y3;
	[ "monitor_touch" ] = x2y3;
}

--- Handle an event.
-- @param event_name	The name of the event (such as 'mouse_click')
-- @param event_args	(Optional) An array of arguments for the event
-- @return self
function handler_methods:handle( event_name, event_args )
	if type( event_name ) ~= "string" then
		error( "Expected string as 'event_name'", 2 )
	end

	local is_global = global_events[ event_name ]
	local loc_info = location_events[ event_name ]

	local selected = self.selected

	local x_pos, y_pos

	if loc_info then
		local x, y = event_args[ loc_info.x ], event_args[ loc_info.y ]

		if x and y then
			if loc_info.one_based then
				x_pos = x - self.x1 - 1
				y_pos = y - self.y1 - 1
			else
				x_pos = x - self.x1
				y_pos = y - self.y1
			end
		end
	end

	-- Parent should do the callback earlier than child
	-- Note that we do not care what the event is, so
	-- local custom events get handled as well
	--TODO: pcall?
	local fn = self.callbacks[ event_name ]
	if fn then
		fn( event_args )
	end

	if not self.family_callbacks[ event_name ] then
		return
	end

	if is_global or x_pos then
		-- Check all children
		for i, child in ipairs( self.children ) do
			if  is_global
			    or ( x_pos
			         and x_pos >= child.x1 and x_pos <= child.x2
			         and y_pos >= child.y1 and y_pos <= child.y2 )
			then
				child:handle( event_name, event_args )

				if not is_global then
					self.selected = child
					selected = child
					child:handle( "on_select", event_name )
				end
			end
			
			if not is_global and selected ~= child then
				child:handle( "on_deselect", event_name )
			end
		end
	end

	return self
end

--- Handle a raw CraftOS event.
-- @param ...	The raw CraftOS event
-- @return Tail call of self:handle(), resulting in self
function handler_methods:handle_raw( ... )
	local event_args = { ... }

	return self:handle( remove( event_args, 1 ), event_args )
end

--- Add a new child.
-- @param child	The handler to adopt
-- @return self
function handler_methods:adopt( child )
	if type( child ) ~= "table" or child.__type ~= "handler" then
		error( "Expected event_handler as 'child'", 2 )
	end

	local family_callbacks = self.family_callbacks
	child.parent = self

	-- Add the callbacks of the new child to the family_callbacks table, for faster react time
	for event_name, fn in pairs( child.callbacks ) do
		family_callbacks[ event_name ] = true
	end

	insert( self.children, child )

	return self
end

--- Register a new callback.
-- @param event_name	The event to trigger the callback on
-- @param fn			The function to call
-- @return self, previous value of self.callbacks[ event_name ]
function handler_methods:register_callback( event_name, fn )
	event_name = tostring( event_name )

	if type( fn ) ~= "function" then
		error( "Expected function as 'fn'", 2 )
	end

	local previous_value = self.callbacks[ event_name ]
	self.callbacks[ event_name ] = fn

	local parent = self.parent

	if parent then
		parent.family_callbacks[ event_name ] = true
	end

	return self, previous_value
end

-- Aliases
handler_methods.add_child = handler_methods.adopt

--- Create a new event handler.
-- @param x			The x coordinate of the handler area
-- @param y			The y coordinate of the handler area
-- @param width		The width of the handler area
-- @param height	The height of the handler area
-- @param callbacks	(Optional) A table of callbacks, structured as { [ event_name ] = fn }
-- @return The new event handler
function handler.new( x, y, width, height, callbacks )
	local n = setmetatable( {}, handler_metatable )

	n.family_callbacks = {}
	n.callbacks = { owner = n }

	if type( callbacks ) == "table" then
		-- Import the callbacks
		for k, fn in pairs( callbacks ) do
			if type( fn ) == "function" and type( k ) == "string" then
				n.callbacks[ k ] = fn
			end
		end
	end

	-- Copy the handler methods to the new instance
	for name, method in pairs( handler_methods ) do
		n[ name ] = method
	end

	n.x1 = x
	n.y1 = y
	n.x2 = x + width - 1
	n.y2 = y + height - 1

	n.children = {}
	n.queue = {}

	-- Metadata
	n.__type = "handler"

	return n
end

--- An alias for event_handler:handle().
-- @param ...	The arguments passed to :handle()
-- @return Tail call of event_handler:handle()
-- @see handler_methods:handle
function handler_metatable:__call( ... )
	return self:handle( ... )
end

--- An alias for event_handler:register_callback().
-- @param callbacks	description
-- @param event_name	description
-- @param fn	description
-- @return Tail call of event_handler:register_callback()
-- @see handler_methods:register_callback
function handler_callbacks_metatable:__newindex( callbacks, event_name, fn )
	return callbacks[ owner ]:register_callback( event_name, fn )
end

return handler
