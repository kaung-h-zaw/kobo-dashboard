local Json = require("json")

local Api = {}
Api.__index = Api

local function shell_quote(value)
    return "'" .. tostring(value):gsub("'", "'\"'\"'") .. "'"
end

local function read_file(path)
    local file = io.open(path, "rb")
    if not file then return nil end
    local contents = file:read("*a")
    file:close()
    return contents
end

local function write_file(path, contents)
    local file = io.open(path, "wb")
    if not file then return false end
    file:write(contents)
    file:close()
    return true
end

local function trim(value)
    return value and value:match("^%s*(.-)%s*$") or ""
end

local function json_string(value)
    return '"' .. tostring(value):gsub('\\', '\\\\'):gsub('"', '\\"')
        :gsub('\n', '\\n'):gsub('\r', '\\r'):gsub('\t', '\\t') .. '"'
end

local function fingerprint(data)
    local parts = { tostring(data.syncedAt or "") }
    local weather = data.weather or {}
    for _, key in ipairs({ "location", "temperature", "condition", "apparentTemperature", "high", "low", "humidity", "windSpeed" }) do
        parts[#parts + 1] = tostring(weather[key] or "")
    end
    for _, day in ipairs(weather.forecast or {}) do
        parts[#parts + 1] = table.concat({ tostring(day.day or ""), tostring(day.condition or ""), tostring(day.high or ""), tostring(day.low or "") }, "|")
    end
    for _, collection in ipairs({ data.events or {}, data.upcomingEvents or {}, data.reminders or {} }) do
        for _, item in ipairs(collection) do
            parts[#parts + 1] = table.concat({
                tostring(item.id or ""), tostring(item.group or ""), tostring(item.time or ""),
                tostring(item.title or ""), tostring(item.due or ""), tostring(item.completed or false),
            }, "|")
        end
    end
    return table.concat(parts, "\31")
end

function Api.new(app_dir, config, logger)
    local token_path = app_dir .. "/" .. (config.DeviceTokenFile or "device-token")
    local token = trim(read_file(token_path))
    local url = trim(config.ApiUrl)
    local enabled = url ~= "" and token ~= "" and token ~= "REPLACE_WITH_DEVICE_API_KEY"
    local self = setmetatable({
        app_dir = app_dir,
        logger = logger,
        url = url,
        token = token,
        enabled = enabled,
        fetching = false,
        cache_path = app_dir .. "/remote-data.json",
        download_path = "/tmp/kaungdashboard-device-data.json",
        status_path = "/tmp/kaungdashboard-device-data.status",
        pid_path = "/tmp/kaungdashboard-curl.pid",
    }, Api)
    if not enabled then logger:error("Remote data disabled: device-token is missing or ApiUrl is empty") end
    return self
end

function Api:decode(contents)
    local ok, data = pcall(Json.decode, contents or "")
    if not ok or type(data) ~= "table" or data.version ~= 1 then
        self.logger:error("Remote data rejected: invalid device-data JSON")
        return nil
    end
    return data
end

function Api:loadCache()
    local contents = read_file(self.cache_path)
    if not contents then return nil end
    local data = self:decode(contents)
    if data then
        self.fingerprint = fingerprint(data)
        self.logger:info("Loaded cached remote data")
    end
    return data
end

function Api:startFetch()
    if not self.enabled or self.fetching then return false end
    os.remove(self.download_path)
    os.remove(self.status_path)
    os.remove(self.pid_path)
    local curl = "curl --fail --silent --show-error --location --connect-timeout 10 --max-time 30"
        .. " -H " .. shell_quote("access-token: " .. self.token)
        .. " -H " .. shell_quote("Accept: application/json")
        .. " -o " .. shell_quote(self.download_path)
        .. " " .. shell_quote(self.url)
    local connect_wifi = "sh " .. shell_quote(self.app_dir .. "/connect-wifi.sh") .. " >/dev/null 2>&1 || true; "
    local worker = connect_wifi .. curl .. "; result=$?; echo $result > " .. shell_quote(self.status_path)
    local launch = "(" .. worker .. ") >/dev/null 2>&1 & echo $! > " .. shell_quote(self.pid_path)
    local result = os.execute(launch)
    self.fetching = result == true or result == 0
    if self.fetching then self.logger:info("Remote data fetch started")
    else self.logger:error("Unable to start remote data fetch") end
    return self.fetching
end

function Api:setReminderCompleted(id, completed)
    if not self.enabled then
        self.logger:error("Reminder completion not sent: remote data is disabled")
        return false
    end
    local payload = '{"id":' .. json_string(id) .. ',"completed":' .. tostring(completed == true) .. '}'
    local curl = "curl --fail --silent --show-error --location --connect-timeout 10 --max-time 30"
        .. " -X POST -H " .. shell_quote("access-token: " .. self.token)
        .. " -H " .. shell_quote("Content-Type: application/json")
        .. " --data " .. shell_quote(payload)
        .. " " .. shell_quote(self.url:gsub("/device%-data/?$", "/reminder-actions"))
    local command = "(" .. curl .. " >>" .. shell_quote(self.logger.path) .. " 2>&1"
        .. " && echo ' reminder action queued' >>" .. shell_quote(self.logger.path)
        .. ") >/dev/null 2>&1 &"
    local result = os.execute(command)
    self.logger:info("Reminder completion upload started: " .. tostring(id) .. " completed=" .. tostring(completed))
    return result == true or result == 0
end

function Api:poll()
    if not self.fetching then return nil, false end
    local status = trim(read_file(self.status_path))
    if status == "" then return nil, false end
    self.fetching = false
    os.remove(self.status_path)
    os.remove(self.pid_path)
    if status ~= "0" then
        os.remove(self.download_path)
        self.logger:error("Remote data fetch failed with curl status " .. status)
        return nil, true
    end
    local contents = read_file(self.download_path)
    os.remove(self.download_path)
    local data = self:decode(contents)
    if not data then return nil, true end
    local next_fingerprint = fingerprint(data)
    local changed = next_fingerprint ~= self.fingerprint
    self.fingerprint = next_fingerprint
    local temporary_cache = self.cache_path .. ".tmp"
    if write_file(temporary_cache, contents) then
        os.remove(self.cache_path .. ".old")
        os.rename(self.cache_path, self.cache_path .. ".old")
        os.rename(temporary_cache, self.cache_path)
    end
    self.logger:info("Remote data fetch completed")
    return data, true, changed
end

function Api:stop()
    local pid = tonumber(trim(read_file(self.pid_path)))
    if pid and pid > 1 then
        os.execute("pkill -TERM -P " .. pid .. " >/dev/null 2>&1 || true")
        os.execute("kill -TERM " .. pid .. " >/dev/null 2>&1 || true")
    end
    os.remove(self.download_path)
    os.remove(self.status_path)
    os.remove(self.pid_path)
    self.fetching = false
end

return Api
