local Reminders = { name = "reminders", title = "Reminders", rows = {}, batch = 1 }
local PAGE_SIZE = 5

local function column_items(state, completed)
    local result = {}
    for _, item in ipairs(state.reminders) do
        if item.completed == completed then result[#result + 1] = item end
    end
    return result
end

local function page_count(state)
    local largest = math.max(#column_items(state, false), #column_items(state, true))
    return math.max(1, math.ceil(largest / PAGE_SIZE))
end

local function draw_column(renderer, state, completed, title, x, width)
    renderer:panel(x, 86, width, 610, title)
    local items = column_items(state, completed)
    local first = (Reminders.batch - 1) * PAGE_SIZE + 1
    local last = math.min(#items, first + PAGE_SIZE - 1)
    local range = #items == 0 and "0" or (first .. "-" .. last .. " / " .. #items)
    renderer:text(range, x + width - 142, 104, 1, { bold = true })
    local y = 150
    local visible = 0
    for item_index = first, last do
        local item = items[item_index]
        local rect = { x = x + 8, y = y, w = width - 16, h = 98 }
        Reminders.rows[item.id] = rect
        renderer:drawReminderRow(item, rect, true)
        y = y + rect.h
        visible = visible + 1
    end
    if visible == 0 then renderer:text(#items == 0 and "NO REMINDERS" or "NO MORE REMINDERS", x + 24, 172, 2, { color = "GRAY6" }) end
end

function Reminders.draw(renderer, state, index, count)
    Reminders.batch = math.min(Reminders.batch, page_count(state))
    renderer:beginPage(Reminders.title, index, count)
    Reminders.rows = {}
    draw_column(renderer, state, false, "Open", 24, 478)
    draw_column(renderer, state, true, "Completed", 518, 482)
    renderer:endPage(Reminders.name)
    return renderer.targets
end

function Reminders.scroll(renderer, state, delta, index, count)
    local pages = page_count(state)
    local next_batch = math.max(1, math.min(pages, Reminders.batch + delta))
    if next_batch == Reminders.batch then return false end
    Reminders.batch = next_batch
    Reminders.draw(renderer, state, index, count)
    return true
end

function Reminders.redrawReminder(renderer, item)
    local rect = Reminders.rows[item.id]
    if rect then renderer:partialReminder(item, rect) end
end

return Reminders
