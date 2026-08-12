local Weather = { name = "weather", title = "Weather" }

function Weather.draw(renderer, state, index, count)
    renderer:beginPage(Weather.title, index, count)
    local weather = state.weather

    renderer:panel(24, 86, 550, 350, renderer:clip(weather.location, 20) .. " / Now")
    renderer:weatherIcon(weather.condition, 48, 160, 132)
    renderer:text(weather.temperature, 208, 164, 5, { bold = true })
    renderer:text(renderer:clip(weather.condition:upper(), 18), 208, 252, 3, { bold = true })
    renderer:text("FEELS LIKE " .. weather.apparentTemperature, 208, 314, 2, { color = "GRAY5" })
    renderer:line(52, 356, 494, 1, "GRAY8")
    renderer:text("UPDATED " .. tostring(state.remoteSyncedAt or "LOCALLY"), 52, 382, 1, { color = "GRAY6" })

    renderer:panel(594, 86, 406, 350, "Today's details")
    renderer:label("High", 618, 158)
    renderer:text(weather.high, 618, 194, 3, { bold = true })
    renderer:label("Low", 816, 158)
    renderer:text(weather.low, 816, 194, 3, { bold = true })
    renderer:line(610, 250, 374, 1, "GRAY8")
    renderer:label("Humidity", 618, 276)
    renderer:text(weather.humidity, 618, 312, 3, { bold = true })
    renderer:label("Wind", 816, 276)
    renderer:text(renderer:clip(weather.windSpeed, 9), 816, 312, 2, { bold = true })

    renderer:panel(24, 456, 976, 240, "Next days")
    local rows = weather.forecast
    local column_width = 244
    for column, row in ipairs(rows) do
        local x = 24 + (column - 1) * column_width
        if column > 1 then renderer:line(x, 518, 1, 162, "GRAY8") end
        renderer:weatherIcon(row.condition, x + 20, 524, 72)
        renderer:text(row.day, x + 108, 528, 2, { bold = true })
        renderer:text(renderer:clip(row.condition:upper(), 9), x + 108, 565, 1, { color = "GRAY5" })
        renderer:text(row.high .. " / " .. row.low, x + 24, 626, 2, { bold = true })
    end

    renderer:endPage(Weather.name)
    return renderer.targets
end

return Weather
