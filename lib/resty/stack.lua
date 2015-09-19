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
local has_resty_post, resty_post = pcall(require, 'resty.post')
local ngx = ngx
local var = ngx.var
local req = ngx.req
local print = ngx.print
local log = ngx.log
local WARN = ngx.WARN
local read_body = ngx.req.read_body
local get_post_args = ngx.req.get_post_args
local get_uri_args = ngx.req.get_uri_args
local HTTP_OK = ngx.HTTP_OK
local HTTP_NOT_FOUND = ngx.HTTP_NOT_FOUND
local HTTP_UNAUTHORIZED = ngx.HTTP_UNAUTHORIZED
local re_find = ngx.re.find
local REST = {get = true, post = true, put = true, delete = true, save = true}
local _M = new_tab(0, 9)
_M.VERSION = "0.2.0"

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
        paths = {},
        services = {}
    }, mt)
end

function _M.module(self, modules)
    if not modules or type(modules) ~= 'table' then 
        return 
    end

    -- module 'string', 'function', 'table'
    -- submodule { 'string', 'function', 'table' }
    for k,v in pairs(modules) do
        local key_type = type(k)
        if type(v) == 'table' then
            for sk,sv in pairs(v) do
                local tsk = type(sk)
                if tsk == 'number' then 
                    sk = sv 
                end

                local spath = tsk == 'string' and k..'/'..sk or k
                local sfn = sv
                if type(sv) == 'string' then
                    spath = k ..'/'.. sk
                    sfn = k ..'.'.. sk
                end

                self:use(spath, sfn)
            end
        else
            if key_type == 'number' then 
                k = v 
            end

            self:use(k, v)
        end
    end
end

function _M.use(self, path, fn)
    if not path then return end

    -- validate path
    local config = self.config
    local services = self.services
    local paths = self.paths
    local tp = type(path)
    if tp ~= 'string' then 
        fn = path
        path = sub(var.uri, config.base_length)
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

    -- register path
    services[path] = o
    for m,_ in pairs(o) do
        if not REST[m] then
            paths[path..'/'..m] = { module = path, action = m }
        end
    end
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

    local status, body = self:load()
    if status then
        ngx.status = status
    end

    if not body then 
        return
    end
    
    if type(body) == 'table' then 
        body = cjson.encode(body) 
    end

    print(body)
end

function _M.load(self, path)
    local services = self.services
    if not services then return HTTP_NOT_FOUND end 
    
    local config = self.config
    local paths = self.paths
    local path = path or sub(var.uri, config.base_length)
    -- check services
    local service = services[path]
    local module = service and path
    local arg = get_uri_args()
    local method = lower(arg.method or var.request_method)
    local handler = service and service[method]
    local action = handler and method

    -- check paths
    if not module and paths[path] then
        module = paths[path].module
        action = paths[path].action
    end
    
    -- check args number module/:id/action
    if not module then
        local from, to, err = re_find(path, "([0-9]+)", "jo")
        if from then
            module = sub(path, 1, from - 2)
            action = sub(path, to + 2)
            arg.id = sub(path, from, to)
        end
    end
    
    if not module then 
        return HTTP_NOT_FOUND
    end

    -- handle special method
    if module and (not action or action == '') then 
        if method == 'head' or method == 'options' then 
            return HTTP_OK
        end

        action = method
        if method == 'post' or method == 'put' then
            action = 'save'
        end
    end
    
    if config.debug then 
        log(WARN, 'load service ', module, ', with request ',
            method, ', and action ', action, ', id ', arg.id ) 
    end

    service = service or services[module]
    handler = handler or service[action]
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
    local user = self.validate_user
    local auth = service.AUTHORIZE
    local auths = service.AUTHORIZES
    if user and (auth or (auths and auths[action])) and not user(param) then
        return HTTP_UNAUTHORIZED
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

    -- execute begin request hook
    if self.begin_request then 
        self.begin_request(param) 
    end

    local body, status = handler(param)

    -- execute end request hook
    if self.end_request then
        self.end_request(param)
    end

    return status, body
end

return _M

