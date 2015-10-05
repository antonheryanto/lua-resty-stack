lua-resty-stack
===============

Openresty Simple Application Stack

Table of Contents
=================
* [Status](#status)
* [Description](#description)
* [TODO](#todo)
* [Installation](#installation)
* [How to use](#how-to-use)
* [Methods](#methods)
* [Copyright and License](#copyright-and-license)
* [See Also](#see-also)

Status
========

Beta Quality and used in production


Description
===========

REST based Application Stack


TODO
====
* more test
* user defined routing module/:id/action

Installation
============

* download or clone this repo
* copy lib/resty/stack.lua to (Openresty Path)/lualib/resty/ or to (Application path)/resty

[Back to TOC](#table-of-contents)

How to use
==========

Recommended Application folder structure
* conf
  * nginx.conf
* resty
  * stack.lua
  * post.lua
  * template.lua
* api
  * config.lua 
  * app.lua
  * hello.lua

```nginx.conf
daemon off;
master process off;
error_log log/error.log warn;
event {}
http {
    client_body_temp_path logs;
    fastcgi_temp_path logs;
    proxy_temp_path logs;
    scgi_temp_path logs;
    uwsgi_temp_path logs;

    init_by_lua_file "api/app.lua";
    server {
        listen 8080;
        lua_code_cache off;
        location /api {
            content_by_lua "app:run()";
        }
    }
}
```

config.lua
```lua
return {
    debug: true,
    redis: { host = '127.0.0.1', port = 6379 },
}
```

app.lua
```lua
    local stack = require 'resty.stack'
    local config = require 'api.config'
    app = stack:new(config)
    app:service ({ api = { 
        'hello'
    }})
```

hello.lua
```lua
local _M = {}

function _M.get(self)
  return "get Hello" 
end

function _M.post(self) 
  return "post Hello"
end

function _M.delete(self)
  return "delete Hello"
end

return _M
```

```sh
$ nginx -p .
```

[Back to TOC](#table-of-contents)


Methods
=======

[Back to TOC](#table-of-contents)

new
---

`syntax: app = stack:new(config)`

Initate new stack apps with config parameter

use
---

`syntax: app:use(path, fn)`

register function or module

* `path`

    the route url path matching with function.
    if path is function the path is current location

* `fn`

    function to execute when path is accessed

service
------

`syntax: app:service(services)`

register servicese using lua table 

* `services`
    
    table of services to load

run
---

`syntax: app:run()`

running the application

authorize
---------

`syntax: function app.authorize(self) end`

implement authorize function for secure module


render
------

`syntax: function app.render(self)`

implement plugable render to override default render


begin\_request
-------------

`syntax: function app.begin_request(self)`

implement begin request hook


end\_request
------------

`syntax: function app.end_request(self)`

implement end request hook


[Back to TOC](#table-of-contents)

Copyright and License
=====================

This module is licensed under the BSD license.

Copyright (C) 2014 - 2015, by Anton Heryanto <anton.heryanto@gmail.com>.

All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

See Also
=======

* [lua-resty-post](https://github.com/antonheryanto/lua-resty-post) 
* [lua-resty-smtp](https://github.com/antonheryanto/lua-resty-smtp) 
* [lua-resty-pdf](https://github.com/antonheryanto/lua-resty-pdf) 
* [lua-resty-search](https://github.com/antonheryanto/lua-resty-search) 
* [lua-resty-upload](https://github.com/openresty/lua-resty-upload)
* [lua-nginx-module](https://github.com/openresty/lua-nginx-module)

[Back to TOC](#table-of-contents)
