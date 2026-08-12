local Reminders = { name = "reminders", title = "Reminders", rows = {} }

local function group_count(state, group)
    local count = 0
    for _, item in ipairs(state.reminders) do
        if item.group == group then count = count + 1 end
    end
    return count
end

local function draw_group(renderer, state, group, x, width)
    renderer:panel(x, 86, width, 610, group)
    renderer:text(tostring(group_count(state, group)), x + width - 46, 100, 2, { bold = true })
    local y = 150
    for _, item in ipairs(state.reminders) do
        if item.group == group then
            local rect = { x = x + 8, y = y, w = width - 16, h = 98 }
            Reminders.rows[item.id] = rect
            renderer:drawReminderRow(item, rect, true)
            y = y + rect.h
        end
    end
end

function Reminders.draw(renderer, state, index, count)
    renderer:beginPage(Reminders.title, index, count)
    Reminders.rows = {}
    draw_group(renderer, state, "TODAY", 24, 478)
    draw_group(renderer, state, "UPCOMING", 518, 482)
    renderer:endPage(Reminders.name)
    return renderer.targets
end

function Reminders.redrawReminder(renderer, item)
    local rect = Reminders.rows[item.id]
    if rect then renderer:partialReminder(item, rect) end
end

return Reminders
