lua-resty-stack
===============

Openresty Simple Application Stack

Synopsis
========
REST based Application Stack

Installation
============
* download or clone this repo
* copy to openresty/lualib/resty/ or to Application path lib/resty

How to use
==========
edit nginx.conf

```nginx.conf
lua_package_path "$prefix/api/?.lua;$prefix/lib/?.lua;;";
server {
  listen 8080;
  
  location /hello {
    default_type "application/json; charset=UTF-8";
    content_by_lua '
      local app = require "resty.stack"
      app.use(function(self)
        return "Hello" 
      end)
    ';
  }

  location /api {
    default_type "application/json; charset=UTF-8";
    content_by_lua '
      local app = require "resty.stack"
      app.use({
        get = function(self)
          return "get Hello" 
        end

        post = function(self) 
          return "post Hello"
        end

        put = function(self) 
          return "put Hello"
        end

        delete = function(self)
          return "delete Hello"
        end
      })
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

function _M.put(self) 
  return "put Hello"
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
      local app = require "resty.stack"
      app.use(require "hello")
      app.run()
    '
 }
```

nginx -p `pwd`



Method
======



Author
======

Anton Heryanto <anton.heryanto@gmail.com>


Copyright and License
=====================

This module is licensed under the BSD license.

Copyright (C) 2014, by Anton Heryanto <anton.heryanto@gmail.com>.

All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
