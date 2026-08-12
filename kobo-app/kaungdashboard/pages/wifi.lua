local Wifi = { name = "wifi", title = "Guest Wi-Fi" }

local function draw_network(renderer, x, width, band, ssid, asset)
    renderer:panel(x, 86, width, 610, band)
    local qr_x = x + math.floor((width - 296) / 2)
    renderer:image(renderer.screen.app_dir .. "/assets/" .. asset, qr_x, 156, 296, 296)
    renderer:line(x + 24, 474, width - 48, 1, "GRAY8")
    renderer:label("Network", x + 24, 500)
    renderer:text(ssid, x + 24, 530, 3, { bold = true })
    renderer:label("Scan to connect", x + 24, 582)
    renderer:text("Saved Wi-Fi access", x + 24, 612, 2, { color = "GRAY6" })
end

function Wifi.draw(renderer, _, index, count)
    renderer:beginPage(Wifi.title, index, count)
    draw_network(renderer, 24, 478, "2.4 GHz / Best range", "KAUNG_2.4G", "wifi-24ghz.png")
    draw_network(renderer, 518, 482, "5 GHz / Best speed", "KAUNG_5G", "wifi-5ghz.png")
    renderer:endPage(Wifi.name)
    return renderer.targets
end

return Wifi
