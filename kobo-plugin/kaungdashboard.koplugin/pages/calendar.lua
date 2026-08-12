local Components = require("ui/components")

local Calendar = { title = "Calendar" }
local month_names = { "JANUARY", "FEBRUARY", "MARCH", "APRIL", "MAY", "JUNE", "JULY", "AUGUST", "SEPTEMBER", "OCTOBER", "NOVEMBER", "DECEMBER" }
local weekdays = { "MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN" }

local function days_in_month(year, month)
    return tonumber(os.date("%d", os.time({ year = year, month = month + 1, day = 0, hour = 12 })))
end

function Calendar.draw(ctx)
    local now = os.date("*t")
    local margin = ctx.theme.margin
    local top = ctx.theme.header_height + 15
    ctx:text(month_names[now.month] .. " " .. now.year, margin, top, 29, { bold = true })

    local grid_top = top + 51
    local grid_width = ctx.width - margin * 2
    local cell_w = math.floor(grid_width / 7)
    local cell_h = 43
    for index, label in ipairs(weekdays) do
        ctx:text(label, margin + (index - 0.5) * cell_w, grid_top, 16, { align = "center", bold = true })
    end
    ctx:line(margin, grid_top + 27, grid_width, ctx.theme.foreground, 2)

    local first_weekday = tonumber(os.date("%w", os.time({ year = now.year, month = now.month, day = 1, hour = 12 })))
    local monday_offset = (first_weekday + 6) % 7
    local count = days_in_month(now.year, now.month)
    for day = 1, count do
        local slot = monday_offset + day - 1
        local col, row = slot % 7, math.floor(slot / 7)
        local x = margin + col * cell_w
        local y = grid_top + 35 + row * cell_h
        if day == now.day then
            ctx:box(x + 12, y, cell_w - 24, 36, { fill = ctx.theme.light, thickness = 2 })
        end
        ctx:text(tostring(day), x + cell_w / 2, y + 6, 20, { align = "center", bold = day == now.day })
    end

    local events_y = grid_top + 35 + 6 * cell_h + 11
    events_y = Components.sectionTitle(ctx, "TODAY", events_y)
    local events = {
        { "09:00", "University" },
        { "14:00", "Project meeting" },
        { "18:30", "Study JavaScript" },
    }
    for _, event in ipairs(events) do
        ctx:text(event[1], margin, events_y, 22, { bold = true })
        ctx:text(event[2], margin + 120, events_y, 22)
        events_y = events_y + 37
    end
end

return Calendar
