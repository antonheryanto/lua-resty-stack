-- Copyright (C) Anton heryanto.

local ngx = ngx
local var = ngx.var
local get_headers = ngx.req.get_headers
local null = ngx.null
local exit = ngx.exit
local floor = math.floor
local find = string.find
local len = string.len
local sub = string.sub
local new_tab = require "table.new"
local redis = require "resty.redis"
local concat = table.concat

local _M = new_tab(0, 5)

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

function _M.get_redis(config)
  if not config then return end

  local r = redis:new()
  
  local ok,err = r:connect(config.host, config.port)
  
  r:set_timeout(config.timeout)
  
  if not ok then 
    local message = "failed connect to redis with message : ".. err
    ngx.log(ngx.ERR, message)
    ngx.say("{error:".. message .."}")
    return
  end
  
  -- add method to redis
  function r.key(r, ...)
    return concat({...},':')
  end

  function r.hash_save(r, key, data, fields, number_of_field)
    --if not key or not data or not fields then return end

    number_of_field = number_of_field or #fields
    for i=1,number_of_field do
      local k = fields[i]
      local v = data[k]
      if v and v ~= '' then r:hset(key, k, v) end
    end
  end
  
  return r, config
end

function _M.keep_redis(r, config)
  local ok,err = r:set_keepalive(config.keep_idle, config.keep_size)
  if not ok then 
    local message = "failed to keepalive with message : ".. err
    ngx.log(ngx.ERR, message)
    ngx.say("{error:".. message .."}")
  end
end

function _M.validates(model, properties)
  if not model or not properties then return end

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
