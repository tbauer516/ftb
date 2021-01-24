local args = { ... }
if (#args ~= 1) then
  print("usage: blacklist <name of new blacklist>")
  error()
end

local blacklist = {}
local blackliststring = "{"

if (not fs.exists("blacklist/")) then
  fs.makeDir("blacklist/")
end

if (fs.exists("blacklist/" .. args[1] .. ".blist")) then
  local handle = fs.open("blacklist/" .. args[1] .. ".blist", "r")
  local blacklistText = handle.readAll()
  local blacklistbyindex = textutils.unserialize(blacklistText)
  handle.close()
  for k,v in pairs(blacklistbyindex) do
    blacklist[v] = 1
  end
end


for i = 1, 16 do
  if (turtle.getItemCount(i) > 0) then
    local data = turtle.getItemDetail(i)
    blacklist[data["name"]] = 1
    -- blacklist[#blacklist + 1] = data["name"]
  end
end

for k,v in pairs(blacklist) do
  blackliststring = blackliststring .. "\"" .. k .. "\","
end
blackliststring = blackliststring .. "}"

local handle = fs.open("blacklist/" .. args[1] .. ".blist", "w")
handle.write(blackliststring)
handle.close()