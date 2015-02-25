-- Copyright (C) Anton heryanto.

local new_tab = require "table.new"
local cjson = require "cjson"
local utils = require "resty.stack.utils"
local get_post = require "resty.stack.post".get

local encode = cjson.encode
local get_redis = utils.get_redis
local keep_redis = utils.keep_redis
local split = utils.split
local setmetatable = setmetatable
local pairs = pairs
local type = type
local tonumber = tonumber
local sub = string.sub
local lower = string.lower
local len = string.len
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

local _M = new_tab(0, 5)

_M.VERSION = "0.1.0"
_M.services = {}
_M.index = 'index'

function _M.module(modules)
    -- module 'string', 'function', 'table', sub { 'string', 'function', 'table' }
    for k,v in pairs(modules) do
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
                _M.use(spath,sfn)
            end
        else
            if key_type == 'number' then k = v end 
            _M.use(k, v)
        end
    end
end

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

    _M.services[path] = o
end

function _M.run(param)
    local header = ngx.header
    header['Access-Control-Allow-Origin'] = '*'
    param = param or {}
    param.base = param.base or '/'
    param.base_length = len(param.base) + 1
    param.services = _M.services
    local res = _M.load(param)
    ngx.status = res.status

    local output = res.body
    if not output then output = null end
    if type(output) == 'table' then output = encode(output) end

    -- get service
    print(output)
end

local not_found = { status = 404, body = { errors = {"page not found"} } }
local not_authorize = { status = 401, body = { errors = {"Authentication required"} } }
function _M.load(param, path)
    local path = path or sub(var.uri, param.base_length)
    local uri = split(path, '/', 3)
    local p = param or {}
    local services = p.services
    if not services then return not_found end 
    
    -- implement home module
    local home = param.home or 'index'
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
    local get_user_id = services.auth and services.auth.get_user_id
    local method = var.request_method
    p.arg = req.get_uri_args()
    p.get_user_id = get_user_id
    if action and tonumber(action) then
        p.arg.id = action
        action = nil
    end

    if not action then 
        p.index = service.index or index
        action = "index" 
    end

    p.m = (method == "POST" or method == "PUT") and get_post(service) or nil 

    if param.debug then 
        log(WARN, 'load service ', module, ' with request ', method, ' and action ', action) 
    end

    local mt = { __index = service }
    local c = setmetatable(p, mt)

    local handler = c[action]

    if handler == nil then return not_found end
    -- validate authorization
    if service.AUTHORIZE then
        if not get_user_id then return not_authorize end
        get_user_id(c) 
    end

    return { status = 200, body = handler(p) }
end

return _M

