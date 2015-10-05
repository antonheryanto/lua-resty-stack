-- Copyright (C) 2014 - 2015 Anton heryanto.

local pcall = pcall
local setmetatable = setmetatable
local pairs = pairs
local type = type
local tonumber = tonumber
local sub = string.sub
local lower = string.lower
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
local re_find = ngx.re.find
local HTTP_OK = ngx.HTTP_OK
local HTTP_NOT_FOUND = ngx.HTTP_NOT_FOUND
local HTTP_UNAUTHORIZED = ngx.HTTP_UNAUTHORIZED
local _M = new_tab(0, 9)
_M.VERSION = "0.2.1"

local mt = { __index = _M }
function _M.new(self, config)
    config = config or {}
    config.base_length = config.base and #config.base + 2 or 2
    local post = has_resty_post and resty_post:new(config.upload_path)
    config.upload_path = config.upload_path or post and post.path
    return setmetatable({
        post = post,
        config = config,
        paths = {},
        services = {}
    }, mt)
end

function _M.service(self, services)
    if not services or type(services) ~= 'table' then 
        return 
    end

    -- service 'string', 'function', 'table'
    -- sub service { 'string', 'function', 'table' }
    for k,v in pairs(services) do
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

                _M.use(self, spath, sfn)
            end
        else
            if type(k) == 'number' then 
                k = v 
            end

            _M.use(self, k, v)
        end
    end
end

-- provides routes table
-- TODO: predefines method and regex options
function _M.route(self, path, service)
    local paths = self.paths
    for m,o in pairs(service) do
        local mt = type(o)
        local mp = path..'/'..m
        -- only add function
        if mt == 'function' then
            paths[mp] = { service = path, action = m }
        -- recursive route add
        elseif mt == 'table' then -- recursive route add
            _M.route(self, mp, o) 
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
    local service
    if tf == 'function' then
        service = { get = fn }
    elseif tf == 'table' then
        service = fn
    elseif tf == 'string' then
        service = require(fn)
    end

    -- register path
    services[path] = service
    _M.route(self, path, service)
end

-- default header, override function to change
function _M.set_header(self)
    local header = ngx.header
    header['Access-Control-Allow-Origin'] = '*'
    header['Access-Control-Max-Age'] = 2520
    header['Access-Control-Allow-Methods'] = 'GET,POST,PUT,DELETE,HEAD,OPTIONS'
    header['Content-Type'] = 'application/json; charset=utf-8'
end

-- default table render
-- TODO: plugable render
function _M.render(self, body)
    return cjson.encode(body)
end

function _M.run(self)
    self.set_header(self)

    local status, body = self:load()
    if status then
        ngx.status = status
    end

    if not body then 
        return
    end
    
    if type(body) == 'table' then 
        body = self.render(self, body) 
    end

    print(body)
end

function _M.load(self, path)
    local paths = self.paths
    if not paths then 
        return HTTP_NOT_FOUND 
    end 
    
    local config = self.config
    local services = self.services
    local path = path or sub(var.uri, config.base_length)
    local arg = get_uri_args()
    local method = lower(arg.method or var.request_method)
    if (method == 'head' or method == 'options') and paths[path..'/get'] then 
        return HTTP_OK
    end

    -- check path or path/method
    local fn = paths[path] or paths[path..'/'..method]

    -- check args number service/:id/action
    if not fn then
        local from, to, err = re_find(path, "([0-9]+)", "jo")
        if from then
            local service = sub(path, 1, from - 2)
            local action = sub(path, to + 2)
            if action == '' then 
                action = method
            end

            fn = paths[service..'/'..action]
            arg.id = sub(path, from, to)
        end
    end

    if not fn then 
        return HTTP_NOT_FOUND
    end

    if config.debug then 
        log(WARN, 'path ', path, ' load service ', fn.service, ', with request ',
            method, ', and action ', fn.action, ', id ', arg.id ) 
    end

    local service = services[fn.service]
    local handler = service and service[fn.action]
    if not handler then
        return HTTP_NOT_FOUND
    end
    
    self.arg = arg
    -- validate authorization support at service and method level
    local user = self.authorize
    local auth = service.AUTHORIZE
    local auths = service.AUTHORIZES
    if user and (auth or (auths and auths[fn.action])) and not user(self) then
        return HTTP_UNAUTHORIZED
    end
    
    -- process post/put data
    local post = self.post
    if method == 'post' or method == 'put' then
        if post then
            self.data = post:read()
        else
            read_body()
            self.data = get_post_args()
        end
    end

    -- execute begin request hook
    if self.begin_request then 
        self.begin_request(self) 
    end

    local body, status = handler(self)

    -- execute end request hook
    if self.end_request then
        self.end_request(self)
    end

    return status, body
end

return _M

