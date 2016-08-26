
local args = { ... }
local old_term = term.current()

local directory = fs.getDir( shell.getRunningProgram() )
local path = fs.combine( directory, args[ 1 ] )

print( "Opening", path )

local f = io.open( path, "r" )

if not f then
	error( "Failed to open file " .. path, 0 )
end

local contents = f:read( "*a" )
f:close()

local fn, err = loadstring( contents, args[ 1 ] )
if not fn then
	error( err, 0 )
end

setfenv( fn, getfenv() )

local ok, err = pcall( fn, ... )

if not ok then
	term.redirect( old_term )
	term.setCursorPos( 1, 1 )
	error( err, 0 )
end
