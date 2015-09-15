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
* copy to openresty/lualib/resty/ or to Application path lib/resty

[Back to TOC](#table-of-contents)

How to use
==========
edit nginx.conf

```nginx.conf
lua_package_path "$prefix/api/?.lua;$prefix/lib/?.lua;;";
server {
  listen 8080;
  
  location /hello {
    content_by_lua '
      local stack = require "resty.stack"
      local app = stack:new()
      app:use(function(self)
        return "Hello" 
      end)
      app:run()
    ';
  }

  location /api {
    content_by_lua '
      local stack = require "resty.stack"
      local app = stack:new()
      app:use({
        get = function(self)
          return "get Hello" 
        end

        post = function(self) 
          return "post Hello"
        end
      })
      app:run()
    ';
  }
}
```
uses separated files
hello.lua
```lua
local _M = {}

function _M.get(self)
  return "get Hello" 
end

function _M.save(self) 
  return "post Hello"
end

function _M.delete(self)
  return "delete Hello"
end

return _M
```

```nginx.conf
 location /api {
    default_type "application/json; charset=UTF-8";
    content_by_lua '
      local stack = require "resty.stack"
      local app = stack:new()
      app:use(require "hello")
      app:run()
    '
 }
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

module
------

`syntax: app:module(table)`

register module using lua table 

* `table`
    
    table list module to load

run
---

`syntax: app:run()`

running the application


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
