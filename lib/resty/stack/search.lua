-- Copyright (C) Anton heryanto.

local lower = string.lower
local len = string.len
local max = math.max
local log = math.log
local unpack = unpack
local gsub = ngx.re.gsub
local split = require "resty.stack.utils".split
local rrandom = require "resty.random"
local rstring = require "resty.string"

local ok, new_tab = pcall(require, "table.new")
if not ok then
    new_tab = function (narr, nrec) return {} end
end

local _M = new_tab(0,4)


-- stop words pulled from the below url
-- http://www.textfixer.com/resources/common-english-words.txt
local WORDS = [[a,able,about,across,after,all,almost,also,am,among,an,and,any,
are,as,at,be,because,been,but,by,can,cannot,could,dear,did,do,does,either,else,
ever,every,for,from,get,got,had,has,have,he,her,hers,him,his,how,however,i,if,
in,into,is,it,its,just,least,let,like,likely,may,me,might,most,must,my,neither,
no,nor,not,of,off,often,on,only,or,other,our,own,rather,said,say,says,she,
should,since,so,some,than,that,the,their,them,then,there,these,they,this,tis,
to,too,twas,us,wants,was,we,were,what,when,where,which,while,who,whom,why,will,
with,would,yet,you,your"]]

local common_words = split(WORDS, ",")

local nword = #common_words
local stop_words = new_tab(0,nword)
for i=1,nword do
    stop_words[common_words[i]] = true
end

local mt = { __index = _M }

function _M.new(self, prefix, redis)
    -- All of our index keys are going to be prefixed with the provided
    -- prefix string.  This will allow multiple independent indexes to
    -- coexist in the same Redis db.
    prefix = prefix and lower(prefix) ..":" or ""
    return setmetatable({ redis = redis, prefix = prefix}, mt)
end

-- Very simple word-based parser.  We skip stop words and single character words.
local function get_index_keys(content)
    -- remove non alphanumeric character
    local raw = gsub(lower(content), "[^a-z0-9' ]"," ","jo")
    local raws = split(raw," ")
    -- strip multi occurance of '
    local j = 0
    local words = {}
    for i=1,#raws do
        local w = split(raws[i],"'")[1]
        if not stop_words[w] and len(w) > 1 then
            j = j + 1
            words[j] = w
        end
    end

    return words, j
end

-- Calculated the TF portion of TF/IDF
local function get_index_scores(content)
    local words, wordcount = get_index_keys(content)
    local j = 1
    local keys = {}
    local counts = {}
    for i=1,wordcount do
        local w = words[i]
        counts[w] = (counts[w] or 0.0) + 1.0  
        if counts[w] then
            keys[j] = w
            j = j + 1
        end
    end

    local ncount = #keys
    local tf = new_tab(0,ncount)
    for i=1,ncount do
        local k = keys[i]
        tf[k] = counts[k]/wordcount
    end

    return keys, ncount, tf
end

function _M.add_indexed_item(self, id, content)
    local r = self.redis
    local keys, n, tf = get_index_scores(content)
    r:init_pipeline(n+1)
    r:sadd(self.prefix .."indexed:", id)
    for i=1,n do
        local k = keys[i]
        r:zadd(self.prefix .. k, tf[k], id)
    end
    r:commit_pipeline()
    return n
end

function _M.remove_indexed_item(self, id, content)
    local r = self.redis
    local keys, n, tf = get_index_scores(content)
    r:init_pipeline(n+1)
    r:srem(self.prefix .."indexed:", id)
    for i=1,n do
        local k = keys[i]
        r:zrem(self.prefix .. k, id)
    end
    r:commit_pipeline()
    return n
end

function _M.query(self, q, offset, count)
    offset = offset or 0
    count = count or 10
    -- Get our search terms just like we did earlier...
    local r = self.redis
    local words, n = get_index_keys(q)
    if n == 0 then return {}, 0 end

    local total_docs = max(r:scard(self.prefix .."indexed:"), 1)
    local keys = new_tab(n,0)

    -- Get our document frequency values...
    r:init_pipeline(n)
    for i=1,n do
        local key = self.prefix .. words[i]
        keys[i] = key
        r:zcard(key)
    end
    local sizes = r:commit_pipeline()

    -- Calculate the inverse document frequencies..
    local idfs = new_tab(n,0)
    local nsize = 0
    for i=1,n do
        local size = sizes[i]
        if size > 0 then nsize = nsize + 1 end
        -- math.log(value,base) = math.log(value) / math.log(base)
        idfs[i] = size == 0 and 0 or max(math.log(total_docs/size) / math.log(2), 0)
    end

    if nsize == 0 then return {}, 0 end

    --  And generate the weight dictionary for passing to zunionstore.
    local j = 0
    local weights = new_tab((nsize * 2) + 1, 0) 
    weights[nsize + 1] = "WEIGHTS"
    for i=1,n do
        local size = sizes[i]
        local key = keys[i]
        local idfv = idfs[i]
        if size then
            j = j + 1
            weights[j] = key
            weights[j + nsize + 1] = idfv
        end
    end

    -- Generate a temporary result storage key
    local temp_key = self.prefix ..'temp:'.. rstring.to_hex(rrandom.bytes(8))
    -- Actually perform the union to combine the scores.
    local known = r:zunionstore(temp_key, j, unpack(weights))
    -- Get the results.
    local ids = r:zrevrange(temp_key, offset, offset + count - 1, "WITHSCORES") 
    -- Clean up after ourselves.
    r:del(temp_key)

    return ids, known
end

return _M
