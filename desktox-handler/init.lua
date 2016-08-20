
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

-- The 'owner' field of event_handler.callbacks
-- mustn't clash with an event name, so we
-- use a local table as the key
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
local rawset = rawset

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
	-- Whether the event can select an element
	selects = true;
	-- Whether the coordinates passed are 1-based (otherwise 0-based)
	one_based = true;
}

local x2y3_no_select = {
	x = 2;
	y = 3;
	selects = false;
	one_based = true;
}

local location_events = {
	[ "mouse_click" ]   = x2y3;
	[ "mouse_up" ]      = x2y3;
	[ "monitor_touch" ] = x2y3;

	-- Scrolling should not select and deselect elements
	[ "mouse_scroll" ]  = x2y3_no_select;
	-- Only clicks should actually count, drags should really be handled internally
	[ "mouse_drag" ]    = x2y3_no_select;
}

--- Append text to the log file.
-- @param txt	The text to write
-- @return nil
local function log( txt )
	local f = io.open( "/log.txt", "a" )
	local time = tostring( os.clock() )

	f:write( "[" .. time .. string.rep( " ", math.max( 0, 10 - #time ) ) .. "]\t" .. txt .. "\n" )

	f:close()
end

--- Handle an event.
-- @param event_name	The name of the event to handle
-- @param local_only	If true, the event won't be propagated to child elements
-- @param ...			The event's arguments
-- @return A tail call chain of handle_internal resulting in self
-- @see handler_methods:handle_internal
function handler_methods:handle_and_return( event_name, ... )
	if type( event_name ) ~= "string" then
		error( "Expected string as 'event_name'", 2 )
	end

	--log( ":handle_and_return() called with '" .. event_name .. "'" )

	local event_args = { ... }

	local is_global = global_events[ event_name ]
	local loc_info = location_events[ event_name ]

	if loc_info then
		-- Offset the coordinates if they come from a 1-based system
		local offset = loc_info.one_based and 1 or 0

		-- loc_info is now a coord table, as defined in the coords param description of :handle_internal()
		loc_info = {
			x = event_args[ loc_info.x ] - offset;
			y = event_args[ loc_info.y ] - offset;
			selects = loc_info.selects;
		}
	end

	self:handle_internal( event_name, event_args, is_global, loc_info and loc_info.selects, loc_info, {}, {}, 0, self )

	return event_name, event_args
end

--- Identical to handler_methods:handle_and_return(), except that the event won't be propagated to children.
-- @param event_name	The name of the event
-- @param ...			The arguments to the event
-- @return The name of the event, its arguments in a table
-- @see handler_methods:handle_internal
function handler_methods:handle_local_and_return( event_name, ... )
	if type( event_name ) ~= "string" then
		error( "Expected string as 'event_name'", 2 )
	end

	--log( ":handle_and_return() called with '" .. event_name .. "'" )

	local event_args = { ... }

	local is_global = global_events[ event_name ]
	local loc_info = location_events[ event_name ]

	if loc_info then
		-- Offset the coordinates if they come from a 1-based system
		local offset = loc_info.one_based and 1 or 0

		-- loc_info is now a coord table, as defined in the coords param description of :handle_internal()
		loc_info = {
			x = event_args[ loc_info.x ] - offset;
			y = event_args[ loc_info.y ] - offset;
			selects = loc_info.selects;
		}
	end

	self:handle_internal( event_name, event_args, is_global, loc_info and loc_info.selects, loc_info, {}, {}, 0, self, true )

	return event_name, event_args
end

--- An internal helper method for non-recursive handling of events.
-- @param event_name		The name of the event, such as 'mouse_click'
-- @param event_args		An array of the event's arguments
-- @param is_global			Whether the event is global
-- @param selects			Whether the event can select an element
-- @param loc_info			Location information for the current element, like a coord table (see the coords param)
-- @param etw				An array of elements to wake (pass :handle_internal control to)
-- @param coords			An array synced with etw containing tables with local coordinates for the etw element
--							at the same index. #etw == #coords at all times, coord tables are structured like
--							{ x = number; y = number; one_based = location_events[ event_name ].one_based }
-- @param n_etw				Length of etw (and therefore also of coords), for performance speed ups
-- @param obj_to_return		The object to return once all elements have finished handle jobs
-- @param local_only		If true, the event won't be propagated to child elements
-- @return Tail call of event_handler:handle_internal or obj_to_return
function handler_methods:handle_internal( event_name, event_args, is_global, selects, loc_info, etw, coords, n_etw, obj_to_return, local_only )
	--local name = tostring( self.name )
	--log( "Starting :handle_internal() for " .. name )

	-- Handle the event locally
	local x1 = self.x1
	local y1 = self.y1

	local x_pos, y_pos

	if loc_info then
		local x, y = loc_info.x, loc_info.y

		if x and y then
			x_pos = x - x1
			y_pos = y - y1

			coord_info = {
				x = x_pos;
				y = y_pos;
			}
		end
	end

	-- Parent should do the callback earlier than child
	-- Note that we do not care what the event is, so
	-- local custom events get handled as well
	--TODO: pcall?
	local fn = self.callbacks[ event_name ]
	if fn then
		fn( unpack( event_args ) )
	end

	if not local_only and self.family_callbacks[ event_name ] then
		--log( "\t✓ Has callbacks" )

		local x2 = self.x2
		local y2 = self.y2
		local selected = self.selected

		if is_global or x_pos then
			local not_global_and_selects = not is_global and selects
			local last_selected = selected
			local no_match = true

			-- Add our affected children to the elements to wake table
			for i, child in ipairs( self.children ) do
				--log( "\t\tChecking child " .. tostring( child.name ) )
				--log( "\t\t\tx_pos = " .. tostring( x_pos ) .. "; y_pos = " .. tostring( y_pos ) .. ";" )

				if  is_global
				    or ( x_pos
				         and x_pos >= child.x1 and x_pos <= child.x2
				         and y_pos >= child.y1 and y_pos <= child.y2 )
				then
					no_match = false

					n_etw = n_etw + 1
					etw[ n_etw ] = child
					coords[ n_etw ] = coord_info

					--log( "\t\t✓ Added to etw" )

					if not_global_and_selects then
						self.selected = child
						selected = child
						child:handle_local_and_return( "on_select", event_name )
					end
				end
			end

			if not_global_and_selects and last_selected and ( selected ~= last_selected or no_match ) then
				last_selected:handle_local_and_return( "on_deselect", event_name )
			end
		end
	end

	if n_etw == 0 then
		-- All elements have been handled
		--log( "\tNo more elements to wake, returning" )
		return obj_to_return

	else
		-- Handle the next element in the queue
		--log( "\t✓ Done, passing control" )
		return remove( etw, 1 )
			:handle_internal(
				event_name,
				event_args,
				is_global,
				selects,
				remove( coords, 1 ),
				etw,
				coords,
				n_etw - 1,
				obj_to_return,
				local_only
			)
	end
end

--- Handle an event and return self for method chaining.
-- @param ...	Arguments passed to self:handle_and_return()
-- @return self
function handler_methods:handle( ... )
	self:handle_and_return( ... )
	return self
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

	-- Also add the child's children's callbacks
	for event_name, _ in pairs( child.family_callbacks ) do
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
	rawset( self.callbacks, event_name, fn )

	local parent = self.parent

	while parent do
		parent.family_callbacks[ event_name ] = true
		parent = parent.parent
	end

	return self, previous_value
end

--- Stop listening for an event.
--	Note: This method does not update
--	parents' family_callbacks table, which
--	makes the hierarchy less efficient.
-- @param event_name	description
-- @return self, callback function
function handler_methods:remove_callback( event_name )
	local fn = self.callbacks[ event_name ]

	if not fn then
		return self
	end

	rawset( self.callbacks, event_name, nil )

	return self, fn
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
	n.callbacks = { [ owner ] = n }

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

	n.callbacks = setmetatable( n.callbacks, handler_callbacks_metatable )

	-- Metadata
	n.__type = "handler"

	return n
end

--- An alias for event_handler:handle().
--	Should be avoided for best performance.
-- @param ...	The arguments passed to :handle()
-- @return Tail call of event_handler:handle()
-- @see handler_methods:handle
function handler_metatable:__call( ... )
	return self:handle( ... )
end

--- An alias for event_handler:register_callback().
--	Should be avoided for best performance.
-- @param ...	The arguments passed to :register_callback()
-- @return Tail call of event_handler:register_callback()
-- @see handler_methods:register_callback
function handler_callbacks_metatable:__newindex( ... )
	return self[ owner ]:register_callback( ... )
end

return handler
