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
function screen:refreshRegion(rect) in_bounds(rect.x, rect.y, rect.w, rect.h) end
function screen:fillRect(x, y, width, height) in_bounds(x, y, width, height) end
function screen:drawText(text, x, y, scale)
    local width, height = #text * 8 * scale, 8 * scale
    in_bounds(x, y, width, height)
    return { x = x, y = y, w = width, h = height }
end
function screen:drawImage(path, x, y, width, height)
    assert(path:match("/assets/wifi%-%d+ghz%.png$"), "unexpected image asset: " .. path)
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
}

function state:kanbanCounts()
    local counts = { todo = 0, in_progress = 0, done = 0 }
    for _, item in ipairs(self.kanbanItems) do counts[item.status] = counts[item.status] + 1 end
    return counts
end

local Renderer = require("renderer")
local renderer = Renderer.new(screen)
local page_names = { "weather", "calendar", "home", "wifi", "reminders", "kanban" }
local expected_targets = { weather = 1, calendar = 1, home = 1, wifi = 1, reminders = 6, kanban = 6 }
for index, page_name in ipairs(page_names) do
    local page = require(page_name)
    local targets = page.draw(renderer, state, index, #page_names)
    assert(type(targets) == "table", page_name .. " did not return touch targets")
    assert(#targets == expected_targets[page_name], page_name .. " has an unexpected touch-target count")
    for _, target in ipairs(targets) do in_bounds(target.x, target.y, target.w, target.h) end
end

local Reminders = require("reminders")
state.reminders[1].completed = true
Reminders.redrawReminder(renderer, state.reminders[1])

print("All six page layouts fit within 1024x758")
