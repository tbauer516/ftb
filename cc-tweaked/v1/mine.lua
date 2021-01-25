package.loaded.t = nil
package.loaded.quarry = nil
local t = require("lib/t"):new()
local quarry = require("lib/quarry")

--## Variables ## --

local args = { ... }
if (#args < 2 or #args > 3) then
  print("Mines a rectangle moving forward <length> and to the right <width> from the starting position.")
  print("Place turtle down, fill slot 16 with coal, slot 15 with cobble.")
  print("If no blacklist is provided, then the default will be used if it exists.")
  print("usage: mine <length> <width> [<alternate blacklist name>]")
  error()
end

--## Main Runtime ##--

quarry = quarry:new(t, tonumber(args[1]), tonumber(args[2]), args[3])
quarry:start()