local Home = { title = "Home" }

function Home.draw(ctx, state)
    local margin = ctx.theme.margin
    local top = ctx.theme.header_height + 24
    local left_width = math.floor(ctx.width * 0.43)
    local right_x = left_width + 70

    ctx:text(os.date("%A %d %B"):upper(), margin, top, 24, { bold = true })
    ctx:text(os.date("%H:%M"), margin, top + 37, 64, { bold = true })

    local y = top + 128
    ctx:text("NEXT EVENT", margin, y, 18, { bold = true, color = ctx.theme.muted })
    ctx:text("13:00  University Class", margin, y + 31, 25, { bold = true, max_width = left_width })
    ctx:line(margin, y + 75, left_width, ctx.theme.light)

    y = y + 96
    ctx:text("NEXT REMINDER", margin, y, 18, { bold = true, color = ctx.theme.muted })
    ctx:text("Finish assignment", margin, y + 31, 25, { bold = true, max_width = left_width })
    ctx:text("Due 18:00", margin, y + 65, 18)

    ctx:text("WEATHER", right_x, top, 18, { bold = true, color = ctx.theme.muted })
    ctx:text("BANGKOK", right_x, top + 31, 28, { bold = true })
    ctx:text("31 C", right_x, top + 72, 55, { bold = true })
    ctx:text("Partly Cloudy", right_x, top + 137, 23)
    ctx:line(right_x, top + 181, ctx.width - margin - right_x, ctx.theme.light)

    local counts = state:kanbanCounts()
    y = top + 207
    ctx:text("KANBAN", right_x, y, 18, { bold = true, color = ctx.theme.muted })
    ctx:text(counts.todo .. "  To Do", right_x, y + 34, 24, { bold = true })
    ctx:text(counts.in_progress .. "  In Progress", right_x, y + 72, 24, { bold = true })
    ctx:text(counts.done .. "  Done", right_x, y + 110, 24, { bold = true })
end

return Home
