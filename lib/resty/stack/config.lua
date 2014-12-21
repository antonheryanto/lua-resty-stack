-- Copyright (C) Anton heryanto.
local cjson = require "cjson"
local new_tab = require "table.new"
local type = type
local len = string.len
local sub = string.sub
local pairs = pairs
local log = ngx.log
local var = ngx.var
local ok, config = pcall(require, "config")
if not ok then 
  log(ngx.WARN, 'config.lua file fail to load, please check config.lua for error')
  config = {} 
end

local _M = new_tab(0,6)
_M.conf = config.conf or {}
_M.debug = config.debug
_M.base = config.base or "/"
_M.base_length = len(_M.base) + 1
_M.index = config.index or 'index'

local redis = config.redis
if redis then
  _M.redis = {
    host = redis.host or "127.0.0.1",
    port = redis.port or 6379,
    timeout = redis.timeout or 1000,
    keep_size = redis.keep_size or 1024,
    keep_idle = redis.keep_idle or 0
  }
end
_M.modules = config.modules or {}
_M.services = { }

function _M.use(path, fn)
  if not path then return end
  
  -- validate path
  local tp = type(path)
  if tp ~= 'string' then 
    fn = path
    path = sub(var.uri,2) or _M.index
  end
  
  -- validate fn
  if not fn then fn = require(path) end 
  local tf = type(fn)
  local o
  if tf == 'function' then
    o = { index = fn }
  elseif tf == 'table' then
    o = fn
  elseif tf == 'string' then
    o = require(fn)
  end

  return path, o
end

-- module 'string', 'function', 'table', sub { 'string', 'function', 'table' }
for k,v in pairs(_M.modules) do
  local key_type = type(k)
  if type(v) == "table" then
    for sk,sv in pairs(v) do
      local tsk = type(sk)
      if tsk == 'number' then sk = sv end 
      local spath = tsk == 'string' and k.."."..sk or k ..".".. _M.index
      local sfn = sv
      if type(sv) == 'string' then
        local ns = k ..".".. sk
        spath = ns
        sfn = ns
      end
      local path, fn = _M.use(spath,sfn)
      _M.services[path] = fn
    end
  else
    if key_type == 'number' then k = v end 
    local path, fn = _M.use(k, v)
    _M.services[path] = fn 
  end
end

return _M

