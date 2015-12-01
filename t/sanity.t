use Test::Nginx::Socket::Lua;
use Cwd qw(cwd);

repeat_each(2);

plan tests => repeat_each() * (blocks() * 6);

my $pwd = cwd();

our $HttpConfig = <<"_EOC_";
    lua_package_path "$pwd/t/servroot/html/?.lua;$pwd/lib/?.lua;;";
_EOC_

no_long_string();
#no_diff();

run_tests();

__DATA__

=== TEST 1: inline use
--- http_config eval: $::HttpConfig
--- config
    location /t {
      content_by_lua "
        local app  = require 'resty.stack':new()
        app:use(function(self)
          return 'ok'
        end)
        app:run()
      ";
    }

    location /base {
      content_by_lua "
        local stack = require 'resty.stack'
        local app = stack:new{ base = '/base/' }
        app:use(function(self)
          return {base = 'base'}
        end)
        app:run()
      ";
    }
--- request eval
['GET /t', 'GET /base']
--- response_body eval
['ok', '{"base":"base"}']
--- no_error_log
[error]

=== TEST 2: use service
--- http_config
    lua_package_path "${prefix}../../lib/?.lua;${prefix}html/?.lua;;";
    init_by_lua "
        local stack = require 'resty.stack'
        app = stack:new()
        app:use('hello')
    ";
--- config
    location /hello {
        content_by_lua "app:run()";
    }
--- user_files
>>> hello.lua
local _M = {}
function _M.get(self)
    return ''
end
function _M.empty(self)
    return
end
return _M
--- request eval
['GET /hello', 'GET /hello/empty']
--- response_body eval
['', 'null']
--- no_error_log
[error]

=== TEST 3: override status
--- http_config eval: $::HttpConfig
--- config
    location /t {
      content_by_lua "
        local app = require 'resty.stack':new()
        app:use({
            get = function() return 'NOT_MODIFIED', 304 end,
            post = function() return 'ACCEPTED', 202 end,
            put = function() return 'CREATED', 201 end,
            delete = function() return 'NO_CONTENT', 204 end
        })
        app:run()
      ";
    }
--- request eval
['GET /t', 'POST /t', 'PUT /t', 'DELETE /t']
--- error_code eval
[304, 202, 201, 204]
--- response_body eval
['', 'ACCEPTED', 'CREATED', '']

=== TEST 4: throw error
--- http_config eval: $::HttpConfig
--- config
    location /t {
      content_by_lua "
        local app = require 'resty.stack':new()
        app:use({
            get = function() return 'UNAUTHORIZED', 401 end,
            post = function() return 'FORBIDDEN', 403 end,
            put = function() return 'NOT_FOUND', 404 end,
            delete = function() return 'NOT_ALLOWED', 405 end
        })
        app:run()
      ";
    }
--- request eval
['GET /t', 'POST /t', 'PUT /t', 'DELETE /t']
--- error_code eval
[401, 403, 404, 405]

