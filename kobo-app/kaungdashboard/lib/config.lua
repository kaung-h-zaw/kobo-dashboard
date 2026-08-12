local Config = {}

local defaults = {
    Orientation = "landscape-right",
    StartPage = "home",
    WrapPages = true,
    KanbanCycleDoneToTodo = false,
    PartialRefresh = true,
    ClockRefreshMinutes = 1,
    FullRefreshMinutes = 15,
    FetchMinutes = 5,
    ApiUrl = "https://kobo-dashboard-7ub6.onrender.com/api/device-data",
    DeviceTokenFile = "device-token",
    SwipeThreshold = 120,
    TapSlop = 28,
    CornerExitHoldSeconds = 3,
    Debug = true,
}

local function parse_value(source, key, fallback)
    local raw = source:match('"' .. key .. '"%s*:%s*([^,%}%n]+)')
    if not raw then return fallback end
    raw = raw:match("^%s*(.-)%s*$")
    if raw == "true" then return true end
    if raw == "false" then return false end
    local quoted = raw:match('^"(.*)"$')
    if quoted then return quoted end
    return tonumber(raw) or fallback
end

function Config.load(path)
    local file = io.open(path, "r")
    local source = file and file:read("*a") or ""
    if file then file:close() end
    local result = {}
    for key, value in pairs(defaults) do result[key] = parse_value(source, key, value) end
    if result.Orientation ~= "portrait" and result.Orientation ~= "landscape-left"
        and result.Orientation ~= "landscape-right" then
        result.Orientation = defaults.Orientation
    end
    return result
end

return Config
