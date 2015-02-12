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

=== TEST 1: sanity
--- http_config eval: $::HttpConfig
--- config
    location /t {
      content_by_lua '
        local app = require "resty.stack"
        app.use(function(self) 
          return "ok"
        end) 
        app.run()
      ';
    }
--- request
GET /t
--- response_body: ok
--- no_error_log
[error]
