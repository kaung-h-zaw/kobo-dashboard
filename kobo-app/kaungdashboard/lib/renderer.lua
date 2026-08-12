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

function Renderer:label(text, x, y, options)
    options = options or {}
    options.bold = true
    options.color = options.color or "GRAY5"
    return self:text(text:upper(), x, y, options.scale or 2, options)
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

function Renderer:beginPage(title, index, count)
    self.targets = {}
    self.screen:clear(true)
    self:fill(24, 12, 96, 42, "BLACK")
    self:text("EXIT", 40, 22, 2, { bold = true, color = "WHITE" })
    self:addTarget("exit", "exit", 12, 2, 120, 64)
    self:text(title:upper(), 150, 19, 3, { bold = true })
    self:text(os.date("%a %d %b"):upper(), 742, 23, 2, { color = "GRAY5" })
    self:text(os.date("%H:%M"), 918, 21, 2, { bold = true })
    self:line(24, 66, self.screen.width - 48, 1, "GRAY8")
    self.page_index, self.page_count = index, count
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
    self:text(page_name:upper(), 24, y + 12, 2, { bold = true })
    self:text("SWIPE TO NAVIGATE", 408, y + 12, 2, { color = "GRAY6" })
    self:text(self.page_index .. " / " .. self.page_count, 936, y + 12, 2, { bold = true })
end

function Renderer:endPage(page_name)
    self:footer(page_name)
    self.screen:refreshFull()
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
    if item.completed then self:text("X", box_x + 7, box_y + 5, 2, { bold = true }) end
    local title_rect = self:text(item.title, title_x, rect.y + 17, 2, {
        bold = true,
        color = item.completed and "GRAY7" or "BLACK",
    })
    if item.completed then
        -- Use FBInk's measured glyph rectangle, not Unicode combining characters.
        local strike_y = title_rect.y + math.floor(title_rect.h / 2)
        self:line(title_rect.x, strike_y, title_rect.w, 2, "BLACK")
    end
    if item.due and not item.completed then
        self:text(item.due, title_x, rect.y + 49, 2, { color = "GRAY6" })
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
