-- Copyright 2024 vivimice@gmail.com
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

require 'apache2'

function get_cookie_name(r)
    local cookie_name = r.subprocess_env["MOD_COOKIE_AUTH_KEY"]
    if not cookie_name then
        cookie_name = "mcasec"
        r:trace6("MOD_COOKIE_AUTH_KEY request environment not set. using default value: "..cookie_name)
    end
    return cookie_name
end

function get_salt(r)
    local salt = r.subprocess_env["MOD_COOKIE_AUTH_SALT"]
    if salt == nil then
        r:err("MOD_COOKIE_AUTH_SALT request environment not set")
    end
    return salt
end

function get_ttl(r)
    local ttl = tonumber(r.subprocess_env["MOD_COOKIE_AUTH_TTL"])
    if ttl == nil then
        ttl = 3600 * 24
        r:warn("MOD_COOKIE_AUTH_TTL request environment not set. using default value: "..ttl)
    end
    return ttl
end

function get_cookie_secure_flag(r)
    return r.subprocess_env["MOD_COOKIE_AUTH_DISABLE_SECURE_COOKIE"] ~= 'this_is_unsafe'
end

function store_credential(r)
    local salt = get_salt(r)
    if salt == nil then
        return apache2.DECLINED
    end

    local path = r.subprocess_env["MOD_COOKIE_AUTH_PATH"]
    if path == nil then
        r:warn("MOD_COOKIE_AUTH_PATH not set. Using default.")
    end

    local user = r.user
    local realm = r.auth_name
    local now = os.time()
    local checksum = r:md5(salt..user..realm..now)
    local cookie_name = get_cookie_name(r)
    local cookie_value = user..":"..realm..":"..now..":"..checksum
    r:trace8("set cookie. name="..cookie_name..", value="..cookie_value)
    r:setcookie({
        key = cookie_name,
        value = cookie_value,
        secure = get_cookie_secure_flag(r),
        httponly = true,
        path = path,
        expires = now + get_ttl(r)
    })
end

function store(r)
    -- If authentication was made neither by mod_auth_xxx, we save credentials cookies
    if r.ap_auth_type ~= nil then
        store_credential(r)
    end
    return apache2.DECLINED
end

function check(r)
    local salt = get_salt(r)
    if salt == nil then
        return apache2.OK
    end

    local cookie_name = get_cookie_name(r)
    local cookie = r:getcookie(cookie_name)
    if cookie == nil then
        r:trace6("no cookie found. name="..cookie_name)
        return apache2.OK
    end
    cookie = r:unescape(cookie)

    local matches = r:regex(cookie, [[([^:]+):([^:]+):(\d+):([^:]+)]])
    if not matches then
        r:trace6("cookie not match. cookie="..cookie)
        return apache2.OK
    end

    local ttl = get_ttl(r)
    
    local clock = tonumber(matches[3])
    local now = os.time()
    local life = now - clock
    if life > ttl then
        r:debug("expired. clock="..clock..", ttl="..ttl..", now="..now)
        return apache2.OK
    end
    
    local user = matches[1]
    local realm = matches[2]
    local actual_checksum = matches[4]

    local expected_checksum = r:md5(salt..user..realm..clock)
    if expected_checksum ~= actual_checksum then
        r:debug("checksum mismatch. actual="..actual_checksum..", expected="..expected_checksum)
        return apache2.OK
    end

    r:debug("user set. user="..user..", realm="..realm)
    r.user = user

    -- refresh credentials
    store_credential(r)
    
    return apache2.OK
end