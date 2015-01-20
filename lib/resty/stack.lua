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
local auth = services.auth and services.auth.get_user_id
local use = config.use
local home = config.index
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
  local method = self.arg.method or var.request_method
  local action = self[lower(method)]
  if not action and (method == "POST" or method == "PUT") then action = self.save end
  return action and action(self)
end

local _M = new_tab(0, 4)

_M.VERSION = "0.1.0"

function _M.use(path, fn)
  local k,v = use(path,fn)
  services[k] = v
end

function _M.run()
  local header = ngx.header
  header['Access-Control-Allow-Origin'] = '*'
  local redis = get_redis(config.redis)
  local res = _M.load(redis)
  ngx.status = res.status
  
  local output = res.body
  if not output then output = null end
  if type(output) == 'table' then output = encode(output) end

  -- get service
  print(output)

  if redis then keep_redis(redis, config.redis) end
end

local not_found = { status = 404, body = { errors = {"page not found"} } }
local not_authorize = { status = 401, body = { errors = {"Authentication required"} } }
function _M.load(redis,path)
  local path = path or sub(var.uri, config.base_length)
  local uri = split(path, '/', 3)

  -- implement home module
  local module = (uri[1] == "" and services[home]) and home or uri[1]
  local action = uri[2] ~= "" and uri[2]
  local service = services[module]
  
  if not service then
    if not action then
      if not services[module ..".".. home] then return not_found end
      action = home
    elseif tonumber(action) then return not_found end
    service = services[module ..".".. action]
    if not service then return not_found end
    action = uri[3] ~= "" and uri[3]
  end

  -- attach to module
  local method = var.request_method
  local p = new_tab(0,7)
  p.r = redis
  p.arg = req.get_uri_args()
  p.get_user_id = _M.get_user_id
  p.services = services
  p.conf = config.conf
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
  if service.AUTHORIZE then
    if not auth then return not_authorize end
    services.auth.get_user_id(c) 
  end

  return { status = 200, body = handler(p) }
end

return _M

