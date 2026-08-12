local Calendar = { name = "calendar", title = "Calendar" }
local months = { "JANUARY", "FEBRUARY", "MARCH", "APRIL", "MAY", "JUNE", "JULY", "AUGUST", "SEPTEMBER", "OCTOBER", "NOVEMBER", "DECEMBER" }
local weekdays = { "MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN" }

local function days_in_month(year, month)
    return tonumber(os.date("%d", os.time({ year = year, month = month + 1, day = 0, hour = 12 })))
end

function Calendar.draw(renderer, _, index, count)
    renderer:beginPage(Calendar.title, index, count)
    local now = os.date("*t")

    renderer:panel(24, 86, 650, 610, months[now.month] .. " " .. now.year)
    local grid_x, grid_y, cell_w, cell_h = 40, 188, 88, 76
    for column, weekday in ipairs(weekdays) do
        renderer:label(weekday, grid_x + (column - 1) * cell_w + 18, 154)
    end
    for column = 0, 7 do
        renderer:line(grid_x + column * cell_w, grid_y, 1, cell_h * 6, "GRAY8")
    end
    for row = 0, 6 do
        renderer:line(grid_x, grid_y + row * cell_h, cell_w * 7, 1, "GRAY8")
    end

    local first = tonumber(os.date("%w", os.time({ year = now.year, month = now.month, day = 1, hour = 12 })))
    local offset = (first + 6) % 7
    for day = 1, days_in_month(now.year, now.month) do
        local slot = offset + day - 1
        local column, row = slot % 7, math.floor(slot / 7)
        local x, y = grid_x + column * cell_w, grid_y + row * cell_h
        if day == now.day then
            renderer:fill(x + 8, y + 10, 44, 38, "BLACK")
            renderer:text(tostring(day), x + 16, y + 19, 2, { bold = true, color = "WHITE" })
        else
            renderer:text(tostring(day), x + 12, y + 18, 2, { bold = true })
        end
    end

    renderer:panel(694, 86, 306, 610, "Today")
    renderer:text(os.date("%d %b"):upper(), 718, 150, 4, { bold = true })
    renderer:text(os.date("%A"):upper(), 718, 202, 2, { color = "GRAY5" })
    renderer:line(718, 238, 258, 1, "GRAY8")

    local events = {
        { "09:00", "University" },
        { "14:00", "Project Meeting" },
        { "18:30", "Study JavaScript" },
    }
    local y = 266
    for _, event in ipairs(events) do
        renderer:text(event[1], 718, y, 3, { bold = true })
        renderer:text(event[2], 718, y + 38, 2)
        renderer:line(718, y + 74, 258, 1, "GRAY8")
        y = y + 98
    end

    renderer:endPage(Calendar.name)
    return renderer.targets
end

return Calendar
