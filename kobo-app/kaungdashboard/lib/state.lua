local State = {}
State.__index = State

local reminder_defaults = {
    { id = "reminder-1", group = "TODAY", title = "Finish assignment", due = "Due 18:00", completed = false },
    { id = "reminder-2", group = "TODAY", title = "Buy groceries", completed = false },
    { id = "reminder-3", group = "TODAY", title = "Call family", completed = true },
    { id = "reminder-4", group = "UPCOMING", title = "Apply for internship", completed = false },
    { id = "reminder-5", group = "UPCOMING", title = "Submit portfolio", completed = false },
}

local kanban_defaults = {
    { id = "kanban-1", title = "Finish project report", status = "todo" },
    { id = "kanban-2", title = "Update resume", status = "todo" },
    { id = "kanban-3", title = "Portfolio redesign", status = "in_progress" },
    { id = "kanban-4", title = "Install KOReader", status = "done" },
    { id = "kanban-5", title = "Setup Render server", status = "done" },
}

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
    local kanban = saved.kanbanItems or {}
    for _, item in ipairs(self.reminders) do
        if type(reminders[item.id]) == "boolean" then item.completed = reminders[item.id] end
    end
    for _, item in ipairs(self.kanbanItems) do
        local status = kanban[item.id]
        if status == "todo" or status == "in_progress" or status == "done" then item.status = status end
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
