local new_tab = require "table.new"
local setmetatable = setmetatable
local tcp = ngx.socket.tcp
local type = type
local concat = table.concat

local _M = new_tab(0,4)
_M._VERSION = '0.1.0'
local mt = { __index = _M }

function _M.new(self)
    local sock,err = tcp()
    if not sock then return nil, err end

    return setmetatable({ sock = sock }, mt)
end

function _M.set_timeout(self, timeout)
    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end
    return sock:settimeout(timeout)
end

function _M.connect(self, ...)
    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end
    --self.subscribed = nil
    return sock:connect(...)
end

function _M.close(self)
    local sock = self.sock
    if not sock then return nil, "not initialized" end

    return sock:close()
end

function _M.send(self, mail)
    local sock = self.sock
    if not sock then return nil, "not initialized" end

    mail = mail or {}
    mail.domain = mail.domain or 'localhost'

    local cmd = {
        {'HELO ', mail.domain, '\r\n'}, -- greeting
        {'MAIL FROM: <', mail.from, '>\r\n'}, -- from
    }

    local n = #cmd
    mail.rcpt = type(mail.to) == 'table' and mail.to or {mail.to}

    for i=1,#mail.to do
        n = n + 1
        cmd[n] = {'RCPT TO: <', mail.rcpt[i], '>\r\n'}
    end

    local data = {
        {
            'DATA\r\n', 
            'Subject: ', mail.subject, '\r\n', 
            mail.headers or '\r\n',
            mail.body
        }, -- data
        '\r\n.\r\n', -- end
        'QUIT\r\n'
    }

    for i=1,#data do
        n = n + 1
        cmd[n] = data[i]
    end

    sock:send(cmd) -- send command

    n = n + 1 -- for initial connnection
    local m = new_tab(n,0)
    for i=1,n do
        local r,e = sock:receive()
        if e == 'timeout' then break end
        m[i] = r
    end
    sock:close()
    return m
end

return _M
