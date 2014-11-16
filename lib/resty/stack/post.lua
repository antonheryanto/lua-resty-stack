-- Copyright (C) Anton heryanto.

local cjson = require "cjson"
local upload = require "resty.upload"
local new_tab = require "table.new"
local split = require "resty.stack.utils".split
local open = io.open
local sub  = string.sub
local len = string.len
local find = string.find
local get_headers = ngx.req.get_headers
local var = ngx.var

local _M = new_tab(0,1)
local needle = 'filename="'
local needle_len = len(needle)
local name_pos = 18 -- 'form-data; name="':len()

local function decode_disposition(self, data)
  local last_quote_pos = len(data) - 1
  local filename_pos = find(data, needle)
  
  if not filename_pos then return sub(data,name_pos,last_quote_pos) end

  local field = sub(data,name_pos,filename_pos - 4) 
  local name = sub(data,filename_pos + needle_len, last_quote_pos)
  
  if name == "" then return end
  local path = "files/" 
  if self.get_path then
    path, name = self.get_path(self, name, field)
  end

  local filename = path .. name
  local handler = open(filename, "w+")

  if not handler then ngx.log(ngx.WARN,"failed to open file ", filename) end

  return field, name, handler
end


local function multipart(self)  
  local chunk_size = 8192
  local form,err = upload:new(chunk_size)

  if not form then
    ngx.log(ngx.WARN, "failed to new upload: ", err)
    return 
  end
  
  local m = { files = {} }
  local handler, key, value
  
  while true do
    local ctype, res, err = form:read()
  
    if not ctype then 
      ngx.log(ngx.WARN,"failed to read: ", err) 
      return 
    end
    
    if ctype == "header" then
      local header, data = res[1], res[2]

      if header == "Content-Disposition" then
        key, value, handler = decode_disposition(self, data)

        if handler then m.files[key] = { name = value } end

      end
      
      if handler and header == "Content-Type" then
        m.files[key].mime = data 
      end
    end
      
    if ctype == "body" then
      if handler then
        handler:write(res)
      elseif res ~= "" then
        value = value and value .. res or res
      end
    end
      
    if ctype == "part_end" then
      if handler then 
        m.files[key].size = handler:seek("end")
        handler:close()
      elseif key then
        m[key] = value
        key = nil
        value = nil
      end
    end
    
    if ctype == "eof" then break end

  end
  return m
end

-- proses post based on content type
function _M.get(self)
  local header = get_headers()
  if not header or not header["content-type"] then return end

  local ctype = header["content-type"]
  
  if ctype:find("multipart") then
    return multipart(self)
  end

  ngx.req.read_body()

  if ctype:find("json") then
    local body = var.request_body
    return body and cjson.decode(body) or {}
  end

  return ngx.req.get_post_args()
end

return _M

