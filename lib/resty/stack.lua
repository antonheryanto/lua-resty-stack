-- Copyright (C) Anton heryanto.

local new_tab = require "table.new"
local cjson = require "cjson"
local utils = require "resty.stack.utils"
local config = require "resty.stack.config"
local get_post = require "resty.stack.post".get

local encode = cjson.encode
local get_redis = utils.get_redis
local keep_redis = utils.keep_redis
local split = utils.split
local services = config.services
local type = type
local tonumber = tonumber
local sub = string.sub
local lower = string.lower
local ngx = ngx
local var = ngx.var
local req = ngx.req
local null = ngx.null
local print = ngx.print
local exit = ngx.exit
local log = ngx.log
local WARN = ngx.WARN

-- module index action 
local function index(self)
  local method = var.request_method or self.arg.method
  local action = self[lower(method)]
  if not action and (method == "POST" or method == "PUT") then action = self.save end
  return action and action(self)
end

local _M = new_tab(0, 3)

_M.get_user_id = services.auth and services.auth.get_user_id

function _M.run()
  local r = get_redis(config.redis)
  local header = ngx.header
  header['Access-Control-Allow-Origin'] = '*'
  local res = _M.load(r)
  ngx.status = res.status
  
  local output = res.body
  if not output then output = null end
  if type(output) == 'table' then output = encode(output) end

  -- get service
  print(output)

  keep_redis(r, config.redis)
end

local not_found = { status = 404, body = { errors = {"page not found"} } }
function _M.load(r,path)
  local path = path or sub(var.uri, config.base_length)
  local uri = split(path, '/', 3)

  -- attach to module
  local method = var.request_method
  local p = new_tab(0,7)
  p.r = r
  p.arg = req.get_uri_args()
  p.get_user_id = _M.get_user_id
  p.services = services
  p.conf = config.conf

  local module = uri[1]
  local service = services[module]
  local action = uri[2] ~= "" and uri[2]
  
  if not service then
    if not action or tonumber(action) then return not_found end
    service = services[module ..".".. action]
    if not service then return not_found end
    action = uri[3] ~= "" and uri[3]
  end

  if action and tonumber(action) then
    p.arg.id = action
    action = nil
  end
  
  if not action then 
    p.index = service.index or index
    action = "index" 
  end
  
  if method == "POST" or method == "PUT" then 
    p.m = get_post(service) 
  end
  
  if config.debug then 
    log(WARN, 'load service ', module, ' with request ', method, ' and action ', action) 
  end

  local mt = { __index = service }
  local c = setmetatable(p, mt)

  local handler = c[action]

  if handler == nil then return not_found end
 
  -- validate authorization
  if not service.IS_PUBLIC then _M.get_user_id(c) end

  return { status = 200, body = handler(p) }
end

return _M

