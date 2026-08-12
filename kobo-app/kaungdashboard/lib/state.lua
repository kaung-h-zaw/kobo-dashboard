local State = {}
State.__index = State

-- Offline mode must never present demonstration tasks as the user's real data.
local reminder_defaults = {}
local kanban_defaults = {}

local weather_default = {
    location = "NO LIVE DATA",
    temperature = "-- C",
    condition = "NOT CONNECTED",
    apparentTemperature = "-- C",
    high = "-- C",
    low = "-- C",
    humidity = "--%",
    windSpeed = "-- KM/H",
    forecast = {},
}

local event_defaults = {}

local function copy(items)
    local result = {}
    for index, item in ipairs(items) do
        result[index] = {}
        for key, value in pairs(item) do result[index][key] = value end
    end
    return result
end

function State.new(path, config, logger)
    local self = setmetatable({
        path = path,
        config = config,
        logger = logger,
        currentPage = config.StartPage,
        reminders = copy(reminder_defaults),
        kanbanItems = copy(kanban_defaults),
        weather = weather_default,
        events = copy(event_defaults),
        upcomingEvents = {},
        savedReminderStates = {},
        completedReminderArchive = {},
        reminderOverrides = {},
        remoteSyncedAt = "NOT CONNECTED",
    }, State)
    self:load()
    -- Version 1 always opens on the configured start page, while still tracking page state in memory.
    self.currentPage = config.StartPage
    return self
end

function State:load()
    local ok, saved = pcall(dofile, self.path)
    if not ok or type(saved) ~= "table" then return end
    local reminders = saved.reminders or {}
    local completed_reminders = saved.completedReminders or {}
    local reminder_overrides = saved.reminderOverrides or {}
    local kanban = saved.kanbanItems or {}
    for _, item in ipairs(self.reminders) do
        if type(reminders[item.id]) == "boolean" then item.completed = reminders[item.id] end
    end
    self.savedReminderStates = reminders
    for id, item in pairs(completed_reminders) do
        if type(id) == "string" and type(item) == "table" and type(item.title) == "string" then
            local archived = {
                id = id,
                group = "COMPLETED",
                title = item.title,
                due = type(item.due) == "string" and item.due or nil,
                completed = true,
            }
            self.completedReminderArchive[id] = archived
            self.reminders[#self.reminders + 1] = archived
        end
    end
    for id, override in pairs(reminder_overrides) do
        if type(id) == "string" and type(override) == "table"
            and type(override.completed) == "boolean" and type(override.changedAt) == "number" then
            self.reminderOverrides[id] = {
                completed = override.completed,
                changedAt = override.changedAt,
            }
        end
    end
    for _, item in ipairs(self.kanbanItems) do
        local status = kanban[item.id]
        if status == "todo" or status == "in_progress" or status == "done" then item.status = status end
    end
end

local function remote_events(items)
    local result = {}
    if type(items) ~= "table" then return result end
    for _, item in ipairs(items) do
        if type(item) == "table" and type(item.title) == "string" and type(item.time) == "string" then
            result[#result + 1] = { title = item.title, time = item.time, calendar = item.calendar }
        end
    end
    return result
end

function State:applyRemote(data)
    if type(data) ~= "table" or type(data.weather) ~= "table" or type(data.reminders) ~= "table" then
        self.logger:error("Remote data has an invalid structure")
        return false
    end

    local weather = data.weather
    self.weather = {
        location = type(weather.location) == "string" and weather.location or weather_default.location,
        temperature = type(weather.temperature) == "string" and weather.temperature or weather_default.temperature,
        condition = type(weather.condition) == "string" and weather.condition or weather_default.condition,
        apparentTemperature = type(weather.apparentTemperature) == "string" and weather.apparentTemperature or weather_default.apparentTemperature,
        high = type(weather.high) == "string" and weather.high or weather_default.high,
        low = type(weather.low) == "string" and weather.low or weather_default.low,
        humidity = type(weather.humidity) == "string" and weather.humidity or weather_default.humidity,
        windSpeed = type(weather.windSpeed) == "string" and weather.windSpeed or weather_default.windSpeed,
        forecast = {},
    }
    if type(weather.forecast) == "table" then
        for _, day in ipairs(weather.forecast) do
            if type(day) == "table" and type(day.day) == "string" then
                self.weather.forecast[#self.weather.forecast + 1] = {
                    day = day.day,
                    condition = type(day.condition) == "string" and day.condition or "UNKNOWN",
                    high = type(day.high) == "string" and day.high or "-- C",
                    low = type(day.low) == "string" and day.low or "-- C",
                }
            end
        end
    end
    if #self.weather.forecast == 0 then self.weather.forecast = copy(weather_default.forecast) end

    local reminders = {}
    local seen = {}
    local now = os.time()
    for _, item in ipairs(data.reminders) do
        if type(item) == "table" and type(item.id) == "string" and type(item.title) == "string" then
            local completed = item.completed == true
            local override = self.reminderOverrides[item.id]
            if override then
                if completed == override.completed then
                    self.reminderOverrides[item.id] = nil
                elseif now - override.changedAt <= 120 then
                    completed = override.completed
                else
                    self.reminderOverrides[item.id] = nil
                end
            end
            local normalized = {
                id = item.id,
                group = completed and "COMPLETED" or (item.group == "UPCOMING" and "UPCOMING" or "TODAY"),
                title = item.title,
                due = type(item.due) == "string" and item.due or nil,
                completed = completed,
            }
            reminders[#reminders + 1] = normalized
            seen[item.id] = true
            if completed then
                self.completedReminderArchive[item.id] = normalized
            else
                self.completedReminderArchive[item.id] = nil
            end
        end
    end
    -- Keep completed rows visible if Apple's next snapshot temporarily omits them.
    for id, item in pairs(self.completedReminderArchive) do
        if not seen[id] then reminders[#reminders + 1] = item end
    end
    self.reminders = reminders
    self.events = remote_events(data.events)
    self.upcomingEvents = remote_events(data.upcomingEvents)
    self.remoteSyncedAt = type(data.syncedAt) == "string" and data.syncedAt or "UNKNOWN"
    self:save()
    self.logger:info("Applied remote data: reminders=" .. #self.reminders .. " events=" .. #self.events)
    return true
end

function State:nextEvent()
    return self.events[1] or self.upcomingEvents[1]
end

function State:nextReminder()
    for _, item in ipairs(self.reminders) do
        if not item.completed then return item end
    end
end

local function quoted(value)
    return string.format("%q", value)
end

function State:save()
    local tmp = self.path .. ".tmp"
    local file = io.open(tmp, "w")
    if not file then
        self.logger:error("Unable to write state file")
        return false
    end
    file:write("return {\n  reminders = {\n")
    for _, item in ipairs(self.reminders) do
        file:write("    [", quoted(item.id), "] = ", tostring(item.completed), ",\n")
    end
    file:write("  },\n  completedReminders = {\n")
    for id, item in pairs(self.completedReminderArchive) do
        file:write("    [", quoted(id), "] = { title = ", quoted(item.title))
        if item.due then file:write(", due = ", quoted(item.due)) end
        file:write(" },\n")
    end
    file:write("  },\n  reminderOverrides = {\n")
    for id, override in pairs(self.reminderOverrides) do
        file:write("    [", quoted(id), "] = { completed = ", tostring(override.completed),
            ", changedAt = ", tostring(override.changedAt), " },\n")
    end
    file:write("  },\n  kanbanItems = {\n")
    for _, item in ipairs(self.kanbanItems) do
        file:write("    [", quoted(item.id), "] = ", quoted(item.status), ",\n")
    end
    file:write("  },\n}\n")
    file:close()
    os.remove(self.path .. ".old")
    os.rename(self.path, self.path .. ".old")
    local ok = os.rename(tmp, self.path)
    return ok and true or false
end

function State:toggleReminder(id)
    for _, item in ipairs(self.reminders) do
        if item.id == id then
            item.completed = not item.completed
            self.savedReminderStates[id] = item.completed
            self.reminderOverrides[id] = { completed = item.completed, changedAt = os.time() }
            if item.completed then
                item.group = "COMPLETED"
                self.completedReminderArchive[id] = item
            else
                item.group = "TODAY"
                self.completedReminderArchive[id] = nil
            end
            self:save()
            self.logger:info("Reminder toggled: " .. id .. " completed=" .. tostring(item.completed))
            return item
        end
    end
end

function State:advanceKanban(id)
    for _, item in ipairs(self.kanbanItems) do
        if item.id == id then
            local old = item.status
            if old == "todo" then item.status = "in_progress"
            elseif old == "in_progress" then item.status = "done"
            elseif self.config.KanbanCycleDoneToTodo then item.status = "todo"
            else return false end
            self:save()
            self.logger:info("Kanban state changed: " .. id .. " " .. old .. " -> " .. item.status)
            return true
        end
    end
    return false
end

function State:kanbanCounts()
    local counts = { todo = 0, in_progress = 0, done = 0 }
    for _, item in ipairs(self.kanbanItems) do counts[item.status] = counts[item.status] + 1 end
    return counts
end

return State
