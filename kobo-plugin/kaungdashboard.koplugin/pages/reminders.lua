local Components = require("ui/components")

local Reminders = { title = "Reminders" }

local function draw_group(ctx, state, group, y)
    y = Components.sectionTitle(ctx, group, y)
    for _, reminder in ipairs(state.reminders) do
        if reminder.group == group then
            local x = ctx.theme.margin
            local width = ctx.width - x * 2
            local height = ctx.theme.touch_height
            ctx:box(x, y, 42, 42, { thickness = 3 })
            if reminder.completed then
                ctx:text("X", x + 21, y + 7, 23, { align = "center", bold = true })
            end
            ctx:text(reminder.title, x + 62, y + 8, 26, {
                bold = not reminder.completed,
                color = reminder.completed and ctx.theme.muted or ctx.theme.foreground,
                max_width = width - 70,
            })
            ctx:addTarget("reminder", reminder.id, x, y - 7, width, height)
            y = y + height
        end
    end
    return y + 10
end

function Reminders.draw(ctx, state)
    local y = ctx.theme.header_height + 22
    y = draw_group(ctx, state, "TODAY", y)
    draw_group(ctx, state, "UPCOMING", y)
end

return Reminders
