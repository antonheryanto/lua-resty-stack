use Test::Nginx::Socket::Lua;
use Cwd qw(cwd);

repeat_each(2);

plan tests => repeat_each() * (blocks() * 3); 

my $pwd = cwd();

our $HttpConfig = <<"_EOC_";
    lua_package_path "$pwd/t/servroot/html/?.lua;$pwd/lib/?.lua;;";
    init_by_lua "
        local stack = require 'resty.stack'
        app = stack:new()
        app:use('authorize', {
            AUTHORIZE = true,
            get = function() end,
            post = function() end
        })
        app:use('authorizes', {
            AUTHORIZES = { get = true },
            get = function() end,
            post = function() end
        })
        function auth(self)
            if not self.arg.auth then
                ngx.status = ngx.HTTP_UNAUTHORIZED
            end
        end
    ";
_EOC_

no_long_string();
#no_diff();

run_tests();

__DATA__

=== TEST 1: Authorize
--- http_config eval: $::HttpConfig
--- config
    location /authorize {
        content_by_lua "app:run()";
    }
--- request eval
['GET /authorize','POST /authorize', 'GET /authorize?auth=1']
--- error_code eval
[200, 200, 200]

=== TEST 2: Authorizes
--- http_config eval: $::HttpConfig
--- config
    location /authorizes {
        content_by_lua "app:run()";
    }
--- request eval
['GET /authorizes','POST /authorizes', 'GET /authorizes?auth=1']
--- error_code eval
[200, 200, 200]

=== TEST 3: use Authorize
--- http_config eval: $::HttpConfig
--- config
    location /authorize {
        content_by_lua "
            app.validate_user = auth
            app:run()
        ";
    }
--- request eval
['GET /authorize','POST /authorize', 'GET /authorize?auth=1']
--- error_code eval
[401, 401, 200]

=== TEST 4: use Authorizes
--- http_config eval: $::HttpConfig
--- config
    location /authorizes {
        content_by_lua "
            app.validate_user = auth
            app:run()
        ";
    }
--- request eval
['GET /authorizes','POST /authorizes', 'GET /authorizes?auth=1']
--- error_code eval
[401, 200, 200]

