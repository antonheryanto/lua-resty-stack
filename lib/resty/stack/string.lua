local new_tab = require "table.new"
local string = string
local len = string.len
local find = string.find
local sub = string.sub
local gsub = string.gsub
local lower = string.lower
local upper = string.upper
local match = string.match

local smallwords = {
    a=1, ["and"]=1, as=1, at=1, but=1, by=1, en=1, ["for"]=1, ["if"]=1,
    ["in"]=1, of=1, the=1, to=1, vs=1, ["vs."]=1, v=1, ["v."]=1, via=1
}

function string.titlecase(self)
    title = lower(self)
    return (gsub(title, "()([%w&`'''\".@:/{%(%[<>_]+)(-? *)()", function (index, nonspace, space, endpos)
        local low = lower(nonspace)
        if (index > 1) and (sub(title, index - 2,index - 2) ~= ':')
            and (endpos < #title) and smallwords[low] then
            return low .. space
        elseif match(sub(title, index - 1, index + 1), "['\"_{%(%[]/)") then
            return sub(nonspace, 1, 1) .. upper(sub(nonspace, 2, 2))
            .. sub(nonspace, 3) .. space
        elseif match(sub(nonspace, 2),"[A-Z&]")
            or match(sub(nonspace, 2),"%w[%._]%w") then
            return nonspace .. space
        end
        return upper(sub(nonspace, 1, 1)) .. sub(nonspace, 2) .. space
    end))
end


function string.trim(self)
    if not self or type(self) ~= "string" then return self end
    return (gsub(self, "^%s*(.-)%s*$", "%1"))
end

function string.split(self, delimiter, limit)
    if not self or type(self) ~= "string" then return end
    local length = len(self)

    if length == 1 then return {self} end

    local result = limit and new_tab(limit, 0) or {}
    local index = 0
    local n = 1

    while true do
        if limit and n > limit then break end

        local pos = find(self,delimiter,index,true) -- find the next d in the string
        if pos ~= nil then -- if "not not" found then..
            result[n] = sub(self,index, pos - 1) -- Save it in our array.
            index = pos + 1 -- save just after where we found it for searching next time.

        else
            result[n] = sub(self,index) -- Save what's left in our array.
            break -- Break at end, as it should be, according to the lua manual.

        end
        n = n + 1
    end

    return result, n
end

-- local usage insted of global extend string
local _M = new_tab(0,3)
_M.titlecase = string.titlecase
_M.trim = string.trim
_M.split = string.split
return _M
