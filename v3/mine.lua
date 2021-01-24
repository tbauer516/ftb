package.loaded.t = nil
package.loaded.quarry = nil
local t = require("lib/t"):new()
local quarry = require("lib/quarry")

--## Variables ## --

local args = { ... }
if (#args < 2 or #args > 3) then
  print("usage: mine <length> <width> [<alternate blacklist name>]")
  error()
end

--## Main Runtime ##--

t.cruiseAltitude = 1
quarry = quarry:new(t, tonumber(args[1]), tonumber(args[2]), args[3])
quarry:start()