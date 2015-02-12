-- Copyright (C) Anton heryanto.

--local verbose = require "resty.stack.config".debug 
--if verbose then
--  local dump = require "jit.dump"
--  dump.on("b", "logs/jit.log")
--else
--  local v = require "jit.v"
--  v.on("logs/jit.log")
--end 

require "resty.core" 

cjson = require "cjson"

utils = require "resty.stack.utils"
post = require "resty.stack.post"
app = require "resty.stack"
