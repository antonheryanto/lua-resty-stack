-- Copyright (C) Anton heryanto.

local split = require "resty.stack.string".split
local type = type
local open = io.open
local popen = io.popen
local concat = table.concat
local sub = string.sub
local gsub = string.gsub
local len = string.len
local print = ngx.print
local log = ngx.log
local WARN = ngx.WARN
local req = ngx.req
local prefix = ngx.config.prefix
local root = prefix() .. '../'

local function concat_file(path, ext, fn, fn_after)
    local cmd = 'find '.. path ..' -name "*.'.. ext ..'"'
    local i = 0 -- avoid ifinite loop
    local output = ''
    local start = len(path) + 2
    local stop = -2 - len(ext)
    while true do
        local handler,err = popen(cmd)
        if err or handler == nil then 
            log(WARN, "handler invalid ", err) 
            break 
        end

        local total = 0
        local success = 0
        for file in handler:lines() do
            total = total + 1
            local h,e = open(file,'r')
            local o = h:read("*all")
            h:close()
            if not h or e then break end

            local name = sub(file,start,stop)
            output = output .. (fn and fn(name, o) or o)
            success = success + 1
        end
        handler:close()
        if total == success or i == 100 then break end
        log(WARN, "result empty ", i)
        i = i + 1
    end
    output = fn_after and fn_after(output) or output
    print(output)
end

local args = req.get_uri_args()
local path = root .. (args.path or 'app') ..'/'
local base = not args.path and 'app' or nil 
local html = not args.html and 'views' or type(args.html) == 'table' and args.html[1] or args.html
local js = not args.js and {'presenters'} or type(args.js) ~= 'table' and {args.js} or args.js


for i=1,#js do concat_file(path.. js[i], 'js') end
-- template
concat_file(path .. html, 'html', function(name, value) 
    return "  '".. name .."':'".. gsub(value,'%s+',' ') .."',\n"
end, function(o) 
    return 'window.templates = {\n'.. o .. '};\n'
end)

