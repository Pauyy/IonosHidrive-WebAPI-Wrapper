local requests = require('requests')

-- Util
-- The given table is only allowed to contains passed keys
local function assertOnlyContainAllowedKeys(t, keys)
    -- Convert "Array" to "Map"
    for k, v in ipairs(keys) do keys[v] = true end

    for key, _ in pairs(t) do
        if type(key) ~= nil then
            assert(keys[key], "The given table contains the forbidden key " .. string.format("%q", key) .. " but the only allowed keys are " .. table.concat(keys, ", "))
        end
    end
end

local core = {}
local _core = {}

-- TODO support numbers
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

function _core.delete(access_token, endpoint, body)
    body = body or {}
    assert(access_token)
    local header = {
        Authorization = "Bearer " .. access_token,
        ["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:134.0) Gecko/20100101 Firefox/134.0",
        ["Content-Type"] = "application/x-www-form-urlencoded; charset=UTF-8"
    }
    local res = requests.delete { url = endpoint, headers = header, data = body }
    return res
end

function _core.put(access_token, endpoint, body, params)
    body = body or {}
    assert(access_token)
    local header = {
        Authorization = "Bearer " .. access_token,
        ["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:134.0) Gecko/20100101 Firefox/134.0",
        ["Content-Type"] = "application/x-www-form-urlencoded; charset=UTF-8"
    }
    -- Right now Params are only used in a put request when uploading files. Uploading Files does not have a specific Content-Type
    -- Hardcoding it this way will backfire, but well
    if params then
        header["Content-Type"] = nil
    else
        params = {}
    end

    local res = requests.put { url = endpoint, headers = header, data = body, params = params }
    return res
end

function _core.patch(access_token, endpoint, body, params)
    body = body or {}
    params = params or {}
    assert(access_token)
    local header = {
        Authorization = "Bearer " .. access_token,
        ["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:134.0) Gecko/20100101 Firefox/134.0",
    }
    local res = requests.patch { url = endpoint, headers = header, data = body, params = params }
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

-- path with parent_id is also valid
function core.get_dir(access_token, path, sort, ok_response_codes)
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

-- Create a dir inside a parent directorie
-- pid as id (id of the folder in which a new folder should be created)
-- name as string (name of the folder to be created)
function core.create_dir(access_token, pid, name)
    local data = {
        pid = pid,
        path = name,
        on_exist = "autoname"
    }
    local data_encoded = _core.url_form_encode(data)
    return _core.post(access_token, "https://hidrive.ionos.com/api/dir", data_encoded)
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
-- Takes access token and 'file_id' or 'directory id and filename'
-- Return tables containing "chash": SHA-1 Hash, "id": b%d.%d, "name": string, "mtime": timestamp, "size": bytes, "writable": boolean
-- ]]
function core.meta(access_token, file_id, name)
    local params = {
        fields = "id,chash,ctime,mtime,name,size,readable,writable",
        pid = file_id,
        path = name
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
   local data = {
       name = new_name,
       pid = file_id
   }
   local data_encoded = _core.url_form_encode(data)
   return _core.post(access_token, "https://hidrive.ionos.com/api/file/rename", data_encoded)
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

-- Determines if a file share should be created, updated, deleted or send by mail based on on the properties of the passed parameters
function core.file_share(access_token, _id, data, message)
    assert(_id, "Some sort of identification is needed")
    if message ~= nil then
        return core.mail_file_share(access_token, _id, data, message)
    elseif data ~= nil then
        return core.update_file_share(access_token, _id, data)
    elseif _id:match("b%d+%.%d+") then
        return core.create_file_share(access_token, _id)
    else
        return core.delete_file_share(access_token, _id)
    end
end

-- Share a single File
-- Folder Shares have different uri and different paramters than file Shares
function core.create_file_share(access_token, pid)
   assert(pid)
   local data = {
       pid= pid,
       type= "file"
   }
   local data_encoded = _core.url_form_encode(data)
   return _core.post(access_token, "https://hidrive.ionos.com/api/sharelink", data_encoded)
end

-- ID that references the share -> https://hidrive.ionos.com/lnk/{id}
-- Folder Shares have different uri and different paramters than file Shares
function core.delete_file_share(access_token, id)
   assert(id)
   local data = {
       id= id
   }
   local data_encoded = _core.url_form_encode(data)
   return _core.delete(access_token, "https://hidrive.ionos.com/api/sharelink", data_encoded)
end

-- Update properties of a folder share
-- id as in lnk/{id}
-- data as table with 
-- password: string (the password for the share)
-- ttl: seconds (how long the share should be available, must be larger or equal than 86400)
-- maxcount: int or empty string (maximum of allowed downloads or infinite)
function core.update_file_share(access_token, id, data)
    assert(id)
    assertOnlyContainAllowedKeys(data, {"password", "ttl", "maxcount"})
    data["id"] = id
    local data_encoded = _core.url_form_encode(data)
    return _core.put(access_token, "https://hidrive.ionos.com/api/sharelink", data_encoded)
end

-- Sends the share as an email
-- id as in lnk/{id}
-- recipient: mail (the mail to wich should recive the share)
-- msg: string (the message in the mail)
function core.mail_file_share(access_token, id, recipient, msg)
    assert(id)
    assert(recipient)
    local data = {
        id = id,
        recipient = recipient,
        msg = msg,
        lang = "de"
    }
    local data_encoded = _core.url_form_encode(data)
    return _core.post(access_token, "https://hidrive.ionos.com/api/sharelink/invite", data_encoded)
end

-- Determines if a file share should be created, updated, deleted or send by mail based on on the properties of the passed parameters
function core.folder_share(access_token, _id, data, message)
    assert(_id, "Some sort of identification is needed")
    if message ~= nil then
        return core.mail_folder_share(access_token, _id, data, message)
    elseif data ~= nil then
        return core.update_folder_share(access_token, _id, data)
    elseif _id:match("b%d+%.%d+") then
        return core.create_folder_share(access_token, _id)
    else
        return core.delete_folder_share(access_token, _id)
    end
end

-- [[
-- Shares a folder
-- Folder Shares have different uri and different paramters than file Shares
--
-- Takes access token, file_id
-- Return tables containing "status": string, "share_type": string, "wopi": boolean, "size": int, "viewmode": string, "pid": b%d.%d, "is_encrypted": boolean, "id": string, "has_password": boolean,
-- "readable": boolean, "count": int, "writable": boolean, "last_modified": timestamp, "path": string, "mime_type": string, "uri": uri, "file_type": string, "created": timestamp
-- ]]
function core.create_folder_share(access_token, file_id)
   assert(file_id)
   local data = {
       viewmode = "a",
	   pid = file_id
   }
   local data_encoded = _core.url_form_encode(data)
   print(data_encoded)
   return _core.post(access_token, "https://hidrive.ionos.com/api/share", data_encoded)
end


-- [[
-- Removes the share of a folder
-- Folder shares have different uri and different paramters than file shares
--
-- Takes access token, id as in /lnk/{id}
-- Return tables containing "status": string, "share_type": string, "wopi": boolean, "size": int, "viewmode": string, "pid": b%d.%d, "is_encrypted": boolean, "id": string, "has_password": boolean,
-- "readable": boolean, "count": int, "writable": boolean, "last_modified": timestamp, "path": string, "mime_type": string, "uri": uri, "file_type": string, "created": timestamp
-- ]]
function core.delete_folder_share(access_token, id)
   assert(id)
   local data = {
       id = id
   }
   local data_encoded = _core.url_form_encode(data)
   print(data_encoded)
   return _core.delete(access_token, "https://hidrive.ionos.com/api/share", data_encoded)
end

-- Update properties of a folder share
-- id as in lnk/{id}
-- data as table with 
-- writable: boolean (if anyone should be allowed to change file)
-- password: string (the password for the share)
-- ttl: seconds (how long the share should be available, must be larger or equal than 86400)
-- viewmode: "a" or "b" or "c"
function core.update_folder_share(access_token, id, data)
    assert(id)
    assertOnlyContainAllowedKeys(data, {"writable", "password", "ttl", "viewmode"})
    data["id"] = id
    local data_encoded = _core.url_form_encode(data)
    return _core.put(access_token, "https://hidrive.ionos.com/api/share", data_encoded)
end

-- Sends the share as an email
-- id as in lnk/{id}
-- recipient: mail (the mail to wich should recive the share)
-- msg: string (the message in the mail)
function core.mail_folder_share(access_token, id, recipient, msg)
    assert(id)
    assert(recipient)
    local data = {
        id = id,
        recipient = recipient,
        msg = msg,
        lang = "de"
    }
    local data_encoded = _core.url_form_encode(data)
    return _core.post(access_token, "https://hidrive.ionos.com/api/share/invite", data_encoded)
end

-- Create a share to upload data into the provided path
-- path: path (in wich data can be uploaded)
-- data as table with 
-- maxsize: int like 2147483647, 1073741824, 524288000, 104857600, 10485760 (size in bit or somtehing like that)
-- password: string (password with wich the share is secured)
-- ttl: int (seconds the share is valid)
-- maxcount: int (max number of allowed uploads)
function core.create_share_upload(access_token, path, data)
    assert(path)
    assertOnlyContainAllowedKeys(data, {"maxsize", "password", "ttl", "maxcount"})
    data["path"] = path
    data["type"] = "dir"
    local data_encoded = _core.url_form_encode(data)
    return _core.post(access_token, "https://hidrive.ionos.com/api/shareupload", data_encoded)
end


-- id as in /upl/{id}
-- data as table with 
-- maxsize: int maximum 2147483647 (size in bit or somtehing like that)
-- password: string (password with wich the share is secured)
-- ttl: int (seconds the share is valid)
-- maxcount: int (max number of allowed uploads)
function core.update_share_upload(access_token, id, data)
    assert(id)
    assertOnlyContainAllowedKeys(data, {"maxsize", "password", "ttl", "maxcount"})
    data["id"] = id
    local data_encoded = _core.url_form_encode(data)
    return _core.put(access_token, "https://hidrive.ionos.com/api/shareupload", data_encoded)
end

-- Deletes a share upload
-- id as in /upl/{id}
function core.delete_share_upload(access_token, id)
    assert(id)
    local data = {
        id = id
    }
    local data_encoded = _core.url_form_encode(data)
    return _core.delete(access_token, "https://hidrive.ionos.com/api/shareupload", data_encoded)
end

-- Creates a Mail Upload
-- path: path (in wich data will be uploaded)
-- data as table with
-- overwrite: true (if duplicate file names should be overwritten)
-- reportok: true (if mail should be returned to uploader with status)
-- reportto: "email" (if mail should be send to account owner that someone uploaded something)
-- subfolder: true (if a subfolder per uploader should be created)
-- ttl: int (seconds the share is valid)
function core.create_mail_upload(access_token, path, data)
    assert(path)
    assertOnlyContainAllowedKeys(data, {"overwrite", "reportok", "reportto", "subfolder", "ttl"})

    local unique_data =  _core.get(access_token, "https://hidrive.ionos.com/api/unique").json()
    print("Here unique", unique_data)
    data["unique"] = unique_data["unique"]
    data["unique_mac"] = unique_data["unique_mac"]

    data["path"] = path
    data["type"] = "dir"
    local data_encoded = _core.url_form_encode(data)
    return _core.post(access_token, "https://hidrive.ionos.com/api/mailupload", data_encoded)
end

-- Update Mail Uplaod
-- overwrite: boolean (if duplicate file names should be overwritten)
-- reportok: boolean (if mail should be returned to uploader with status)
-- reportto: "email" or "none" (if mail should be send to account owner that someone uploaded something)
-- subfolder: boolean (if a subfolder per uploader should be created)
-- ttl: int (seconds the share is valid)
function core.update_mail_upload(access_token, path, data)
    assert(path)
    assertOnlyContainAllowedKeys(data, {"overwrite", "reportok", "reportto", "subfolder", "ttl"})

    data["path"] = path
    local data_encoded = _core.url_form_encode(data)
    return _core.put(access_token, "https://hidrive.ionos.com/api/mailupload", data_encoded)
end

-- Deletes a Mail Upload
-- path as path
function core.delete_mail_upload(access_token, path)
    assert(path)
    local data = {
        path = path
    }
    local data_encoded = _core.url_form_encode(data)
    return _core.delete(access_token, "https://hidrive.ionos.com/api/mailupload", data_encoded)
end

-- Zip Multiple Files
-- dst as path (where the zip should be located and wich name it should have)
-- src as table with paths (wich files should be zipped together)
function core.zip(access_token, dst, src)
    assert(type(dst) == "string")
    assert(type(src) == "table")
    local data = {
        dst = dst,
        src = src
    }
    local data_encoded = _core.url_form_encode(data)
    return _core.post(access_token, "https://hidrive.ionos.com/api/file/archive/deflate", data_encoded)
end

-- Uploads a given string as bytes
function _core.upload_file_bytes(access_token, bytes, dir_id, filename, file_creation_time)
    local params = {
        dir_id = dir_id,
        name = filename,
        mtime = file_creation_time
    }
    return _core.put(access_token, "https://hidrive.ionos.com/api/file", bytes, params)
end

-- Uploads a given file
function _core.upload_file_filehandle(access_token, file, dir_id, filename, file_creation_time)
    local temp_filename = filename .. os.date("%Y%m%d%H%M%S", os.time()) .. ".webupload"
    local params = {
        dir_id = dir_id,
        name = temp_filename,
        mtime = file_creation_time
    }
    local bytes = file:read(5242880)
    print("Start File Upload")
    local response = {}
    -- Upload First 5mb of file
    local upload_response = _core.put(access_token, "https://hidrive.ionos.com/api/file", bytes, params)
    table.insert(response, upload_response)
    --extract the id of the uploaded file to append missing data
    local id = response[1].json()["id"]
    local finished_bytes = 5242880
    while true do
        -- Read next 5mb of file
        bytes = file:read(5242880)
        if not bytes then break end
        params = {
            pid = id,
            offset = finished_bytes,
            mtime = file_creation_time
        }
        -- "Patch" uploaded file with next 5mb of data
        local patch_response = _core.patch(access_token, "https://hidrive.ionos.com/api/file", bytes, params)
        table.insert(response, patch_response)
        --update offset
        finished_bytes = finished_bytes + 5242880
    end
    file:close()
    if response[#response].status_code == 204 then
        local rename_response = core.rename(access_token, id, filename)
        table.insert(response, rename_response)
    end
    return response
end

-- Generic Upload Function that takes a string or file and decides how to correctly upload them
-- File Upload will happen in 5mb batches
-- file as string or file (the data that will be uploaded)
-- Takes dir_id as id (of dir to upload)
-- Filename as string (the name the file will have after download)
-- file_creation_time as int (unix timestamp)
function core.upload_file(access_token, file, dir_id, filename, file_creation_time)
    local meta = core.meta(access_token, dir_id, filename)
    if meta.status_code ~= 404 then
        assert(nil, "File with name " .. filename .. " already exists in directory.\nID: " .. meta.json().id)
    end
    if type(file) == "userdata" then
        return _core.upload_file_filehandle(access_token, file, dir_id, filename, file_creation_time)
    elseif type(file) == "string" then
        return _core.upload_file_bytes(access_token, file, dir_id, filename, file_creation_time)
    end
    assert(nil, "passed file type neither a filehandler or string")
end

return core
