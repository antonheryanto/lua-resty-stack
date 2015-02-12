-- Copyright (C) Anton heryanto.

local ngx = ngx
local var = ngx.var
local get_headers = ngx.req.get_headers
local null = ngx.null
local exit = ngx.exit
local log = ngx.log
local ERR = ngx.ERR
local floor = math.floor
local find = string.find
local len = string.len
local sub = string.sub
local new_tab = require "table.new"
local redis = require "resty.redis"
local concat = table.concat
local type = type

local _M = new_tab(0, 5)

local smallwords = {
  a=1, ["and"]=1, as=1, at=1, but=1, by=1, en=1, ["for"]=1, ["if"]=1,
  ["in"]=1, of=1, the=1, to=1, vs=1, ["vs."]=1, v=1, ["v."]=1, via=1
}

function _M.titlecase(title)
  title = title:lower()
  return string.gsub(title, "()([%w&`'''\".@:/{%(%[<>_]+)(-? *)()",
    function(index, nonspace, space, endpos)
      local low = nonspace:lower();
      if (index > 1) and (title:sub(index-2,index-2) ~= ':')
            and (endpos < #title) and smallwords[low] then
        return low .. space;
      elseif title:sub(index-1, index+1):match("['\"_{%(%[]/)") then
        return nonspace:sub(1,1) .. nonspace:sub(2,2):upper()
           .. nonspace:sub(3) .. space;
      elseif nonspace:sub(2):match("[A-Z&]")
            or nonspace:sub(2):match("%w[%._]%w") then
        return nonspace .. space;
      end
      return nonspace:sub(1,1):upper() .. nonspace:sub(2) .. space;
    end);
end


function _M.trim(self)
    if not self or type(self) ~= "string" then return end
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end

function _M.split(self, delimiter, limit)
    if not self or type(self) ~= "string" then return end
    local length = len(self)

    if length == 1 then return {self} end

    local result = limit and new_tab(limit, 0) or {}
    local index, n = 0, 1

    while true do
        if limit and n > limit then break end

        local pos = find(self,delimiter,index,true) -- find the next d in the string
        if pos ~= nil then -- if "not not" found then..
            result[n] = sub(self,index, pos - 1) -- Save it in our array.
            index = pos + 1 -- save just after where we found it for searching next time.

        else
            result[n] = sub(self,index) -- Save what's left in our array.
            break -- Break at end, as it should be, according to the lua manual.

        end
        n = n + 1

    end

    return result
end

function _M.get_redis(conf)
    conf = conf or {}
    local config = {
        host = conf.host or "127.0.0.1",
        port = conf.port or 6379,
        timeout = conf.timeout or 1000,
        keep_size = conf.keep_size or 1024,
        keep_idle = conf.keep_idle or 0
    } 

    local r = redis:new()

    local ok,err = r:connect(config.host, config.port)

    r:set_timeout(config.timeout)

    if not ok then 
        local message = "failed connect to redis with message : ".. err
        log(ERR, message)
        return
    end

    -- add method to redis
    function r.key(r, ...)
        return concat({...},':')
    end

    function r.hash_get(r, key, ...)
        local args = {...}
        local fields = #args == 1 and type(args[1]) == 'table' and args[1] or args
        local n = #fields
        local m = new_tab(0, n)
        local data = r:hmget(key,unpack(fields)) 
        for i=1,n do
            local k = fields[i]
            local v = data[i]
            if v ~= null then m[k] = v end
        end
        return m
    end

    function r.hash_save(r, key, data, fields, n)
        n = n or #fields
        for i=1,n do
            local k = fields[i]
            local v = data[k]
            if v and v ~= '' then r:hset(key, k, v) end
        end
    end

    return r, config
end

function _M.keep_redis(redis, config)
    if not redis then return end
    local ok,err = redis:set_keepalive(config.keep_idle or 0, config.keep_size or 1024)
    if not ok then 
        local message = "failed to keepalive with message : ".. err
        log(ERR, message)
    end
end

function _M.validates(model, properties)
    if not model or not properties then return {'data is empty'} end

    local n = #properties
    if n == 0 then return end

    local errors, ne = new_tab(n,0), 1
    for i=1,n do
        local p = properties[i]
        local v = model[p]
        if not v or v == '' then
            errors[ne] = p .." is required"
            ne = ne + 1
        end
    end
    return errors

end

return _M
