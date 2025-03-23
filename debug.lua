local core = require "core"
local credentials = require "_env"
local username = credentials.username
local password = credentials.password

local verbose = function() end
if true then
    verbose = function(...) print(...) end
end

local function print_table(t)
    if #t > 1 then
        for k, v in ipairs(t) do
            print_table(v)
        end
    else
        for k, v in pairs(t) do
            print(k, v)
        end
    end
end

local function write_cache_to_disk(login_res_data)
    local f = assert(io.open("cache.lua", "w"))
    local s = [[
        return {
            access_token="%s",
            till=%d,
            till_formatted="%s",
            session_id="%s"
        }
    ]]
    local until_ts = os.time() + tonumber(login_res_data.expires)
    f:write(s:format(login_res_data.access_token, until_ts, os.date("%d. %b %X", until_ts), login_res_data.session_id))
    f:close()
    return login_res_data.access_token
end

local cache_exists, auth_data = pcall(function() return require "cache" end)
if not cache_exists then
    verbose("No Cache found, create one!")
    write_cache_to_disk(core.login(username, password))
    auth_data = require "cache"
elseif auth_data.till < os.time() then
    verbose("Cached access_token invalid, refresh cache!")
    auth_data.access_token = write_cache_to_disk(core.login(username, password))
elseif auth_data.till - 2700 < os.time() then
    verbose("Should refresh, should implement")
else
    verbose("Cache successfully loaded!")
end
local access_token = auth_data.access_token

-- so much lines, just for caching access_tokens
-- setup is done
-- call core methods here
local me = core.me(access_token)
print_table(me)
