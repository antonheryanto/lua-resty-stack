local new_tab = require 'table.new'
local _M = new_tab(0,1)

function _M.required(model, properties)
    if not model or not properties then return {'data is empty'} end

    local n = #properties
    if n == 0 then return end

    local errors, ne = new_tab(n,0), 1
    for i=1,n do
        local p = properties[i]
        local v = model[p]
        if not v or v == '' then
            errors[ne] = p .." is required"
            ne = ne + 1
        end
    end
    return errors

end

return _M
