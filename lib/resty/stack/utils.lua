-- Copyright (C) Anton heryanto.
-- deprecated will remove soon
require "resty.stack.string"
local db = require "resty.stack.db"
local validation = require "resty.stack.validation"
local new_tab = require "table.new"
local _M = new_tab(0, 5)

_M.validates = validation.required
_M.titlecase = string.titlecase
_M.trim = string.trim
_M.split = string.split
_M.keep_redis = db.keep
function _M.get_redis(conf)
    return db.init(conf, db.redis)
end

return _M
