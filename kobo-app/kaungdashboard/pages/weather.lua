local Weather = { name = "weather", title = "Weather" }

function Weather.draw(renderer, _, index, count)
    renderer:beginPage(Weather.title, index, count)
    renderer:text("BANGKOK", 40, 100, 5, { bold = true })
    renderer:text("NOW", 40, 184, 2, { bold = true, color = "GRAY5" })
    renderer:text("31 C", 40, 220, 7, { bold = true })
    renderer:text("Partly Cloudy", 40, 300, 4, { bold = true })

    renderer:text("TODAY", 580, 184, 2, { bold = true, color = "GRAY5" })
    renderer:text("HIGH  34 C", 580, 224, 4, { bold = true })
    renderer:text("LOW   27 C", 580, 280, 4, { bold = true })

    local y = renderer:section("NEXT DAYS", 390)
    local rows = { {"THU", "33 C / 27 C"}, {"FRI", "32 C / 26 C"}, {"SAT", "34 C / 27 C"} }
    for _, row in ipairs(rows) do
        renderer:text(row[1], 40, y + 8, 3, { bold = true })
        renderer:text(row[2], 690, y + 8, 3, { bold = true })
        renderer:line(40, y + 48, 940, 1, "GRAY8")
        y = y + 58
    end
    renderer:endPage(Weather.name)
    return renderer.targets
end

return Weather
