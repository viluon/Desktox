
local path = fs.getDir( shell.getRunningProgram() or shell.getDir() )
require = dofile( fs.combine( path, "require.lua" ) )
