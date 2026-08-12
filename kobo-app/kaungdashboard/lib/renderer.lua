local Renderer = {}
Renderer.__index = Renderer

function Renderer.new(screen)
    return setmetatable({ screen = screen, targets = {} }, Renderer)
end

function Renderer:text(text, x, y, scale, options)
    return self.screen:drawText(text, x, y, scale, options)
end

function Renderer:image(path, x, y, width, height)
    return self.screen:drawImage(path, x, y, width, height)
end

function Renderer:fill(x, y, width, height, color)
    return self.screen:fillRect(x, y, width, height, color or "BLACK", true)
end

function Renderer:line(x, y, width, thickness, color)
    self.screen:fillRect(x, y, width, thickness or 2, color or "BLACK", true)
end

function Renderer:box(x, y, width, height, thickness)
    thickness = thickness or 2
    self:line(x, y, width, thickness)
    self:line(x, y + height - thickness, width, thickness)
    self.screen:fillRect(x, y, thickness, height, "BLACK", true)
    self.screen:fillRect(x + width - thickness, y, thickness, height, "BLACK", true)
end

local function weather_kind(condition)
    local value = tostring(condition or ""):lower()
    if value == "" or value:find("not connected", 1, true) or value:find("no live", 1, true) then return nil end
    if value:find("thunder", 1, true) then return "storm" end
    if value:find("snow", 1, true) then return "snow" end
    if value:find("rain", 1, true) or value:find("drizzle", 1, true) or value:find("shower", 1, true) then return "rain" end
    if value:find("fog", 1, true) or value:find("mist", 1, true) then return "fog" end
    if value:find("partly", 1, true) or value:find("mainly", 1, true) then return "partly" end
    if value:find("cloud", 1, true) or value:find("overcast", 1, true) then return "cloudy" end
    return "sunny"
end

function Renderer:weatherIcon(condition, x, y, size)
    local kind = weather_kind(condition)
    if not kind then return end
    local asset = self.screen.app_dir .. "/assets/icon-" .. kind .. ".png"
    self:image(asset, x, y, size, size)
end

function Renderer:label(text, x, y, options)
    options = options or {}
    options.bold = true
    options.color = options.color or "GRAY5"
    return self:text(text:upper(), x, y, options.scale or 2, options)
end

function Renderer:clip(text, maximum)
    text = tostring(text or "")
    if #text <= maximum then return text end
    return text:sub(1, math.max(1, maximum - 3)) .. "..."
end

function Renderer:panel(x, y, width, height, title)
    self:box(x, y, width, height, 1)
    if title then
        self:label(title, x + 16, y + 14)
        self:line(x + 1, y + 46, width - 2, 1, "GRAY8")
    end
    return y + (title and 58 or 16)
end

function Renderer:addTarget(kind, id, x, y, width, height)
    table.insert(self.targets, { kind = kind, id = id, x = x, y = y, w = width, h = height })
end

function Renderer:drawReload(loading)
    local x, y, size = 640, 12, 44
    self:box(x, y, size, 42, loading and 3 or 1)
    self:image(self.screen.app_dir .. "/assets/icon-refresh.png", x + 7, y + 6, 30, 30)
end

function Renderer:beginPage(title, index, count)
    self.targets = {}
    self.screen:clear(true)
    self:image(self.screen.app_dir .. "/assets/header-exit.png", 24, 9, 96, 48)
    self:addTarget("exit", "exit", 12, 2, 120, 64)
    self:text(self:clip(title:upper(), 14), 150, 22, 2, { bold = true })
    self:drawReload(false)
    self:addTarget("reload", "reload", 624, 2, 76, 64)
    self:text(os.date("%a %d %b"):upper(), 742, 23, 2, { color = "GRAY5" })
    self:text(os.date("%H:%M"), 918, 21, 2, { bold = true })
    self:line(24, 66, self.screen.width - 48, 1, "GRAY8")
    self.page_index, self.page_count = index, count
end

function Renderer:updateReload(loading)
    local rect = { x = 636, y = 8, w = 52, h = 50 }
    self:fill(rect.x, rect.y, rect.w, rect.h, "WHITE")
    self:drawReload(loading)
    self.screen:refreshRegion(rect)
end

function Renderer:section(title, y)
    self:label(title, 24, y)
    self:line(24, y + 30, self.screen.width - 48, 1, "GRAY8")
    return y + 42
end

function Renderer:footer(page_name)
    local y = self.screen.height - 42
    self:fill(0, y, self.screen.width, 42, "GRAY2")
    self:line(0, y, self.screen.width, 1, "BLACK")
    self:text(page_name:upper(), 24, y + 8, 2, { bold = true, color = "WHITE" })
    self:text("SWIPE TO NAVIGATE", 408, y + 8, 2, { color = "WHITE" })
    self:text(self.page_index .. " / " .. self.page_count, 936, y + 8, 2, { bold = true, color = "WHITE" })
end

function Renderer:endPage(page_name)
    self:footer(page_name)
    self.screen:refreshPage()
end

function Renderer:updateClock(force_full)
    local rect = { x = 904, y = 12, w = 96, h = 42 }
    self.screen:fillRect(rect.x, rect.y, rect.w, rect.h, "WHITE", true)
    self:text(os.date("%H:%M"), 918, 21, 2, { bold = true })
    if force_full then self.screen:refreshFull()
    else self.screen:refreshRegion(rect) end
end

function Renderer:clearRow(rect)
    self.screen:fillRect(rect.x, rect.y, rect.w, rect.h, "WHITE", true)
end

function Renderer:drawReminderRow(item, rect, register_target)
    local box_x, title_x = rect.x + 12, rect.x + 58
    local box_y = rect.y + 17
    self:box(box_x, box_y, 30, 30, 2)
    if item.completed then
        self:image(self.screen.app_dir .. "/assets/icon-check.png", box_x + 4, box_y + 4, 22, 22)
    end
    local title_rect = self:text(self:clip(item.title, 23), title_x, rect.y + 17, 2, {
        bold = true,
        color = item.completed and "GRAY7" or "BLACK",
    })
    if item.completed then
        -- Use FBInk's measured glyph rectangle, not Unicode combining characters.
        local strike_y = title_rect.y + math.floor(title_rect.h / 2)
        self:line(title_rect.x, strike_y, title_rect.w, 2, "BLACK")
    end
    if item.due and not item.completed then
        self:text(item.due, title_x, rect.y + 56, 1, { color = "GRAY6" })
    end
    self:line(rect.x + 8, rect.y + rect.h - 1, rect.w - 16, 1, "GRAY8")
    if register_target then self:addTarget("reminder", item.id, rect.x, rect.y, rect.w, rect.h) end
end

function Renderer:partialReminder(item, rect)
    self:clearRow(rect)
    self:drawReminderRow(item, rect, false)
    self.screen:refreshRegion(rect)
end

return Renderer
