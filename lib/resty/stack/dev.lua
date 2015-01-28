-- Copyright (C) Anton heryanto.

local split = require "resty.stack.utils".split
local type = type
local popen = io.popen
local concat = table.concat
local sub = string.sub
local gsub = string.gsub
local capture = ngx.location.capture
local say = ngx.print
local var = ngx.var
local log = ngx.log
local req = ngx.req

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

local function combine(path, base, ext, fn, fn_after)
    local result = cmd(path, ext or "js")

    if not result then
        log(ngx.WARN, "popen failed ")
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

local function html2js(path, base)
    combine(path, base, 'html', function(file, uri, body)
        local len = path:len() + 2
        return "  '".. sub(file,len,-6) .."':'".. gsub(body,'%s+',' ') .."',\n"
    end, function(o)
    return 'window.templates = {\n'.. o .. '};\n'
end)
end


local args = req.get_uri_args()
local path = args.path or 'app/'
local base = not args.path and 'app' or nil 
local html = not args.html and 'views' or type(args.html) == 'table' and args.html[1] or args.html
local js = not args.js and {'presenters'} or type(args.js) ~= 'table' and {args.js} or args.js

--templates
html2js(path.. html, base) 
--js
for i=1,#js do 
    combine(path.. js[i], base) 
end
