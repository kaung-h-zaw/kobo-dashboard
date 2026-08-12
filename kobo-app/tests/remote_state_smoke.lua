package.path = "kobo-app/kaungdashboard/lib/?.lua;" .. package.path

local State = require("state")
local logger = { info = function() end, error = function() end }
local state = State.new("/missing-state-data.lua", { StartPage = "home" }, logger)
state.savedReminderStates.live_reminder = true

local applied = state:applyRemote({
    syncedAt = "12:45",
    weather = {
        location = "Bangkok", temperature = "32 C", condition = "Clear Sky",
        apparentTemperature = "35 C", high = "35 C", low = "27 C",
        humidity = "61%", windSpeed = "8 KM/H",
        forecast = {
            { day = "THU", condition = "CLEAR SKY", high = "34 C", low = "27 C" },
        },
    },
    events = { { time = "10:30", title = "Live calendar event" } },
    upcomingEvents = { { time = "09:00", title = "Tomorrow event" } },
    reminders = {
        { id = "live_reminder", group = "TODAY", title = "Live reminder", due = "Due 18:00", completed = false },
        { id = "future_reminder", group = "UPCOMING", title = "Future reminder", completed = false },
    },
})

assert(applied)
assert(state.weather.temperature == "32 C")
assert(state.events[1].title == "Live calendar event")
assert(state.reminders[1].completed == true)
assert(state:nextEvent().time == "10:30")
assert(state:nextReminder().id == "future_reminder")
assert(state.remoteSyncedAt == "12:45")
print("Remote state binding smoke test passed")
