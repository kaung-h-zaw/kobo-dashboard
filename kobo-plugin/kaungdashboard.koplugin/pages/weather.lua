local Components = require("ui/components")

local Weather = { title = "Weather" }

function Weather.draw(ctx)
    local margin = ctx.theme.margin
    local top = ctx.theme.header_height + 28
    ctx:text("BANGKOK", margin, top, 40, { bold = true })

    ctx:text("NOW", margin, top + 75, 19, { bold = true, color = ctx.theme.muted })
    ctx:text("31 C", margin, top + 105, 82, { bold = true })
    ctx:text("Partly Cloudy", margin, top + 199, 29, { bold = true })

    local right_x = math.floor(ctx.width * 0.56)
    ctx:text("TODAY", right_x, top + 75, 19, { bold = true, color = ctx.theme.muted })
    ctx:text("HIGH  34 C", right_x, top + 112, 30, { bold = true })
    ctx:text("LOW   27 C", right_x, top + 159, 30, { bold = true })

    local y = Components.sectionTitle(ctx, "NEXT DAYS", top + 283)
    local rows = {
        { "THU", "33 C / 27 C", "PARTLY CLOUDY" },
        { "FRI", "32 C / 26 C", "CLOUDY" },
        { "SAT", "34 C / 27 C", "CLEAR" },
    }
    for _, row in ipairs(rows) do
        ctx:text(row[1], margin, y + 9, 25, { bold = true })
        ctx:text(row[3], margin + 125, y + 12, 20)
        ctx:text(row[2], ctx.width - margin, y + 9, 25, { align = "right", bold = true })
        ctx:line(margin, y + 51, ctx.width - margin * 2, ctx.theme.light, 1)
        y = y + 59
    end
end

return Weather
