package.path = "kobo-app/kaungdashboard/?.lua;kobo-app/kaungdashboard/lib/?.lua;kobo-app/kaungdashboard/pages/?.lua;" .. package.path

local function in_bounds(x, y, width, height)
    assert(x >= 0 and y >= 0, "negative drawing coordinate")
    assert(width >= 0 and height >= 0, "negative drawing size")
    assert(x + width <= 1024, "drawing exceeds screen width")
    assert(y + height <= 758, "drawing exceeds screen height")
end

local screen = {
    app_dir = "kobo-app/kaungdashboard",
    width = 1024,
    height = 758,
}

function screen:clear() end
function screen:refreshFull() end
function screen:refreshPage() end
function screen:refreshRegion(rect) in_bounds(rect.x, rect.y, rect.w, rect.h) end
function screen:fillRect(x, y, width, height) in_bounds(x, y, width, height) end
function screen:drawText(text, x, y, scale)
    -- FBInk's built-in cell fonts are 8x16 before scaling.
    local width, height = #text * 8 * scale, 16 * scale
    in_bounds(x, y, width, height)
    return { x = x, y = y, w = width, h = height }
end
function screen:drawImage(path, x, y, width, height)
    assert(path:match("/assets/[%w%-]+%.png$"), "unexpected image asset: " .. path)
    in_bounds(x, y, width, height)
end

local state = {
    reminders = {
        { id = "reminder-1", group = "TODAY", title = "Finish assignment", due = "Due 18:00", completed = false },
        { id = "reminder-2", group = "TODAY", title = "Buy groceries", completed = false },
        { id = "reminder-3", group = "TODAY", title = "Call family", completed = true },
        { id = "reminder-4", group = "UPCOMING", title = "Apply for internship", completed = false },
        { id = "reminder-5", group = "UPCOMING", title = "Submit portfolio", completed = false },
    },
    kanbanItems = {
        { id = "kanban-1", title = "Finish project report", status = "todo" },
        { id = "kanban-2", title = "Update resume", status = "todo" },
        { id = "kanban-3", title = "Portfolio redesign", status = "in_progress" },
        { id = "kanban-4", title = "Install KOReader", status = "done" },
        { id = "kanban-5", title = "Setup Render server", status = "done" },
    },
    weather = {
        location = "Bangkok", temperature = "31 C", condition = "Partly Cloudy",
        apparentTemperature = "34 C", high = "34 C", low = "27 C",
        humidity = "68%", windSpeed = "9 KM/H",
        forecast = {
            { day = "THU", condition = "CLOUDY", high = "33 C", low = "27 C" },
            { day = "FRI", condition = "RAIN", high = "32 C", low = "26 C" },
            { day = "SAT", condition = "SUNNY", high = "34 C", low = "27 C" },
            { day = "SUN", condition = "CLOUDY", high = "33 C", low = "26 C" },
        },
    },
    events = {
        { time = "09:00", title = "University" },
        { time = "14:00", title = "Project Meeting" },
        { time = "18:30", title = "Study JavaScript" },
    },
    upcomingEvents = {},
    remoteSyncedAt = "LOCAL SAMPLE",
}

function state:kanbanCounts()
    local counts = { todo = 0, in_progress = 0, done = 0 }
    for _, item in ipairs(self.kanbanItems) do counts[item.status] = counts[item.status] + 1 end
    return counts
end

function state:nextEvent() return self.events[1] or self.upcomingEvents[1] end
function state:nextReminder()
    for _, item in ipairs(self.reminders) do if not item.completed then return item end end
end

local Renderer = require("renderer")
local renderer = Renderer.new(screen)
local page_names = { "weather", "calendar", "home", "wifi", "reminders", "kanban" }
local expected_targets = { weather = 2, calendar = 2, home = 2, wifi = 2, reminders = 7, kanban = 7 }
for index, page_name in ipairs(page_names) do
    local page = require(page_name)
    local targets = page.draw(renderer, state, index, #page_names)
    assert(type(targets) == "table", page_name .. " did not return touch targets")
    assert(#targets == expected_targets[page_name], page_name .. " has an unexpected touch-target count")
    local has_reload = false
    for _, target in ipairs(targets) do if target.kind == "reload" then has_reload = true end end
    assert(has_reload, page_name .. " is missing the reload target")
    for _, target in ipairs(targets) do in_bounds(target.x, target.y, target.w, target.h) end
end

local Reminders = require("reminders")
state.reminders[1].completed = true
Reminders.redrawReminder(renderer, state.reminders[1])
renderer:updateReload(true)
renderer:updateReload(false)

local Navigation = require("navigation")
local navigation = Navigation.new(page_names, "weather", true)
local _, wrapped_back = navigation:move(-1)
assert(wrapped_back == "kanban", "backward navigation did not wrap to the last page")
local _, wrapped_forward = navigation:move(1)
assert(wrapped_forward == "weather", "forward navigation did not wrap to the first page")

print("All six page layouts fit within 1024x758 and navigation wraps")
