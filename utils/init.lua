
-- Desktox utility functions
local utils = {}

local floor = math.floor

--- Get the maximum value out of a and b.
--	Unlike math.max, only supports 2 arguments,
--	but returns the second-in-value number as
--	the second value.
-- @param a	The first number to compare
-- @param b	The second number to compare
-- @return a and b, whichever is greater in value goes first.
function utils.max( a, b )
	if a > b then
		return a, b
	end

	return b, a
end

--- Rounds a number to a set amount of decimal places.
-- @param n			The number to round
-- @param places 	The number of decimal places to keep
-- @return The result
function utils.round( n, places )
	local mult = 10 ^ ( places or 0 )
	return floor( n * mult + 0.5 ) / mult
end

--- Open a file for logging.
-- @param path	description
-- @return A log() function which, when called, appends its arguments to the open log file,
--         and another function which, when called, closes the file handle
function utils.open_log_file( path )
	local file = io.open( path, "a" )
	local tconcat = table.concat

	return function( ... )
		file:write( tconcat( { ... }, ";" ) .. "\n" )
		file:flush()
	end, function()
		file:close()
	end
end

return utils
