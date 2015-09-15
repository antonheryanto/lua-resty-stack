use Test::Nginx::Socket::Lua;
use Cwd qw(cwd);

repeat_each(2);

plan tests => repeat_each() * (blocks() * 3);

my $pwd = cwd();

our $HttpConfig = <<"_EOC_";
    lua_package_path "$pwd/lib/?.lua;;";
_EOC_

no_long_string();
#no_diff();

run_tests();

__DATA__

=== TEST 1: basic usage
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
--- no_error_log
[error]

=== TEST 2: define module
--- http_config
    lua_package_path "${prefix}../../lib/?.lua;${prefix}html/?.lua;;";       
    init_by_lua "
        local stack = require 'resty.stack'
        app = stack:new()
        app:module({'hello'})
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
--- no_error_log
[error]

