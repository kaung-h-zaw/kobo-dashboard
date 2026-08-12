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

    renderer:panel(24, 86, 478, 218, "Today")
    renderer:text(os.date("%A"):upper(), 42, 150, 3, { bold = true })
    renderer:text(os.date("%d %B %Y"):upper(), 42, 190, 2, { color = "GRAY5" })
    renderer:text(os.date("%H:%M"), 292, 153, 5, { bold = true })

    renderer:panel(518, 86, 482, 218, "Weather / Bangkok")
    renderer:text("31 C", 542, 148, 6, { bold = true })
    renderer:text("PARTLY CLOUDY", 542, 224, 3, { bold = true })
    renderer:text("HIGH 34 C   LOW 27 C", 542, 265, 2, { color = "GRAY5" })

    renderer:panel(24, 320, 478, 248, "Agenda")
    renderer:label("Next event", 42, 382)
    renderer:text("13:00", 42, 410, 3, { bold = true })
    renderer:text("University Class", 164, 416, 2, { bold = true })
    renderer:line(42, 454, 442, 1, "GRAY8")
    renderer:label("Next reminder", 42, 472)
    renderer:text("Finish assignment", 42, 502, 3, { bold = true })
    renderer:text("DUE 18:00", 42, 538, 2, { color = "GRAY5" })

    renderer:panel(518, 320, 482, 248, "Kanban")
    local counts = state:kanbanCounts()
    renderer:text(tostring(counts.todo), 556, 390, 5, { bold = true })
    renderer:label("To do", 546, 450)
    renderer:line(674, 382, 1, 128, "GRAY8")
    renderer:text(tostring(counts.in_progress), 720, 390, 5, { bold = true })
    renderer:label("Doing", 700, 450)
    renderer:line(838, 382, 1, 128, "GRAY8")
    renderer:text(tostring(counts.done), 888, 390, 5, { bold = true })
    renderer:label("Done", 874, 450)

    local day = tonumber(os.date("%j")) or 1
    local quote = daily_quotes[((day - 1) % #daily_quotes) + 1]
    renderer:panel(24, 584, 976, 112, "Quote of the day")
    renderer:text(quote, 42, 650, 2, { bold = true })

    renderer:endPage(Home.name)
    return renderer.targets
end

return Home
