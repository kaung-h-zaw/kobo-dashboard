local Calendar = { name = "calendar", title = "Calendar" }
local months = { "JANUARY", "FEBRUARY", "MARCH", "APRIL", "MAY", "JUNE", "JULY", "AUGUST", "SEPTEMBER", "OCTOBER", "NOVEMBER", "DECEMBER" }
local weekdays = { "MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN" }

local function days_in_month(year, month)
    return tonumber(os.date("%d", os.time({ year = year, month = month + 1, day = 0, hour = 12 })))
end

function Calendar.draw(renderer, _, index, count)
    renderer:beginPage(Calendar.title, index, count)
    local now = os.date("*t")
    renderer:text(months[now.month] .. " " .. now.year, 40, 88, 4, { bold = true })
    local left, top, cell_w, cell_h = 40, 142, 134, 44
    for col, day in ipairs(weekdays) do renderer:text(day, left + (col - 1) * cell_w + 34, top, 2, { bold = true }) end
    renderer:line(left, top + 29, 938, 2)
    local first = tonumber(os.date("%w", os.time({ year = now.year, month = now.month, day = 1, hour = 12 })))
    local offset = (first + 6) % 7
    for day = 1, days_in_month(now.year, now.month) do
        local slot = offset + day - 1
        local col, row = slot % 7, math.floor(slot / 7)
        local x, y = left + col * cell_w + 44, top + 42 + row * cell_h
        if day == now.day then renderer:box(x - 12, y - 7, 54, 37, 2) end
        renderer:text(tostring(day), x, y, 2, { bold = day == now.day })
    end
    local y = renderer:section("TODAY", 462)
    for _, event in ipairs({ {"09:00", "University"}, {"14:00", "Project Meeting"}, {"18:30", "Study JavaScript"} }) do
        renderer:text(event[1], 40, y, 3, { bold = true })
        renderer:text(event[2], 190, y, 3)
        y = y + 45
    end
    renderer:endPage(Calendar.name)
    return renderer.targets
end

return Calendar
