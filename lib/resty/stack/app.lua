-- Copyright (C) Anton heryanto.

local new_tab = new_tab
local type = type
local tonumber = tonumber
local sub = string.sub
local ngx = ngx
local var = ngx.var
local req = ngx.req
local null = ngx.null
local exit = ngx.exit
local get_post =  post.get
local get_redis = utils.get_redis
local keep_redis = utils.keep_redis
local split = utils.split
local config = require "resty.stack.config"

local function get_user_id(self)
  if self.IS_PUBLIC then return end
  
  local auth = var.cookie_auth
  if not auth then return exit(401) end
  
  self.user_id = self.r:hget("user:auth", auth)
  if self.user_id == null then return exit(401) end
  
  self.user_key = "user:".. self.user_id
  self.is_admin =  self.r:hget(self.user_key, "is_admin") == "1"
end

local function index(self)
  local method = var.request_method
  local output 
  if method == "POST" then
    self.m = get_post(self)
    output = self.save(self)
  else
    if self.arg.id then
      if method == "DELETE" or self.arg.method == "DELETE" then
        output = self.delete(self)
      else
        output = self.get(self) or '{}'
      end
    else
      output = self.all(self) or '[]'
    end
  end
  return output
end

local _M = new_tab(0, 2)

function _M.run()
  local r = get_redis(config.redis)
  -- get service
  local output = _M.load(r)
  
  if not output then 
    output = "null"
  elseif type(output) == "table" then
    output = cjson.encode(output)
  end

  local header = ngx.header
  header['Access-Control-Allow-Origin'] = '*'
  ngx.say(output)

  keep_redis(r, config.redis)

end

function _M.load(r,path)
  local path = path or sub(var.uri, config.base_length)
  local uri = split(path, '/', 3)
  local err = { error = "page not found" }
  local services = config.services
  
  local p = new_tab(0,3)
  p.index = index
  p.r = r
  p.arg = req.get_uri_args()

  local module = uri[1]
  local service = services[module]
  local method = uri[2] ~= "" and uri[2]
  
  if not service then
    if not method or tonumber(method) then return err end
    service = services[module ..".".. method]
    if not service then return err end
    method = uri[3] ~= "" and uri[3]
  end

  if method and tonumber(method) then
    p.arg.id = method
    method = nil
  end
  
  if not method then method = "index" end
  
  local c = service:new(p)
  if not c then return err end

  local handler = c[method]

  -- if method not found check sub module
  if handler == nil then return err end
 
  -- validate authorization
  get_user_id(c)
  
  return handler(c)

end

return _M

