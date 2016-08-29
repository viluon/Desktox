
local buffer = require "desktox-buffer"

local w, h = term.getSize()
local terminal = term.current()

local main_buf   = buffer.new( 0, 0, w, h )
local layer1_buf = buffer.new( 2, 2, w - 4,  h - 4,  main_buf   ):clear( colours.lime,  colours.lightGrey, "X" )
local layer2_buf = buffer.new( 2, 2, w - 8,  h - 8,  layer1_buf ):clear( colours.black, -1,                "X" )
local layer3_buf = buffer.new( 2, 2, w - 12, h - 12, layer2_buf ):clear( colours.blue,  -2,                "X" )

layer3_buf:render()
layer2_buf:render()
layer1_buf:render()

main_buf:render_to_window( terminal )

--buffer.close_log()
