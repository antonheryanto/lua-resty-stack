-- Copyright (C) Anton heryanto.

ngx.req.read_body()
local var = ngx.var
local say = ngx.say
local args, err = ngx.req.get_post_args()
local code = args.code or ''

local template = [[
<form method="post">
  <textarea name="code" rows="10" style="width:100%;font-size:14px">]]..code..[[</textarea>
  <button>Run</button>
</form>
<hr>
]]
-- if not code or code == "" then ngx.say("please provide code") return end

say(template)
func = loadstring(code)
if type(func) ~= "function" then 
    say("syntax error")
    return
end

local ok,o = pcall(func)
say("<pre>",o,"</pre>")
