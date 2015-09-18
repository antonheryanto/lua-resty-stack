use Test::Nginx::Socket::Lua;
use Cwd qw(cwd);

repeat_each(2);

plan tests => repeat_each() * (blocks() * 3);

my $pwd = cwd();

our $HttpConfig = <<"_EOC_";
    lua_package_path "$pwd/t/servroot/html/?.lua;$pwd/lib/?.lua;;";
    init_by_lua "
        local db = require 'resty.stack.db'
        local stack = require 'resty.stack'
        app = stack:new()
        app:use('t', function(self)
            return self.r:get('cat')      
        end)
        function app.begin_request(self)
            self.r = db.redis(self.config.redis)
            self.r:set('cat', 'tiger')
        end
        function app.end_request(self)
            db.keep(self.r, self.config.redis)
        end
    ";
_EOC_

no_long_string();
        
run_tests();

__DATA__

=== TEST 1: begin and end request
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua "app:run()";
    }
--- request 
GET /t
--- response_body: tiger
--- no_error_log
[error]
