use Test::Nginx::Socket::Lua;
use Cwd qw(cwd);

repeat_each(2);

plan tests => repeat_each() * (blocks() * 4);

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
        local app = require 'resty.stack':new()
        app:use(function(self) 
          return 'ok'
        end) 
        app:run()
      ";
    }
--- request
GET /t
--- response_body: ok

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
    return 'hello'
end
return _M
--- request
GET /hello
--- response_body: hello

=== TEST 3: override status
--- http_config eval: $::HttpConfig
--- config
    location /t {
      content_by_lua "
        local app = require 'resty.stack':new()
        app:use({
            get = function() return nil, 404 end,
            post = function() return 'accepted', 202 end,
            put = function() return 'created', 201 end,
            delete = function() return nil, 204 end
        }) 
        app:run()
      ";
    }
--- request eval
['GET /t', 'POST /t', 'PUT /t', 'DELETE /t']
--- error_code eval
[404, 202, 201, 204]
--- response_body eval
['', 'accepted', 'created', '']

