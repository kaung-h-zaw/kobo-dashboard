local Weather = { name = "weather", title = "Weather" }

function Weather.draw(renderer, _, index, count)
    renderer:beginPage(Weather.title, index, count)

    renderer:panel(24, 86, 550, 350, "Bangkok / Now")
    renderer:text("31 C", 52, 164, 7, { bold = true })
    renderer:text("PARTLY CLOUDY", 52, 258, 4, { bold = true })
    renderer:text("FEELS LIKE 34 C", 52, 318, 2, { color = "GRAY5" })
    renderer:line(52, 356, 494, 1, "GRAY8")
    renderer:text("Updated locally", 52, 378, 2, { color = "GRAY6" })

    renderer:panel(594, 86, 406, 350, "Today's details")
    renderer:label("High", 618, 158)
    renderer:text("34 C", 618, 188, 4, { bold = true })
    renderer:label("Low", 816, 158)
    renderer:text("27 C", 816, 188, 4, { bold = true })
    renderer:line(610, 250, 374, 1, "GRAY8")
    renderer:label("Humidity", 618, 276)
    renderer:text("68%", 618, 306, 4, { bold = true })
    renderer:label("Wind", 816, 276)
    renderer:text("9 KM/H", 816, 306, 3, { bold = true })

    renderer:panel(24, 456, 976, 240, "Next days")
    local rows = {
        { "THU", "CLOUDY", "33 / 27" },
        { "FRI", "RAIN", "32 / 26" },
        { "SAT", "SUNNY", "34 / 27" },
        { "SUN", "CLOUDY", "33 / 26" },
    }
    local column_width = 244
    for column, row in ipairs(rows) do
        local x = 24 + (column - 1) * column_width
        if column > 1 then renderer:line(x, 518, 1, 162, "GRAY8") end
        renderer:text(row[1], x + 24, 530, 3, { bold = true })
        renderer:text(row[2], x + 24, 574, 2, { color = "GRAY5" })
        renderer:text(row[3] .. " C", x + 24, 618, 3, { bold = true })
    end

    renderer:endPage(Weather.name)
    return renderer.targets
end

return Weather
