local DataStorage = require("datastorage")
local LuaSettings = require("luasettings")
local logger = require("logger")

local State = {}
State.__index = State

local reminder_defaults = {
    { id = "reminder-1", group = "TODAY", title = "Finish assignment", completed = false },
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

local function copy_items(items)
    local result = {}
    for i, item in ipairs(items) do
        result[i] = {}
        for key, value in pairs(item) do
            result[i][key] = value
        end
    end
    return result
end

function State:new(config)
    local settings = LuaSettings:open(DataStorage:getSettingsDir() .. "/kaungdashboard.lua")
    local state = setmetatable({
        config = config,
        settings = settings,
        current_page = config.default_page,
        swipe_count = settings:readSetting("swipe_count") or 0,
        reminders = copy_items(reminder_defaults),
        kanban = copy_items(kanban_defaults),
    }, self)

    local saved_reminders = settings:readSetting("reminders") or {}
    for _, reminder in ipairs(state.reminders) do
        if saved_reminders[reminder.id] ~= nil then
            reminder.completed = saved_reminders[reminder.id]
        end
    end

    local saved_kanban = settings:readSetting("kanban") or {}
    for _, item in ipairs(state.kanban) do
        local saved = saved_kanban[item.id]
        if saved == "todo" or saved == "in_progress" or saved == "done" then
            item.status = saved
        end
    end
    return state
end

function State:pageIndex()
    for index, name in ipairs(self.config.page_order) do
        if name == self.current_page then return index end
    end
    return 1
end

function State:setPageByDelta(delta)
    local count = #self.config.page_order
    local next_index = self:pageIndex() + delta
    if self.config.wrap_pages then
        next_index = ((next_index - 1) % count) + 1
    else
        next_index = math.max(1, math.min(count, next_index))
    end
    if self.config.page_order[next_index] == self.current_page then return false end
    self.current_page = self.config.page_order[next_index]
    self.swipe_count = self.swipe_count + 1
    self:save()
    logger.info("KaungDashboard: Current page:", self.current_page)
    return true
end

function State:toggleReminder(id)
    for _, reminder in ipairs(self.reminders) do
        if reminder.id == id then
            reminder.completed = not reminder.completed
            self:save()
            logger.info("KaungDashboard: Reminder toggled: id=" .. id .. " completed=" .. tostring(reminder.completed))
            return true
        end
    end
    return false
end

function State:advanceKanban(id)
    for _, item in ipairs(self.kanban) do
        if item.id == id then
            local old_status = item.status
            if old_status == "todo" then
                item.status = "in_progress"
            elseif old_status == "in_progress" then
                item.status = "done"
            elseif self.config.done_cycles_to_todo then
                item.status = "todo"
            else
                return false
            end
            self:save()
            logger.info("KaungDashboard: Kanban item moved: " .. old_status .. " -> " .. item.status)
            return true
        end
    end
    return false
end

function State:kanbanCounts()
    local counts = { todo = 0, in_progress = 0, done = 0 }
    for _, item in ipairs(self.kanban) do counts[item.status] = counts[item.status] + 1 end
    return counts
end

function State:save()
    local reminders, kanban = {}, {}
    for _, reminder in ipairs(self.reminders) do reminders[reminder.id] = reminder.completed end
    for _, item in ipairs(self.kanban) do kanban[item.id] = item.status end
    self.settings:saveSetting("reminders", reminders)
        :saveSetting("kanban", kanban)
        :saveSetting("swipe_count", self.swipe_count)
        :flush()
end

return State
