-- Copyright (C) Anton heryanto.

local split = require "resty.stack.utils".split

local popen = io.popen
local concat = table.concat
local sub = string.sub
local gsub = string.gsub
local templates = ngx.shared.templates
local capture = ngx.location.capture
local say = ngx.print
local var = ngx.var
local log = ngx.log

local ok, config = pcall(require, "config")
if not ok then 
  log(ngx.WARN, 'config.lua fail to load')
  config = {} 
end

local function cmd_unix(path, ext)
  local cmd = 'find '.. path ..' -name "*.'.. ext ..'"'
  local i = 0 -- avoid ifinite loop
  local result
  while true do
    local handler,err = popen(cmd)
    if err or handler == nil then 
      log(ngx.WARN, "handler invalid ", err) 
      break 
    end

    result = handler:read('*a')
    handler:close()
    if result or i == 100 then break end
    log(ngx.INFO, "result empty ", i)
    i = i + 1
  end
  
  return result
end

local function cmd_windows(path, ext)
  local dir = concat(split(path,'/'),'\\')
  local cmd = 'forfiles /p '.. dir ..' /s /m *.'.. ext ..
    ' /c "cmd /c echo @relpath"'
  local i, raw = 0

  while true do
    local handler = popen(cmd)
    raws = handler:read('*a')
    handler:close()
    if raw or i == 100 then break end
    i = i + 1
  end

  local files = split(raws,'\n')
  local result = ''
  for i=1,#files do
    local file = files[i]
    if file ~= "" then
      result = result .. path ..'/'.. 
        concat(split(sub(file,4,-2),'\\'),'/') ..'\n'
    end
  end
  return result
end

local cmd = cmd_unix
if ok and config.is_windows then cmd = cmd_windows end

local function combine(name, path, base, ext, fn, fn_after)
  local result = cmd(path, ext or "js")

  if not result then
    log(ngx.WARN, "popen failed, load from cache ", name)
    say("console.warn('".. name .." loaded from cache');")
    return
  end

  fn = fn or function(file, uri, body) return body end
  local files = split(result,'\n')
  local n = #files
  local strip = base and base:len() + 1 or nil
  local output = ''
  for i=1,n do
    local file = files[i]
    if file ~= "" then
      local uri = strip and sub(file,strip) or '/'.. file
      local res = capture(uri)
      if res.status == 200 then
        output = output .. fn(file, uri, res.body)
      end
    end
  end
  output = fn_after and fn_after(output) or output
  say(output)
end

local function html2js(name, path, base)
  combine(name, path, base, 'html', function(file, uri, body)
    local len = path:len() + 2
    return "  '".. sub(file,len,-6) .."':'".. gsub(body,'%s+',' ') .."',\n"
  end, function(o)
    return 'window.templates = {\n'.. o .. '};'
  end)
end

local path = var.arg_path or 'app'
local base = not var.arg_path and 'app' or nil 

-- templates 
html2js(path..'_templates.js',path ..'/views', base)
-- js
combine(path.. '.js', path ..'/presenters', base)


