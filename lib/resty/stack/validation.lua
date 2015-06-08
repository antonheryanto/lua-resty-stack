local new_tab = require 'table.new'
local trim = require 'resty.stack.string'.trim
local _M = new_tab(0,1)

function _M.required(model, properties)
    if not model or not properties then return {'data is empty'} end

    local n = #properties
    if n == 0 then return end

    local errors = new_tab(0,n)
    local e = 0
    for i=1,n do
        local p = properties[i]
        local v = trim(model[p])
        if not v or v == '' then
            e = e + 1
            errors[p] = "is required"
        end
    end
    return errors, e
end

return _M
