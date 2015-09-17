-- Copyright (C) 2014 - 2015 Anton heryanto.

local pcall = pcall
local setmetatable = setmetatable
local pairs = pairs
local type = type
local tonumber = tonumber
local sub = string.sub
local lower = string.lower
local len = string.len
local new_tab = require "table.new"
local cjson = require "cjson"
local split = require "resty.stack.string".split
local has_resty_post, resty_post = pcall(require, 'resty.post')
local ngx = ngx
local var = ngx.var
local req = ngx.req
local null = ngx.null
local print = ngx.print
local exit = ngx.exit
local log = ngx.log
local WARN = ngx.WARN
local read_body = ngx.req.read_body
local get_post_args = ngx.req.get_post_args
local get_uri_args = ngx.req.get_uri_args
local HTTP_OK = ngx.HTTP_OK
local HTTP_NOT_FOUND = ngx.HTTP_NOT_FOUND
local HTTP_UNAUTHORIZED = ngx.HTTP_UNAUTHORIZED
local INDEX = 'index'
local _M = new_tab(0, 9)
_M.VERSION = "0.1.1"

local mt = { __index = _M }
function _M.new(self, config)
    config = config or {}
    config.base = config.base or '/'
    config.base_length = len(config.base) + 1
    local post = has_resty_post and resty_post:new(config.upload_path)
    config.upload_path = config.upload_path or post and post.path
    return setmetatable({
        post = post,
        config = config,
        services = {}
    }, mt)
end

function _M.module(self, modules)
    if not modules then return end

    -- module 'string', 'function', 'table', sub { 'string', 'function', 'table' }
    for k,v in pairs(modules) do
        local key_type = type(k)
        if type(v) == "table" then
            for sk,sv in pairs(v) do
                local tsk = type(sk)
                if tsk == 'number' then sk = sv end 
                local spath = tsk == 'string' and k.."."..sk or k ..".".. INDEX
                local sfn = sv
                if type(sv) == 'string' then
                    local ns = k ..".".. sk
                    spath = ns
                    sfn = ns
                end
                self:use(spath,sfn)
            end
        else
            if key_type == 'number' then k = v end 
            self:use(k, v)
        end
    end
end

function _M.use(self, path, fn)
    if not path then return end

    -- validate path
    local tp = type(path)
    if tp ~= 'string' then 
        fn = path
        local uri = sub(var.uri, 2)
        path = len(uri) ~= 0 and uri or INDEX
    end

    -- validate fn
    if not fn then fn = require(path) end 
    local tf = type(fn)
    local o
    if tf == 'function' then
        o = { get = fn }
    elseif tf == 'table' then
        o = fn
    elseif tf == 'string' then
        o = require(fn)
    end

    self.services[path] = o
end

-- default header, override function to change
function _M.set_header()
    local header = ngx.header
    header['Access-Control-Allow-Origin'] = '*'
    header['Access-Control-Max-Age'] = 2520
    header['Access-Control-Allow-Methods'] = 'GET,POST,PUT,DELETE,HEAD,OPTIONS'
end

function _M.run(self)
    _M.set_header()

    local status, output = self:load()
    if status then
        ngx.status = status
    end

    if not output then 
        return
    end
    
    if type(output) == 'table' then 
        output = cjson.encode(output) 
    end

    print(output)
end

function _M.load(self, path)
    local services = self.services
    if not services then return HTTP_NOT_FOUND end 
    
    local config = self.config
    local path = path or sub(var.uri, config.base_length)
    local uri = split(path, '/', 4) -- limit to 4 level
    local module = (uri[1] == '' and services[INDEX]) and INDEX or uri[1]
    local action = uri[2] ~= '' and uri[2] or nil
    local extra = uri[3] ~= '' and uri[3] or nil
    local service = services[module]

    -- check sub modules
    if not service then
        if not action then
            if not services[module ..'.'.. INDEX] then 
                return HTTP_NOT_FOUND 
            end

            action = INDEX
        elseif tonumber(action) then 
            return HTTP_NOT_FOUND 
        end
        module = module ..'.'.. action
        service = services[module]

        if not service then 
            return HTTP_NOT_FOUND 
        end

        action = extra
        extra = uri[4] ~= '' and uri[4] or nil
    end

    -- parse route
    local arg = get_uri_args()
    local method = lower(arg.method or var.request_method)
    if action and tonumber(action) then
        arg.id = action
        action = extra
    end

    if not action then 
        if method == 'head' or method == 'options' then 
            return HTTP_OK
        end

        action = method
        if not service[action] and (method == 'post' or method == 'put') then
            action = 'save'
        end
    end

    if config.debug then 
        log(WARN, 'load service ', module, ' with request ',
            method, ' and action ', action) 
    end

    local handler = service[action]
    if not handler then
        return HTTP_NOT_FOUND
    end
    
    -- passing param to module
    local param = {
        config = config,
        services = services,
        arg = arg,
        method = method,
        action = action,
        module = module
    }
    -- validate authorization support at module and method level
    local validate_user = self.validate_user
    local auth = service.AUTHORIZES
    if validate_user and (service.AUTHORIZE or (auth and auth[action])) then
        validate_user(param)
    end
    
    -- process post/put data
    local post = self.post
    if method == 'post' or method == 'put' then
        if post then
            param.data = post:read()
        else
            read_body()
            param.data = get_post_args()
        end
    end

    local output, status = handler(param)
    return status, handler(param)
end

return _M

