require "resty.stack.string"
local new_tab = require "table.new"
local redis = require "resty.redis"
local mysql = require "resty.mysql"
local concat = table.concat
local trim = string.trim
local unpack = unpack
local type = type
local null = ngx.null
local log = ngx.log
local ERR = ngx.ERR

local _M = new_tab(0,3)

function _M.mysql(conf)
    conf = conf or {}
    conf.host = conf.host or '127.0.0.1'
    conf.port = conf.port or 3306
    conf.database = conf.database or 'test'
    conf.user = conf.user or 'root'
    conf.password = conf.password or ''

    local db = mysql:new()
    db:set_timeout(conf.timeout or 1000)
    db:connect(conf) 
    
    return db, conf
end

function _M.redis(conf)
    conf = conf or {}
    local r = redis:new()
    r:set_timeout(conf.timeout)
    local ok,err = conf.socket and r:connect(conf.socket) 
        or r:connect(conf.host or '127.0.0.1', conf.port or 6379)

    if not ok then 
        log(ERR, "failed connect to redis with message : ".. (err or ''))
        return
    end

    -- add method to redis
    function r.key(r, ...)
        return concat({...},':')
    end

    function r.hash_get(r, key, ...)
        local args = {...}
        local fields = (#args == 1 and type(args[1]) == 'table') and args[1] or args
        local n = #fields
        local m = new_tab(0, n)
        local data = r:hmget(key,unpack(fields)) 
        for i=1,n do
            local k = fields[i]
            local v = data[i]
            if v ~= null then m[k] = v end
        end
        return m
    end

    function r.hash_save(r, key, data, fields, n)
        n = n or #fields
        for i=1,n do
            local k = fields[i]
            local v = trim(data[k])
            if v and v ~= '' and v ~= null then r:hset(key, k, v) end
        end
    end

    return r, conf
end

function _M.init(conf, fn)
    conf = conf or {}
    conf.host = conf.host or "127.0.0.1"
    conf.timeout = conf.timeout or 1000
    conf.keep_size = conf.keep_size or 1024
    conf.keep_idle = conf.keep_idle or 0
    fn = fn or (conf.type and _M[conf.type])
    if fn then return fn(conf) end
end

function _M.keep(db, conf)
    if not db then return end

    local ok,err = db:set_keepalive(conf.keep_idle or 0, conf.keep_size or 1024)
    if not ok then log(ERR, "failed to keepalive with message : ".. err) end
end

return _M
