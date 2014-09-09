-- Copyright (C) Anton heryanto.

local verbose = true 
if verbose then
  local dump = require "jit.dump"
  dump.on(nil, "logs/jit.log")
else
  local v = require "jit.v"
  v.on("logs/jit.log")
end 

cjson = require "cjson"
new_tab = require "table.new"

require "resty.core" 
redis = require "resty.redis"
upload = require "resty.upload"

utils = require "resty.stack.utils"
post = require "resty.stack.post"
app = require "resty.stack.app"
