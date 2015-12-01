use Test::Nginx::Socket::Lua;
use Cwd qw(cwd);

repeat_each(2);

plan tests => repeat_each() * (blocks() * 18);

no_long_string();
#no_diff();

run_tests();

__DATA__

=== TEST 1: response to each methods
--- http_config
    lua_package_path "${prefix}../../lib/?.lua;/${prefix}/html/?.lua;;";
    init_by_lua "
        local stack = require 'resty.stack'
        app = stack:new()
        app:service({'t', t = {'m'}, a = 't.m'})
    ";
--- config
    location /t {
        content_by_lua "app:run()";
    }
    location /a {
        content_by_lua "app:run()";
    }
--- user_files
>>> t.lua
local _M = {}
function _M.get(self)
    return 't'..(self.arg.id or '')
end
function _M.x(self)
    return 'tx'..(self.arg.id or '')
end
return _M
>>> t/m.lua
local _M = {}
function _M.get(self)
    return 'tm'..(self.arg.id or '')
end
function _M.x(self)
    return 'tmx'..(self.arg.id or '')
end
return _M
--- request eval
['GET /t', 'GET /t/1', 'GET /t/1/x'
,'GET /t/m', 'GET /t/m/1', 'GET /t/m/1/x'
,'GET /a', 'GET /a/1', 'GET /a/1/x']
--- response_body eval
['t', 't1', 'tx1', 'tm', 'tm1', 'tmx1',
'tm', 'tm1', 'tmx1']

