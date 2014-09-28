-- Copyright (C) Anton heryanto.

local setmetatable = setmetatable
local ngx = ngx
local var = ngx.var
local null = ngx.null
local md5 = ngx.md5
local time = ngx.time
local cookie_time = ngx.cookie_time
local user = require "user"
local new_tab = require "table.new"
local get_post = require "resty.stack.post".get

local _M = new_tab(0,4)
local mt = { __index = _M }

_M.IS_PUBLIC = true

function _M.new(self, p)
  p.index = self.login
  return setmetatable(p, mt)
end

function _M.user_data(self, id)
  local r, u = self.r, {id = id} 

  if user.data then
    u = user.data({r = r }, id)
  end
  
  return u
end

function _M.login(self)
  local auth, r = var.cookie_auth, self.r

  if auth then -- check cookie auth if id exist
    local id = r:hget("user:auth", auth)
    if id ~= null and auth == r:hget("user:".. id, "auth") then
      return _M.user_data(self, id)
    end
  end

  local m = var.request_method == "GET" and self.arg or get_post(self)
  if not m.name or not m.password then
    return { errors = {"please provide username and password" }}
  end

  local password = "password"
  local property = m.name:find("@") and "email" or "name"
  local id = r:hget("user:".. property, m.name)
  local no_id = { errors = {"email or password is incorrect " }}
  
  if id == null then return no_id end

  local user_key = "user:".. id
  local u = r:hmget(user_key, "password", "auth")
  
  if (u[1] ~= null and md5(m.password) ~= u[1]) or (u[1] == null and m.password ~= password) then
    return no_id
  end

  auth = u[2]

  if auth == null then
    auth = md5(time() .. m.name)
    r:hset(user_key, "auth", auth)
  end

  r:hset("user:auth", auth, id)

  local header = ngx.header
  local expires = 3600 * 24 -- 1 day
  header["Set-Cookie"] = "auth=" .. auth .. ";Expires=" .. cookie_time(time() + expires)

  return _M.user_data(self, id)
end

function _M.logout(self)
  local r, auth = self.r, ngx.var.cookie_auth
  if not auth then return end

  local key = "user:auth"
  local id = r:hget(key, auth)
  if id == null then 
    return r:hdel(key, auth) 
  end

  local user_auth = md5(time())
  r:hdel(key, auth)
  r:hset("user:".. id, "auth", user_auth)
end

return _M
