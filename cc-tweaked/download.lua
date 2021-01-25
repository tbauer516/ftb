local version = "v5"

local makeCallDir
local navigateTreeJSON

makeCallDir = function(dir)
  local req = {
    url = "https://api.github.com/repos/tbauer516/ftb/contents/cc-tweaked/" .. version,
    method = "GET",
    headers = {
      Accept = "application/vnd.github.v3+json",
    },
  }

  if (dir ~= "") then
    req.url = req.url .. "/" .. dir
  end
  -- print("Making call to:")
  -- print(req.url)
  local res = http.request(req)
  local result = nil
  while true do
    result = {os.pullEvent()}
    if (result[1] == "http_success") then
      break
    elseif (result[1] == "http_failure") then
      local h = fs.open("error_log", "a")
      h.write(result[3])
      h.writeLine("")
      h.close()
    end
  end
  local json = result[3].readAll()
  result[3].close()
  return json
end

navigateTreeJSON = function(text, dir)
  fs.makeDir(dir)

  local resObj = textutils.unserializeJSON(text)

  for i,v in ipairs(resObj) do
    if (v.type == "dir") then
      local prefix = ""
      if (dir ~= "") then
        prefix = dir .. "/"
      end
      navigateTreeJSON(makeCallDir(prefix .. v.name), prefix .. v.name)
    elseif(v.type == "file") then
      shell.run("wget", v.download_url)
      if (dir ~= "") then
        fs.move(v.name, dir .. "/" .. v.name)
      end
    end
  end
end

local baseRequest = {
  url = "<string>",
  method = "GET",
  body = "<string>",
  headers = {
    Accept = "application/vnd.github.v3+json",
  },
}

--## Main Runtime ##--

term.clear()
term.setCursorPos(1,1)
navigateTreeJSON(makeCallDir(""), "")

if (pocket) then
  fs.move("TABLET/*", "/")
elseif (turtle) then
  fs.move("TURTLE/*", "/")
else
  fs.move("COMPUTER/*", "/")
end
fs.delete("TABLET")
fs.delete("TURTLE")
fs.delete("COMPUTER")
