
local path = fs.getDir( shell.getRunningProgram and shell.getRunningProgram() or shell.dir() )
require = dofile( fs.combine( path, "require.lua" ) )
