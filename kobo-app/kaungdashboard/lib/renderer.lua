local Renderer = {}
Renderer.__index = Renderer

function Renderer.new(screen)
    return setmetatable({ screen = screen, targets = {} }, Renderer)
end

function Renderer:text(text, x, y, scale, options)
    return self.screen:drawText(text, x, y, scale, options)
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

function Renderer:addTarget(kind, id, x, y, width, height)
    table.insert(self.targets, { kind = kind, id = id, x = x, y = y, w = width, h = height })
end

function Renderer:beginPage(title, index, count)
    self.targets = {}
    self.screen:clear(true)
    self:box(34, 10, 106, 48, 3)
    self:text("EXIT", 50, 18, 3, { bold = true })
    self:addTarget("exit", "exit", 20, 0, 140, 76)
    self:text(title:upper(), 178, 18, 4, { bold = true })
    self:text(os.date("%H:%M"), 855, 18, 3, { bold = true })
    self:line(34, 68, self.screen.width - 68, 2)
    self.page_index, self.page_count = index, count
end

function Renderer:section(title, y)
    self:text(title, 34, y, 3, { bold = true })
    self:line(34, y + 34, self.screen.width - 68, 1, "GRAY8")
    return y + 44
end

function Renderer:footer(page_name)
    local y = self.screen.height - 43
    self:line(34, y, self.screen.width - 68, 1, "GRAY8")
    self:text(page_name:upper(), 34, y + 10, 2, { bold = true })
    self:text(self.page_index .. " / " .. self.page_count, 475, y + 10, 2, { bold = true })
end

function Renderer:endPage(page_name)
    self:footer(page_name)
    self.screen:refreshFull()
end

function Renderer:clearRow(rect)
    self.screen:fillRect(rect.x, rect.y, rect.w, rect.h, "WHITE", true)
end

function Renderer:drawReminderRow(item, rect, register_target)
    local box_x, title_x = rect.x + 10, rect.x + 72
    local box_y = rect.y + 12
    self:box(box_x, box_y, 38, 38, 3)
    if item.completed then self:text("X", box_x + 8, box_y + 4, 3, { bold = true }) end
    local title_rect = self:text(item.title, title_x, rect.y + 12, 3, {
        color = item.completed and "GRAY7" or "BLACK",
    })
    if item.completed then
        -- Use FBInk's measured glyph rectangle, not Unicode combining characters.
        local strike_y = title_rect.y + math.floor(title_rect.h / 2)
        self:line(title_rect.x, strike_y, title_rect.w, 3, "BLACK")
    end
    if item.due and not item.completed then
        self:text(item.due, title_x, rect.y + 48, 2, { color = "GRAY6" })
    end
    if register_target then self:addTarget("reminder", item.id, rect.x, rect.y, rect.w, rect.h) end
end

function Renderer:partialReminder(item, rect)
    self:clearRow(rect)
    self:drawReminderRow(item, rect, false)
    self.screen:refreshRegion(rect)
end

return Renderer
