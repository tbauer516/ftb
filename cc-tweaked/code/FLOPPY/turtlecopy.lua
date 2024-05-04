if (not turtle) then
  error()
end

shell.setDir("/")

local existing = fs.list("/")
for i, existingName in ipairs(existing) do
  if (not fs.isDir(existingName)) then
    fs.delete(existingName)
  end
end
fs.delete("ui")
fs.delete("lib")
fs.delete("blacklist")

local files = fs.list("disk/TURTLE")
for i, fileName in ipairs(files) do
  fs.copy("disk/TURTLE/" .. fileName, fileName)
end

fs.copy("disk/ui", "ui")
fs.copy("disk/lib", "lib")
fs.copy("disk/blacklist", "blacklist")