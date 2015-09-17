use Test::Nginx::Socket::Lua;
use Cwd qw(cwd);

repeat_each(2);

plan tests => repeat_each() * (blocks() * 27);

my $pwd = cwd();

our $HttpConfig = <<"_EOC_";
    lua_package_path "$pwd/t/servroot/html/?.lua;/$pwd/lib/?.lua;;";
_EOC_

no_long_string();
#no_diff();

run_tests();

__DATA__

=== TEST 1: response to each methods
--- http_config eval: $::HttpConfig
--- config 
    location /t {
        content_by_lua "
            local stack = require 'resty.stack'
            app = stack:new()
            app:use(require 'method')
            app:run()
        ";
    }
--- user_files
>>> method.lua
local _M = {}
function _M.get() 
    return 'get'
end
function _M.post() 
    return 'post'
end
function _M.put() 
    return 'put'
end
function _M.delete() 
    return 'delete'
end
return _M
--- request eval
['GET /t', 'POST /t', 'PUT /t', 'DELETE /t', 
'GET /t?method=POST', 'GET /t?method=PUT', 'GET /t?method=DELETE',
'HEAD /t', 'OPTIONS /t']
--- response_body eval
['get', 'post', 'put', 'delete', 'post', 'put', 'delete', '', '']
--- no_error_log
[error]

