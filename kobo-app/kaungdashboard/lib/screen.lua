local Screen = {}
Screen.__index = Screen

local function shell_quote(value)
    return "'" .. tostring(value):gsub("'", "'\"'\"'") .. "'"
end

function Screen.new(app_dir, config, logger)
    return setmetatable({
        app_dir = app_dir,
        config = config,
        logger = logger,
        fbink = app_dir .. "/bin/fbink",
        fbdepth = app_dir .. "/bin/fbdepth",
        physical_width = 758,
        physical_height = 1024,
        width = config.Orientation == "portrait" and 758 or 1024,
        height = config.Orientation == "portrait" and 1024 or 758,
    }, Screen)
end

function Screen:command(command, capture)
    self.logger:debug(command)
    if capture then
        local pipe = io.popen(command .. " 2>>" .. shell_quote(self.logger.path), "r")
        if not pipe then return nil end
        local output = pipe:read("*a")
        local ok = pipe:close()
        return ok and output or nil
    end
    return os.execute(command .. " >>" .. shell_quote(self.logger.path) .. " 2>&1")
end

function Screen:setOrientation()
    local canonical = self.config.Orientation == "landscape-left" and "CCW"
        or self.config.Orientation == "landscape-right" and "CW" or "UR"
    self:command(shell_quote(self.fbdepth) .. " -q -d 8 -R " .. canonical)
    self.logger:info("Orientation: " .. self.config.Orientation .. " logical=" .. self.width .. "x" .. self.height)
end

function Screen:clear(no_refresh)
    local command = shell_quote(self.fbink) .. " -q -B WHITE "
        .. (no_refresh and "-b " or "") .. "--cls"
    return self:command(command)
end

function Screen:fillRect(x, y, width, height, color, no_refresh)
    x, y = math.floor(x), math.floor(y)
    width, height = math.max(1, math.floor(width)), math.max(1, math.floor(height))
    local command = shell_quote(self.fbink) .. " -q -B " .. (color or "BLACK") .. " "
        .. (no_refresh and "-b " or "")
        .. "--cls=top=" .. y .. ",left=" .. x .. ",width=" .. width .. ",height=" .. height
    return self:command(command)
end

function Screen:refreshFull()
    return self:command(shell_quote(self.fbink) .. " -q -f --refresh")
end

function Screen:refreshPage()
    -- GC16 updates the composed page without the disruptive white/black flash.
    -- A full flashing cleanup still runs periodically through updateClock.
    return self:command(shell_quote(self.fbink) .. " -q -W GC16 --refresh")
end

function Screen:refreshRegion(rect)
    if not self.config.PartialRefresh then return self:refreshFull() end
    local x = math.max(0, math.floor(rect.x))
    local y = math.max(0, math.floor(rect.y))
    local width = math.min(self.width - x, math.floor(rect.w))
    local height = math.min(self.height - y, math.floor(rect.h))
    return self:command(shell_quote(self.fbink) .. " -q -W GC16 --refresh=top=" .. y
        .. ",left=" .. x .. ",width=" .. width .. ",height=" .. height)
end

function Screen:drawText(text, x, y, scale, options)
    options = options or {}
    local color = options.color or "BLACK"
    local font = options.bold and "TERMINUSB" or "IBM"
    local command = shell_quote(self.fbink) .. " -q -b -O -E -F " .. font
        .. " -S " .. math.floor(scale) .. " -x 0 -y 0 -X " .. math.floor(x)
        .. " -Y " .. math.floor(y) .. " -C " .. color .. " -- " .. shell_quote(text)
    local output = self:command(command, true) or ""
    local rect = {
        x = tonumber(output:match("lastRect_Left=(%d+)")) or math.floor(x),
        y = tonumber(output:match("lastRect_Top=(%d+)")) or math.floor(y),
        w = tonumber(output:match("lastRect_Width=(%d+)")) or (#text * 8 * scale),
        h = tonumber(output:match("lastRect_Height=(%d+)")) or (8 * scale),
    }
    return rect
end

function Screen:drawImage(path, x, y, width, height)
    local geometry = "x=" .. math.floor(x) .. ",y=" .. math.floor(y)
    if width and height then
        geometry = geometry .. ",w=" .. math.floor(width) .. ",h=" .. math.floor(height)
    end
    local command = shell_quote(self.fbink) .. " -q -b -W GC16 -i " .. shell_quote(path)
        .. " -g " .. shell_quote(geometry)
    return self:command(command)
end

function Screen:rawToLogical(raw_x, raw_y, ranges)
    local function normalize(value, minimum, maximum, target_max)
        if maximum <= minimum then return value end
        return math.floor(((value - minimum) / (maximum - minimum)) * target_max + 0.5)
    end
    -- Kobo Nia inherits KOReader's Kobo defaults: raw axes are switched and portrait X is mirrored.
    local touch_x = normalize(raw_x, ranges.x_min, ranges.x_max, self.physical_height - 1)
    local touch_y = normalize(raw_y, ranges.y_min, ranges.y_max, self.physical_width - 1)
    local portrait_x = self.physical_width - 1 - touch_y
    local portrait_y = touch_x
    if self.config.Orientation == "landscape-right" then
        return portrait_y, self.physical_width - 1 - portrait_x
    elseif self.config.Orientation == "landscape-left" then
        return self.physical_height - 1 - portrait_y, portrait_x
    end
    return portrait_x, portrait_y
end

return Screen
