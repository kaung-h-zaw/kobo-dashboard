local source = debug.getinfo(1, "S").source:gsub("^@", "")
local app_dir = source:match("^(.*)/[^/]+$") or "."
package.path = app_dir .. "/?.lua;" .. app_dir .. "/lib/?.lua;" .. app_dir .. "/pages/?.lua;" .. package.path

local Config = require("config")
local Api = require("api")
local Gestures = require("gestures")
local Input = require("input")
local Logger = require("logger")
local Navigation = require("navigation")
local Renderer = require("renderer")
local Screen = require("screen")
local State = require("state")

local config = Config.load(app_dir .. "/config.json")
local logger = Logger.new(app_dir .. "/debug.log", config.Debug)
local api = Api.new(app_dir, config, logger)
local screen = Screen.new(app_dir, config, logger)
local state = State.new(app_dir .. "/state-data.lua", config, logger)
local cached_remote = api:loadCache()
if cached_remote then state:applyRemote(cached_remote) end
local renderer = Renderer.new(screen)
local gestures = Gestures.new(config)

local page_order = { "weather", "calendar", "home", "wifi", "reminders", "kanban" }
local pages = {
    weather = require("weather"),
    calendar = require("calendar"),
    home = require("home"),
    wifi = require("wifi"),
    reminders = require("reminders"),
    kanban = require("kanban"),
}

local navigation = Navigation.new(page_order, state.currentPage, config.WrapPages)
local targets = {}
local running = true
local clock_partial_count = 0
local fetch_seconds = math.max(1, tonumber(config.FetchMinutes) or 5) * 60
local last_fetch_started = 0

local function render_page()
    state.currentPage = navigation:current()
    targets = pages[state.currentPage].draw(renderer, state, navigation.index, #page_order)
    clock_partial_count = 0
end

local function contains(target, x, y)
    return x >= target.x and x <= target.x + target.w and y >= target.y and y <= target.y + target.h
end

local function change_page(delta)
    local old, next_page, changed = navigation:move(delta)
    if not changed then return end
    state.currentPage = next_page
    logger:info("Page changed: " .. old .. " -> " .. state.currentPage)
    render_page()
end

local function request_fetch(force_sync)
    if api:startFetch(force_sync) then
        last_fetch_started = os.time()
        renderer:updateReload(true)
        return true
    end
    return false
end

local function handle_tap(x, y)
    for index = #targets, 1, -1 do
        local target = targets[index]
        if contains(target, x, y) then
            if target.kind == "exit" then
                logger:info("Exit requested: button")
                running = false
            elseif target.kind == "reload" then
                logger:info("Manual reload requested")
                request_fetch(true)
            elseif target.kind == "reminder" then
                local item = state:toggleReminder(target.id)
                if item then
                    pages.reminders.redrawReminder(renderer, item)
                    api:setReminderCompleted(item.id, item.completed)
                end
            elseif target.kind == "kanban" and state:advanceKanban(target.id) then
                render_page()
            end
            return
        end
    end
end

logger:info("App started")
logger:info("Detected Kobo Nia profile")
logger:info("Framebuffer target: 758x1024")
screen:setOrientation()
render_page()
request_fetch()

local ok, input_or_error = pcall(Input.new, app_dir, screen, logger)
if not ok then
    logger:error(input_or_error)
    error(input_or_error)
end
local input = input_or_error
local stop_file = "/tmp/kaungdashboard.stop"
local refresh_minutes = math.max(1, tonumber(config.ClockRefreshMinutes) or 1)
local full_refresh_minutes = math.max(refresh_minutes, tonumber(config.FullRefreshMinutes) or 15)
local full_refresh_after = math.max(1, math.floor(full_refresh_minutes / refresh_minutes))
local last_clock_bucket = math.floor(os.time() / (refresh_minutes * 60))
local last_day = os.date("%Y%m%d")
if last_fetch_started == 0 then last_fetch_started = os.time() end

while running do
    local stop = io.open(stop_file, "r")
    if stop then stop:close(); logger:info("Exit requested: stop file"); break end
    local raw_event = input:nextEvent(500)
    if raw_event then
        local gesture = gestures:feed(raw_event)
        if gesture then
            if gesture.kind == "exit" then
                logger:info("Exit requested: " .. gesture.reason)
                running = false
            elseif gesture.kind == "swipe" then
                if state.currentPage == "reminders" and (gesture.direction == "up" or gesture.direction == "down") then
                    pages.reminders.scroll(renderer, state, gesture.direction == "up" and 1 or -1,
                        navigation.index, #page_order)
                elseif gesture.direction == "left" or gesture.direction == "right" then
                    change_page(gesture.direction == "left" and 1 or -1)
                end
            elseif gesture.kind == "tap" then
                handle_tap(gesture.x, gesture.y)
            end
        end
    end
    local remote_data, fetch_finished, remote_changed = api:poll()
    local remote_rendered = remote_data and remote_changed and state:applyRemote(remote_data)
    if remote_rendered then render_page()
    elseif fetch_finished then renderer:updateReload(false) end
    if api.enabled and not api.fetching and os.time() - last_fetch_started >= fetch_seconds then
        request_fetch()
    end
    local clock_bucket = math.floor(os.time() / (refresh_minutes * 60))
    if clock_bucket ~= last_clock_bucket then
        last_clock_bucket = clock_bucket
        local day = os.date("%Y%m%d")
        if state.currentPage == "home" and day ~= last_day then
            render_page()
        else
            clock_partial_count = clock_partial_count + 1
            local force_full = clock_partial_count >= full_refresh_after
            renderer:updateClock(force_full)
            if force_full then clock_partial_count = 0 end
        end
        last_day = day
    end
end

api:stop()
input:close()
logger:info("App stopped")
os.exit(0)
