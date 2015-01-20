use Test::Nginx::Socket::Lua;
use Cwd qw(cwd);

repeat_each(2);

plan tests => repeat_each() * (blocks() * 2);

my $pwd = cwd();

our $HttpConfig = <<"_EOC_";
  lua_package_path "$pwd/lib/?.lua;;";
_EOC_

no_long_string();
no_diff();
run_tests();

__DATA__

=== TEST 1: resty.stack.post
--- http_config eval: $::HttpConfig
--- config
    location /t {
      content_by_lua "
        local cjson = require 'cjson'
        local post = require 'resty.stack.post'
        local m = post.get({})
        ngx.say(cjson.encode(m))
      ";
    }

--- request
POST /t
a=3&b=4&c
--- response_body
{"b":"4","a":"3","c":true}
--- error_log
