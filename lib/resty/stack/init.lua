-- Copyright (C) Anton heryanto.

local verbose = require "resty.stack.config".debug 
if verbose then
  ngx.log(ngx.WARN,"dump jit")
  local dump = require "jit.dump"
  dump.on("b", "logs/jit.log")
else
  local v = require "jit.v"
  v.on("logs/jit.log")
end 

require "resty.core" 

cjson = require "cjson"

config = require "resty.stack.config"
utils = require "resty.stack.utils"
post = require "resty.stack.post"
app = require "resty.stack.app"
