local Home = { name = "home", title = "Home" }

local daily_quotes = {
    "Start small. Keep moving.",
    "Make room for what matters.",
    "A clear plan makes a lighter day.",
    "Progress grows from consistent action.",
    "Finish one thing before chasing ten.",
    "Today is built one choice at a time.",
    "Quiet focus creates visible progress.",
}

function Home.draw(renderer, state, index, count)
    renderer:beginPage(Home.title, index, count)
    local weather = state.weather
    local event = state:nextEvent()
    local reminder = state:nextReminder()

    renderer:panel(24, 86, 478, 218, "Today")
    renderer:text(os.date("%A"):upper(), 42, 152, 3, { bold = true })
    renderer:text(os.date("%d %B %Y"):upper(), 42, 216, 2, { color = "GRAY5" })
    renderer:text(os.date("%H:%M"), 298, 170, 4, { bold = true })

    renderer:panel(518, 86, 482, 218, "Weather / " .. renderer:clip(weather.location, 18))
    renderer:weatherIcon(weather.condition, 538, 154, 104)
    renderer:text(weather.temperature, 670, 158, 4, { bold = true })
    renderer:text(renderer:clip(weather.condition:upper(), 18), 670, 226, 2, { bold = true })
    renderer:text("HIGH " .. weather.high .. "   LOW " .. weather.low, 670, 265, 1, { color = "GRAY5" })

    renderer:panel(24, 320, 478, 248, "Agenda")
    renderer:label("Next event", 42, 378, { scale = 1 })
    renderer:text(event and event.time or "--:--", 42, 404, 3, { bold = true })
    renderer:text(renderer:clip(event and event.title or "No events", 19), 164, 412, 2, { bold = true })
    renderer:line(42, 462, 442, 1, "GRAY8")
    renderer:label("Next reminder", 42, 478, { scale = 1 })
    renderer:text(renderer:clip(reminder and reminder.title or "No reminders", 27), 42, 504, 2, { bold = true })
    renderer:text(reminder and reminder.due and reminder.due:upper() or "NO DUE TIME", 42, 542, 1, { color = "GRAY5" })

    renderer:panel(518, 320, 482, 248, "Kanban")
    local counts = state:kanbanCounts()
    renderer:text(tostring(counts.todo), 556, 384, 4, { bold = true })
    renderer:label("To do", 552, 466, { scale = 1 })
    renderer:line(674, 382, 1, 128, "GRAY8")
    renderer:text(tostring(counts.in_progress), 720, 384, 4, { bold = true })
    renderer:label("Doing", 712, 466, { scale = 1 })
    renderer:line(838, 382, 1, 128, "GRAY8")
    renderer:text(tostring(counts.done), 888, 384, 4, { bold = true })
    renderer:label("Done", 880, 466, { scale = 1 })

    local day = tonumber(os.date("%j")) or 1
    local quote = daily_quotes[((day - 1) % #daily_quotes) + 1]
    renderer:panel(24, 584, 976, 112, "Quote of the day")
    renderer:text(quote, 42, 650, 2, { bold = true })
    renderer:text("SYNC " .. state.remoteSyncedAt, 790, 600, 1, { color = "GRAY6" })

    renderer:endPage(Home.name)
    return renderer.targets
end

return Home
