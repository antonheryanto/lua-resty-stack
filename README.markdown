lua-resty-stack
===============

Openresty Simple Application Stack


Installation
============
* copy lib/resty/stack to openresty/lualib/resty/


How to use
==========
edit nginx.conf

```nginx.conf
init_by_lua_file "resty/stack/init.lua";

server {
  listen 8080;
  
  location /api {
    default_type "application/json; charset=UTF-8";
    content_by_lua 'app.run()';
  }
}
```
