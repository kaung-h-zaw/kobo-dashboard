local Gestures = {}
Gestures.__index = Gestures

function Gestures.new(config)
    return setmetatable({ config = config, start = nil }, Gestures)
end

function Gestures:feed(event)
    if event.kind == "down" then
        self.start = { x = event.x, y = event.y, time = event.time }
        return nil
    end
    if not self.start then return nil end
    if event.kind == "move" then return nil end
    if event.kind ~= "up" then return nil end

    local start = self.start
    self.start = nil
    local dx, dy = event.x - start.x, event.y - start.y
    local duration = event.time - start.time
    if start.x <= 145 and start.y <= 100 and duration >= self.config.CornerExitHoldSeconds then
        return { kind = "exit", reason = "corner-hold" }
    end
    if math.abs(dx) >= self.config.SwipeThreshold and math.abs(dx) > math.abs(dy) * 1.4 then
        return { kind = "swipe", direction = dx < 0 and "left" or "right" }
    end
    if math.abs(dy) >= self.config.SwipeThreshold and math.abs(dy) > math.abs(dx) * 1.4 then
        return { kind = "swipe", direction = dy < 0 and "up" or "down" }
    end
    if math.abs(dx) <= self.config.TapSlop and math.abs(dy) <= self.config.TapSlop then
        return { kind = "tap", x = event.x, y = event.y }
    end
    return { kind = "ignored" }
end

return Gestures
