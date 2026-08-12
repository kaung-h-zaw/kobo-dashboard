local Home = { name = "home", title = "Home" }

function Home.draw(renderer, state, index, count)
    renderer:beginPage(Home.title, index, count)
    renderer:text(os.date("%A %d %B"):upper(), 40, 94, 3, { bold = true })
    renderer:text(os.date("%H:%M"), 40, 134, 6, { bold = true })

    renderer:text("NEXT EVENT", 40, 228, 2, { bold = true, color = "GRAY5" })
    renderer:text("13:00  University Class", 40, 258, 3, { bold = true })
    renderer:line(40, 306, 420, 1, "GRAY8")
    renderer:text("NEXT REMINDER", 40, 330, 2, { bold = true, color = "GRAY5" })
    renderer:text("Finish assignment", 40, 360, 3, { bold = true })
    renderer:text("18:00", 40, 398, 2, { color = "GRAY5" })

    renderer:text("WEATHER", 560, 96, 2, { bold = true, color = "GRAY5" })
    renderer:text("BANGKOK", 560, 128, 4, { bold = true })
    renderer:text("31 C", 560, 184, 6, { bold = true })
    renderer:text("Partly Cloudy", 560, 252, 3)
    renderer:line(560, 306, 420, 1, "GRAY8")
    renderer:text("KANBAN", 560, 330, 2, { bold = true, color = "GRAY5" })
    local counts = state:kanbanCounts()
    renderer:text(counts.todo .. "  To Do", 560, 362, 3, { bold = true })
    renderer:text(counts.in_progress .. "  In Progress", 560, 408, 3, { bold = true })
    renderer:text(counts.done .. "  Done", 560, 454, 3, { bold = true })
    renderer:endPage(Home.name)
    return renderer.targets
end

return Home
