
local round  = require( "desktox-utils" ).round

local string = string
local math   = math

local rep = string.rep
local max = math.max

local text = {}

--- Wrap text to the given maximum length.
-- @param txt		The text to wrap
-- @param length	The maximum length of a single line
-- @return Table of lines
function text.wrap( txt, length )
	local lines

	if txt:find( "\n" ) then
		-- Deal with newlines
		lines = {}

		for line in ( txt .. "\n" ):gmatch( "(.-)\n" ) do
			-- Wrap each *original* line separately and combine them
			for i, l in ipairs( text.wrap( line, length ) ) do
				lines[ #lines + 1 ] = l
			end
		end
	else
		-- No newlines found, wrap the text
		lines = { "" }

		for word in txt:gmatch( "(%S+)" ) do
			if #word > length then
				-- Word exceeds line length
				local current_pos = 1

				while current_pos < #word do
					-- Split the word into pieces of the maximum length and save them as new lines
					lines[ #lines + 1 ] = word:sub( current_pos, current_pos + length - 1 )
					current_pos = current_pos + length
				end

			elseif #lines[ #lines ] + #word <= length then
				-- The word still fits on this line
				lines[ #lines ] = lines[ #lines ] .. word .. " "

			else
				-- Neither of the 2 cases above, start a new line
				lines[ #lines + 1 ] = word .. " "
			end
		end
	end

	return lines
end

--- Align text on a line to the left (append spaces).
-- @param txt			The text to align
-- @param line_width	The width of the line
-- @param character		(Optional) The character to append at the line's end, defaults to space
-- @return The aligned text
function text.align_left( txt, line_width, character )
	return txt .. rep( character or " ", max( 0, line_width - #txt ) )
end

--- Align text on a line to the right (prepend with spaces).
-- @param txt			The text to align
-- @param line_width	The width of the line
-- @param character		(Optional) The character to prepend the line with, defaults to space
-- @return The aligned text
function text.align_right( txt, line_width, character )
	return rep( character or " ", max( 0, line_width - #txt ) ) .. txt
end

--- Align text on a line to the centre (prepend with spaces).
-- @param txt			The text to align
-- @param line_width	The width of the line
-- @param character		(Optional) The character to prepend the line with, defaults to space
-- @return The aligned text
function text.align_centre( txt, line_width, character )
	return rep( character or " ", max( 0, round( line_width / 2 - #txt / 2 ) ) ) .. txt
end

return text
