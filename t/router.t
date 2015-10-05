use Test::Nginx::Socket::Lua;
use Cwd qw(cwd);

repeat_each(2);

plan tests => repeat_each() * (blocks() * 10);

my $pwd = cwd();

our $HttpConfig = <<"_EOC_";
    lua_package_path "$pwd/t/servroot/html/?.lua;/$pwd/lib/?.lua;;";
    init_by_lua "
        local _M = {}
        function _M.get(self)
            local id = self.arg.id or ''
            return 'get'..id
        end
        function _M.x(self)
            local id = self.arg.id or ''
            return 'x'..id
        end
        local stack = require 'resty.stack'
        app = stack:new({debug = true})
        app:use('t', _M)
        app:use('t/m', _M)
    ";
_EOC_

no_long_string();
#no_diff();

run_tests();

__DATA__

=== TEST 1: first level routing
--- http_config eval: $::HttpConfig
--- config 
    location /t {
        content_by_lua "app:run()";
    }
--- request eval
['GET /t', 'GET /t?id=1', 'GET /t/x', 'GET /t/1', 'GET /t/1/x'] 
--- response_body eval
['get', 'get1', 'x', 'get1', 'x1']

=== TEST 2: second level routing
--- http_config eval: $::HttpConfig
--- config 
    location /t/m {
        content_by_lua "app:run()";
    }
--- request eval
['GET /t/m', 'GET /t/m?id=1', 'GET /t/m/x', 'GET /t/m/1', 'GET /t/m/1/x'] 
--- response_body eval
['get', 'get1', 'x', 'get1', 'x1']
