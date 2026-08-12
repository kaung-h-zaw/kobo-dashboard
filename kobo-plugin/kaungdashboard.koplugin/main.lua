local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
local Event = require("ui/event")
local Geom = require("ui/geometry")
local InputContainer = require("ui/widget/container/inputcontainer")
local UIManager = require("ui/uimanager")
local Widget = require("ui/widget/widget")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local logger = require("logger")
local _ = require("gettext")

local Config = require("config")
local State = require("state")
local Components = require("ui/components")
local Footer = require("ui/footer")
local Header = require("ui/header")
local Theme = require("ui/theme")

local Screen = Device.screen

local pages = {
    weather = require("pages/weather"),
    calendar = require("pages/calendar"),
    home = require("pages/home"),
    reminders = require("pages/reminders"),
    kanban = require("pages/kanban"),
}

local DashboardCanvas = Widget:extend{}

function DashboardCanvas:getSize()
    return self.dimen
end

function DashboardCanvas:paintTo(bb, x, y)
    self.dimen.x, self.dimen.y = x, y
    bb:paintRect(x, y, self.dimen.w, self.dimen.h, Blitbuffer.COLOR_WHITE)
    local ctx = Components.newContext(bb, self.dimen.w, self.dimen.h, Theme)
    local page = pages[self.state.current_page]
    Header.draw(ctx, page.title)
    page.draw(ctx, self.state)
    Footer.draw(ctx, self.state)
    self.targets = ctx.targets
end

local DashboardView = InputContainer:extend{
    name = "kaung_dashboard_view",
    covers_fullscreen = true,
    modal = true,
    disable_double_tap = true,
}

function DashboardView:init()
    self.state = State:new(Config)
    self.original_rotation = self.original_rotation or Screen:getRotationMode()
    self.closed = false
    self.dimen = Geom:new{ x = 0, y = 0, w = Screen:getWidth(), h = Screen:getHeight() }
    self.canvas = DashboardCanvas:new{
        dimen = Geom:new{ x = 0, y = 0, w = self.dimen.w, h = self.dimen.h },
        state = self.state,
        targets = {},
    }
    self[1] = self.canvas

    if Device:isTouchDevice() then
        self:registerTouchZones({
            {
                id = "kaung_dashboard_tap",
                ges = "tap",
                screen_zone = { ratio_x = 0, ratio_y = 0, ratio_w = 1, ratio_h = 1 },
                handler = function(ges) return self:onDashboardTap(ges) end,
            },
            {
                id = "kaung_dashboard_swipe",
                ges = "swipe",
                screen_zone = { ratio_x = 0, ratio_y = 0, ratio_w = 1, ratio_h = 1 },
                handler = function(ges) return self:onDashboardSwipe(ges) end,
            },
        })
    end

    self.key_events.Close = { { Device.input.group.Back } }
    logger.info("KaungDashboard loaded")
    logger.info("KaungDashboard: Current page:", self.state.current_page)
end

function DashboardView:onDashboardSwipe(ges)
    if not ges or not ges.direction then return false end
    local minimum = Screen:getWidth() * Config.minimum_swipe_distance_ratio
    if ges.distance and ges.distance < minimum then
        logger.dbg("KaungDashboard: Ignored short swipe")
        return true
    end

    local changed = false
    if ges.direction == "west" then
        logger.info("KaungDashboard: Swipe left")
        changed = self.state:setPageByDelta(1)
    elseif ges.direction == "east" then
        logger.info("KaungDashboard: Swipe right")
        changed = self.state:setPageByDelta(-1)
    else
        return false
    end
    if changed then UIManager:setDirty(self, "flashui") end
    return true
end

local function contains(target, x, y)
    return x >= target.x and x <= target.x + target.w
        and y >= target.y and y <= target.y + target.h
end

function DashboardView:onDashboardTap(ges)
    if not ges or not ges.pos then return false end
    for index = #self.canvas.targets, 1, -1 do
        local target = self.canvas.targets[index]
        if contains(target, ges.pos.x, ges.pos.y) then
            if target.kind == "exit" then
                self:onClose()
            elseif target.kind == "reminder" and self.state:toggleReminder(target.id) then
                UIManager:setDirty(self, "ui", Geom:new{
                    x = target.x, y = target.y, w = target.w, h = target.h,
                })
            elseif target.kind == "kanban" and self.state:advanceKanban(target.id) then
                UIManager:setDirty(self, "ui", Geom:new{
                    x = 0,
                    y = Theme.header_height,
                    w = Screen:getWidth(),
                    h = Screen:getHeight() - Theme.header_height - Theme.footer_height,
                })
            end
            return true
        end
    end
    return false
end

function DashboardView:resize(dimen)
    dimen = dimen or Geom:new{ w = Screen:getWidth(), h = Screen:getHeight() }
    self.dimen = Geom:new{ x = 0, y = 0, w = dimen.w, h = dimen.h }
    self.canvas.dimen = Geom:new{ x = 0, y = 0, w = dimen.w, h = dimen.h }
    if Device:isTouchDevice() then self:updateTouchZonesOnScreenResize(self.dimen) end
    UIManager:setDirty(self, "flashui")
    return true
end

DashboardView.onSetDimensions = DashboardView.resize
DashboardView.onScreenResize = DashboardView.resize

function DashboardView:onClose()
    if self.closed then return true end
    self.closed = true
    self.state:save()
    UIManager:close(self)
    return true
end

function DashboardView:onCloseWidget()
    self.state:save()
    local original_rotation = self.original_rotation
    UIManager:scheduleIn(0.01, function()
        if Screen:getRotationMode() ~= original_rotation then
            UIManager:broadcastEvent(Event:new("SetRotationMode", original_rotation))
            if Screen:getRotationMode() ~= original_rotation then
                Screen:setRotationMode(original_rotation)
                UIManager:broadcastEvent(Event:new("ScreenResize", Geom:new{
                    w = Screen:getWidth(), h = Screen:getHeight(),
                }))
            end
        end
        UIManager:setDirty("all", "flashui")
    end)
end

local KaungDashboard = WidgetContainer:extend{
    name = "kaungdashboard",
    is_doc_only = false,
}

function KaungDashboard:init()
    self.ui.menu:registerToMainMenu(self)
end

function KaungDashboard:addToMainMenu(menu_items)
    menu_items.kaung_dashboard = {
        text = _("Kaung Dashboard"),
        sorting_hint = "more_tools",
        callback = function() self:openDashboard() end,
    }
end

function KaungDashboard:openDashboard()
    local original_rotation = Screen:getRotationMode()
    if Screen:getWidth() < Screen:getHeight() then
        local landscape_mode = Config.landscape_rotation == "counter_clockwise"
            and Screen.DEVICE_ROTATED_COUNTER_CLOCKWISE
            or Screen.DEVICE_ROTATED_CLOCKWISE
        UIManager:broadcastEvent(Event:new("SetRotationMode", landscape_mode))
        if Screen:getRotationMode() ~= landscape_mode then
            Screen:setRotationMode(landscape_mode)
        end
    end

    local dashboard = DashboardView:new{ original_rotation = original_rotation }
    UIManager:show(dashboard, "flashui")
end

return KaungDashboard
