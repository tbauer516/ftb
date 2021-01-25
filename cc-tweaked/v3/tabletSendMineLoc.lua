local n = require("lib/networking"):new()

--## Main Runtime ##--

while true do
  term.clear()
  term.setCursorPos(1,1)
  term.write("Waiting for server request")
  n:waitToSendAvailability()
  n:sendCoords()
end