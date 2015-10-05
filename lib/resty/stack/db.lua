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
local WARN = ngx.WARN

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
    local ok,err = db:connect(conf) 
    if not ok then 
        log(ERR, 'failed connect to mysql with message: ', err) 
        return
    end
    
    return db, conf
end

function _M.redis(conf)
    conf = conf or {}
    local r = redis:new()
    r:set_timeout(conf.timeout or 1000)
    local ok,err = conf.socket and r:connect(conf.socket) 
        or r:connect(conf.host or '127.0.0.1', conf.port or 6379)

    if not ok then 
        log(ERR, "failed connect to redis with message : ", err)
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
        r:init_pipeline(n)
        for i = 1, n do
            r:hget(key, fields[i])
        end

        local data = r:commit_pipeline()
        for i = 1, n do
            local v = data[i]
            if v ~= null then m[fields[i]] = v end
        end

        return m
    end

    function r.hash_save(r, key, data, fields, n)
        n = n or #fields
        for i=1,n do
            local k = fields[i]
            local v = trim(data[k])
            local t = type(v)
            if v and v ~= '' and v ~= null and v ~= 'table'  and v ~= 'function' then 
                r:hset(key, k, v) 
            end
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
    if not db or not db.set_keepalive then return end
    conf = conf or {}

    if conf.debug then
        local times, ex = db:get_reused_times()
        log(WARN, "reused: ", times, " error: ", ex)
    end

    local ok,err = db:set_keepalive(conf.keep_idle or 1000, conf.keep_size or 1024)
    if not ok then 
        log(ERR, "failed to keepalive with message: ", err) 
    end
end

return _M
