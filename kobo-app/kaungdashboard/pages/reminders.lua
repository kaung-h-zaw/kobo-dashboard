local Reminders = { name = "reminders", title = "Reminders", rows = {} }

local function draw_group(renderer, state, group, y)
    y = renderer:section(group, y)
    for _, item in ipairs(state.reminders) do
        if item.group == group then
            local height = item.due and 82 or 68
            local rect = { x = 34, y = y, w = renderer.screen.width - 68, h = height }
            Reminders.rows[item.id] = rect
            renderer:drawReminderRow(item, rect, true)
            y = y + height
        end
    end
    return y + 9
end

function Reminders.draw(renderer, state, index, count)
    renderer:beginPage(Reminders.title, index, count)
    Reminders.rows = {}
    local y = draw_group(renderer, state, "TODAY", 88)
    draw_group(renderer, state, "UPCOMING", y)
    renderer:endPage(Reminders.name)
    return renderer.targets
end

function Reminders.redrawReminder(renderer, item)
    local rect = Reminders.rows[item.id]
    if rect then renderer:partialReminder(item, rect) end
end

return Reminders
