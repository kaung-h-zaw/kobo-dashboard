local source = debug.getinfo(1, "S").source:gsub("^@", "")
local app_dir = source:match("^(.*)/[^/]+$") or "."
package.path = app_dir .. "/?.lua;" .. app_dir .. "/lib/?.lua;" .. app_dir .. "/pages/?.lua;" .. package.path

local Config = require("config")
local Gestures = require("gestures")
local Input = require("input")
local Logger = require("logger")
local Navigation = require("navigation")
local Renderer = require("renderer")
local Screen = require("screen")
local State = require("state")

local config = Config.load(app_dir .. "/config.json")
local logger = Logger.new(app_dir .. "/debug.log", config.Debug)
local screen = Screen.new(app_dir, config, logger)
local state = State.new(app_dir .. "/state-data.lua", config, logger)
local renderer = Renderer.new(screen)
local gestures = Gestures.new(config)

local page_order = { "weather", "calendar", "home", "reminders", "kanban" }
local pages = {
    weather = require("weather"),
    calendar = require("calendar"),
    home = require("home"),
    reminders = require("reminders"),
    kanban = require("kanban"),
}

local navigation = Navigation.new(page_order, state.currentPage, config.WrapPages)
local targets = {}
local running = true

local function render_page()
    state.currentPage = navigation:current()
    targets = pages[state.currentPage].draw(renderer, state, navigation.index, #page_order)
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

local function handle_tap(x, y)
    for index = #targets, 1, -1 do
        local target = targets[index]
        if contains(target, x, y) then
            if target.kind == "exit" then
                logger:info("Exit requested: button")
                running = false
            elseif target.kind == "reminder" then
                local item = state:toggleReminder(target.id)
                if item then pages.reminders.redrawReminder(renderer, item) end
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

local ok, input_or_error = pcall(Input.new, app_dir, screen, logger)
if not ok then
    logger:error(input_or_error)
    error(input_or_error)
end
local input = input_or_error
local stop_file = "/tmp/kaungdashboard.stop"

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
                change_page(gesture.direction == "left" and 1 or -1)
            elseif gesture.kind == "tap" then
                handle_tap(gesture.x, gesture.y)
            end
        end
    end
end

input:close()
logger:info("App stopped")
os.exit(0)
