-- Copyright (C) 2014 - 2015 Anton heryanto.

local pcall = pcall
local setmetatable = setmetatable
local pairs = pairs
local type = type
local tonumber = tonumber
local sub = string.sub
local lower = string.lower
local byte = string.byte
local new_tab = require 'table.new'
local cjson = require 'cjson'
local has_resty_post, resty_post = pcall(require, 'resty.post')
local ngx = ngx
local var = ngx.var
local req = ngx.req
local print = ngx.print
local log = ngx.log
local exit = ngx.exit
local read_body = ngx.req.read_body
local get_post_args = ngx.req.get_post_args
local get_uri_args = ngx.req.get_uri_args
local re_find = ngx.re.find
local WARN = ngx.WARN
local HTTP_OK = ngx.HTTP_OK
local HTTP_NOT_FOUND = ngx.HTTP_NOT_FOUND
local HTTP_UNAUTHORIZED = ngx.HTTP_UNAUTHORIZED

local _M = new_tab(0, 9)
local mt = { __index = _M }
_M._VERSION = '0.3.1'

function _M.new(self, config)
    config = config or {}
    config.base_length = config.base and #config.base + 2 or 2
    local post = has_resty_post and resty_post:new(config.upload_path)
    config.upload_path = config.upload_path or post and post.path
    return setmetatable({
        post = post,
        config = config,
        services = {}
    }, mt)
end

-- register service
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
-- validate authorization support at service and method level
-- FIXME: only used for init state as pairs is NYI
-- TODO: predefines method and regex options
local function router(self, path, service)
    local auth = service.AUTHORIZE
    for m,o in pairs(service) do
        local mt = type(o)
        local mp = path..'/'..m
        local authorize = auth == true or auth and auth[m]
        if mt == 'function' then
            self.services[mp] = { service = o, authorize = authorize }
        elseif mt == 'table' then -- recursive add routes
            router(self, mp, o)
        end
    end
end

-- FIXME provides single param instead of multiple for simplicity
-- FIXME string, function, or table for complete
function _M.use(self, path, fn, authorize)
    if not path then return end

    -- validate path
    local config = self.config
    local services = self.services
    local tp = type(path)
    if tp ~= 'string' then
        authorize = fn
        fn = path
        path = var.uri
    end

    if byte(path, 1) == 47 then -- char '/'
        path = sub(path, config.base_length)
    end

    if not fn then
        fn = path
    end

    local tf = type(fn)
    if tf == 'function' then
        services[path] = { service = fn, authorize = authorize }
    elseif tf == 'table' then
        router(self, path, fn)
    elseif tf == 'string' then
        router(self, path, require(fn))
    end
end

-- default header and body render
-- default handling json only
-- FIXME handle return text, html, binary
function _M.render(self, body)
    if not body then return end

    -- json when service return table
    if type(body) == 'table' then
	local header = ngx.header
	header['Content-Type'] = 'application/json'
        body = cjson.encode(body)
    end

    -- print string body, type define by service
    print(body)
end

-- FIXME simplify best way to modify header
function _M.set_header(self)
    local header = ngx.header
    header['Access-Control-Allow-Origin'] = '*'
    header['Access-Control-Max-Age'] = 2520
    header['Access-Control-Allow-Methods'] = 'GET,POST,PUT,DELETE,HEAD,OPTIONS'
end


-- main method run app request
-- FIXME: uses return instead of status
-- TODO: plugable render for content
function _M.run(self)
    local status, body = self:load()
    if status then
        ngx.status = status
        if not body then
            return exit(status)
        end
    end

    self:render(body)
end

function _M.load(self, uri)
    local services = self.services
    if not services then
        return HTTP_NOT_FOUND
    end

    if not uri then
        uri = var.uri
    end

    local config = self.config
    local slash = byte(uri, #uri) == 47 and #uri - 1 or nil -- char '/'
    local path = sub(uri, config.base_length, slash)
    local arg = get_uri_args()
    local method = lower(arg.method or var.request_method)
    if (method == 'head' or method == 'options') and services[path..'/get'] then
        return HTTP_OK
    end

    -- check path or path/method
    local route  = services[path] or services[path..'/'..method]

    -- check args number service/:id/action
    if not route then
        local from, to, err = re_find(path, '([0-9]+)', 'jo')
        if from then
            local service = sub(path, 1, from - 2)
            local action = sub(path, to + 2)
            if action == '' then
                action = method
            end

            route = services[service..'/'..action]
            arg.id = sub(path, from, to)
        end
    end

    if not route then
        return HTTP_NOT_FOUND
    end

    if config.debug then
        log(WARN, 'path: ', path, ' method: ', method, ' id: ', arg.id,
            ' authorize ', type(route.authorize))
    end

    -- setup service and params
    local service = route.service
    local params = {
	authorize = route.authorize,
        config = self.config,
        arg = arg
    }

    -- execute begin request hook
    if self.begin_request then
        self.begin_request(params)
    end

    -- validate authorization
    local authorize = self.authorize
    if authorize and route.authorize and not authorize(params) then
        -- execute end request hook
        if self.end_request then
            self.end_request(params)
        end

        return HTTP_UNAUTHORIZED
    end

    -- process post/put data
    local post = self.post
    if method == 'post' or method == 'put' then
        if post then
            params.data = post:read()
        else
            read_body()
            params.data = get_post_args()
        end
    end

    local body, status = service(params)

    -- execute end request hook
    if self.end_request then
        self.end_request(params)
    end

    return status, body
end

return _M

