# Ionos HiDrive API Wrapper
A Lua Programm that wraps alot of features present in the Ionos HiDrive Web Frontend.

- [X] List Content
- [X] Loging in
- [X] Infos about logged in user
- [X] Infos about specific users
- [X] Features of booked package
- [X] Features of bookable features
- [X] Thumbnail preview for images
- [X] Meta Data bout files
- [X] Rename Files
- [X] Move Files to new Location
- [X] Share Files
- [X] Revoke Share
- [X] Update Share Properties
- [X] Create Share Upload
- [X] Create Mail Upload
- [X] Refresh Session
- [X] Share by Mail
- [X] Get Archive Information
- [X] Zip Files
- [X] Unzip Files
- [X] Delete Files
- [X] Download Files
- [X] Upload Files
- [X] Copy Files


# Usage
Import the library  
` local core = require "core" `  
Generate Access Token  
` local auth_data = core.login(username, password) `  
Extract Access Token  
` local access_token = auth_data.access_token `  
Call any other methods with the access token.  
Per Default the Access Token ist valid for 60 Minutes.  
` local me = core.me(access_token) `
Every Method (except login) will return a table containing
- text: Response
- headers: Table of Response Headers
- status_code
- status
- json: function that, after callings, parsers the Response as json using cjson
- xml: function that, after calling, parsers the Response as xml

# Dependencies
- [lua-requests](https://github.com/JakobGreen/lua-requests)

## Installing Dependencies
`luarocks install lua-requests`  
the xml dependencie of lua-requests could fail. A fix for that is installing it with  
`luarocks install xml STDCPP_LIBDIR=/system/lib`  
and then rerun  
`luarocks install lua-requests`  
If you install it into user space there is a posibility that you have to setup the env correctly  
`eval "$(luarocks path --bin)"`  

# Developing
For ease of developing there is a file called `debug.lua` it
implements simple generating and caching of the access_token.  
To use it, create a file called `_env.lua` with contents as 
```lua 
return {
    username = "your login name",
    password = "your password"
}
```
After the first usage it will create a file called `cache.lua` wich contains the access_token and other usefull information.  
The Debug File loads the core library. To call and test any Methods use `local res = core.any_method()`  

## With Docker
Using `docker compose up` will start execute `debug.lua` in a docker container.


