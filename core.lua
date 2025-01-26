local requests = require('requests')

local core = {}
local _core = {}

function _core.url_form_encode(params)
    local encoded = {}
    assert(type(params) == 'table', 'Expected a table to url form encode and not a ' .. type(params))
    for k, v in pairs(params) do
        -- Making this recursive might be better, but I think it wil work for now
        if type(v) == 'table' then
            for _, val in ipairs(v) do
                k = k:gsub("([^%w-_%.~])", function(c)
                    return string.format("%%%02X", string.byte(c))
                end)
                val = val:gsub("([^%w-_%.~])", function(c)
                    return string.format("%%%02X", string.byte(c))
                end)
                table.insert(encoded, string.format("%s=%s&", k, val))
            end
        else
            k = k:gsub("([^%w-_%.~])", function(c)
                return string.format("%%%02X", string.byte(c))
            end)
            v = v:gsub("([^%w-_%.~])", function(c)
                return string.format("%%%02X", string.byte(c))
            end)
            table.insert(encoded, string.format("%s=%s&", k, v))
        end
    end
    return table.concat(encoded, ''):sub(1, -2)
end

function _core.format_get_params(params)
   assert(type(params) == 'table')
   error("Not implemented")
   return ""
end

function _core.switch_table_values_with_keys(t)
    local r = {}
    for _,v in ipairs(t) do
        r[v] = true
    end
    return r
end

function _core.get(access_token, endpoint, params)
    params = params or {}
    assert(access_token)
    local header = {
        Authorization = "Bearer " .. access_token,
        ["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:134.0) Gecko/20100101 Firefox/134.0"
    }
    local res = requests.get { url = endpoint, headers = header, params = params }
    return res
end

-- TODO Merge get and post
function _core.post(access_token, endpoint, body)
    body = body or {}
    assert(access_token)
    local header = {
        Authorization = "Bearer " .. access_token,
        ["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:134.0) Gecko/20100101 Firefox/134.0",
        ["Content-Type"] = "application/x-www-form-urlencoded; charset=UTF-8"
    }
    local res = requests.post { url = endpoint, headers = header, data = body }
    return res
end



-- [[
-- Log into and hidrive account
--
-- Takes username and password
-- Return table with "session_id", "access_token", "status", "expires"
-- ]]
function core.login(username, password)
    -- Ionos uses a 'jsst' for the login
    -- It is retrived by quering their jsst route with a callback
    -- contained of 20 random letters
    local chars = 'abcdefghijklmnopqrstuvwxyz'
    local callback_value = ""
    for i = 1, 20 do
        local j = math.random(1, #chars)
        callback_value = callback_value .. chars:sub(j, j)
    end
    local jsst_res = requests.get("https://hidrive.ionos.com/auth/jsst?callback=_" .. callback_value)
    -- The Response is a js function on which we are interested in the returned static string
    -- Find Position of the string in the repsonse, then extract only that and trim the quotes
    local jsst = jsst_res.text:sub(jsst_res.text:find('".-"')):sub(2, -2)

    local headers = {
        ["Content-Type"] = "application/x-www-form-urlencoded; charset=UTF-8"
    }
    local data = {
        username = username,
        password = password,
        jsst = jsst
    }
    local login_res = requests.post { url = "https://hidrive.ionos.com/auth/login", data = _core.url_form_encode(data), headers = headers }
    assert(login_res.status_code == 200, login_res.text)
    return login_res.json()
end

-- [[
-- Retrive Information about logged in Account
--
-- Takes access token
-- Return table with "home_id": b%d.%d, "language": string short country code, "email_login": boolean, "account": %d.%d.%d, "has_2fa": boolean, "email_pending": null?
-- "email_verified": boolean, "descr": string, "is_owner": boolean, "email": string, "is-admin": boolean, "alias": string, "home": string as unix path
-- ]]
function core.me(access_token)
    return _core.get(access_token, "https://hidrive.ionos.com/api/user/me?fields=alias%2Caccount%2Cemail%2Cemail_login%2Cemail_pending%2Cemail_verified%2Cdescr%2Clanguage%2Cstatusmail%2Cis_admin%2Cis_owner%2Chome%2Chas_2fa%2Chome_id")
end

-- [[
-- Retrive Information about users specified by their account id
--
-- Takes access token and table of account_ids
-- Return array with tables containing "home_id": b%d.%d, "language": string short country code, "email_login": boolean, "account": %d.%d.%d, "has_2fa": boolean, "email_pending": null?
-- "email_verified": boolean, "descr": string, "is_owner": boolean, "email": string, "is-admin": boolean, "alias": string, "home": string as unix path
-- ]]
function core.user(access_token, account_ids)
    local params = {
        fields= "alias%2Caccount%2Cemail%2Cemail_login%2Cemail_pending%2Cemail_verified%2Cdescr%2Clanguage%2Cstatusmail%2Cis_admin%2Cis_owner%2Chome%2Chas_2fa%2Chome_id",
        account= account_ids,
        scope= "all"
    }
    return _core.get(access_token, "https://hidrive.ionos.com/api/user", params)
end


function core.features(access_token)
    return _core.get(access_token, "https://hidrive.ionos.com/api/features?fields=accounts_max%2Cadmins_max%2Cbackup%2Cencryption%2Cmailupload_enabled%2Cmarket%2Cprotocols%2Csharelink_password%2Csharelink_ttl%2Csharelink_downloads%2Cshareupload_enabled%2Csnapshot_ttl%2Cdoi%2Crollout%2Cwopi")
end

-- [[
-- Retrive Information about features that can be ordered
--
-- Takes access token
-- Return array with tables containing "can_order": boolean, "category": string
-- ]]
function core.orderables(access_token)
    return _core.get(access_token, "https://hidrive.ionos.com/api/status/orderables")
end

function core.zone()
    return _core.get("", "https://hidrive.ionos.com/api/zone?scope=all")
end

function core.dir(access_token, path, sort, ok_response_codes)
    sort = sort or 'none'
    path = path or "/"
    local params = {
        fields= "chash,id,members.category,members.ctime,members.id,members.image.exif.Orientation,members.image.height,members.image.width,members.mime_type,members.mtime,members.name,members.parent_id,members.path,members.readable,members.rshare,members.shareable,members.size,members.teamfolder,members.type,members.writable,path,readable,rshare,shareable,writable",
        path= path,
        members= "all",
        limit = "0,5000",
        sort= sort
    }
    return _core.get(access_token, "https://hidrive.ionos.com/api/dir", params, ok_response_codes)
end

function core.thumbnail(access_token, file_id, refresh_time, width)
    local params = {
        pid= file_id,
        width = width or 140,
        refresh_time = refresh_time or os.time(),
        access_token = access_token
    }
    return _core.get("", "https://hidrive.ionos.com/api/file/thumbnail", params)
end

-- [[
-- Retrive Meta Information about file
--
-- Takes access token and file_id
-- Return tables containing "chash": SHA-1 Hash, "id": b%d.%d, "name": string, "mtime": timestamp, "size": bytes, "writable": boolean
-- ]]
function core.meta(access_token, file_id)
   local params = {
       fields = "id,chash,mtime,name,size,writable",
       pid = file_id
   }
   return _core.get(access_token, "https://hidrive.ionos.com/api/meta", params)
end

-- [[
-- Renames a file, referenced by its file_id to the given name
--
-- Takes access token, file_id and new_name
-- Return tables containing "mhash": SHA-1?, "parent_id": b%d.%d, "size": bytes?, "sharable": boolean, "id": b%d.%d, "category": image or something else as string,
-- "readable": boolean, "ctime": timestamp, "chash": SHA-1?, "writable": boolean, "nhash": SHA-1, "mtime": timestamp", "name": string, "path": string, "mime_type": mime_type,
-- "image": image data -> width, exif -> ImageHeight, ImageWidth, "height": int, "type": file or something else as string
-- ]]
function core.rename(access_token, file_id, new_name)
   local params = {
       name = new_name,
       pid = file_id
   }
   return _core.post(access_token, "https://hidrive.ionos.com/api/file/rename", params)
end

-- [[
-- Moves one or multiple files to a new destination
--
-- Takes access token, file_id(s) and new location
-- Return tables containing with "done" and "failed" containing an array with tables that contain:
-- "ctime": timestmap, "chash": SHA-1, "mhash": SHA-1, "mtime": timestamp, "nhash": SHA-1, "writable": boolean
-- "name": string, "path": string, "parent_id": b%d.%d, "size": bytes?, "mime_type": mime_type as string, "sharable": boolean,
-- "src_id": b%d.%d, "id": b%d.%d, "type": string, "category": string, "readable": boolean
-- ]]
function core.move(access_token, file_ids, new_location)
   assert(file_ids)
   local data = {
       src_id= file_ids,
       dst_id= new_location,
       on_exist= "autoname"
   }
   local data_encoded = _core.url_form_encode(data)
   print(data_encoded)
   return _core.post(access_token, "https://hidrive.ionos.com/api/fs/move", data_encoded)
end



return core
