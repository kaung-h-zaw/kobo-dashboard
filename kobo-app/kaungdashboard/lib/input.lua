local ffi = require("ffi")

ffi.cdef[[
typedef long int ssize_t;
typedef unsigned long int size_t;
struct timeval { long tv_sec; long tv_usec; };
struct input_event { struct timeval time; unsigned short type; unsigned short code; int value; };
struct input_absinfo { int value; int minimum; int maximum; int fuzz; int flat; int resolution; };
struct pollfd { int fd; short events; short revents; };
int open(const char *pathname, int flags, ...);
int close(int fd);
ssize_t read(int fd, void *buf, size_t count);
int poll(struct pollfd *fds, unsigned long nfds, int timeout);
int ioctl(int fd, unsigned long request, ...);
]]

local Input = {}
Input.__index = Input

local EV_SYN, EV_KEY, EV_ABS = 0, 1, 3
local SYN_REPORT, ABS_X, ABS_Y = 0, 0, 1
local ABS_MT_TOUCH_MAJOR, ABS_MT_POSITION_X, ABS_MT_POSITION_Y, ABS_MT_TRACKING_ID = 48, 53, 54, 57
local BTN_TOUCH, POLLIN, O_NONBLOCK = 330, 1, 2048

local function first_csv(value)
    return value and value:match("^%s*([^,%s]+)")
end

function Input.new(app_dir, screen, logger)
    local scanner = app_dir .. "/bin/input_scan"
    local pipe = io.popen("'" .. scanner .. "' -q -m touchscreen -p 2>/dev/null", "r")
    local path = pipe and first_csv(pipe:read("*a")) or nil
    if pipe then pipe:close() end
    path = path or "/dev/input/event1"
    local fd = ffi.C.open(path, O_NONBLOCK)
    assert(fd >= 0, "Unable to open touchscreen " .. path)
    local self = setmetatable({
        fd = fd, path = path, screen = screen, logger = logger,
        raw_x = 0, raw_y = 0, active = false, was_active = false,
        touch_major_seen = false,
        queue = {},
        ranges = { x_min = 0, x_max = 1023, y_min = 0, y_max = 757 },
    }, Input)
    self:_readRanges()
    logger:info("Input device detected: " .. path)
    return self
end

function Input:_absInfo(code)
    local info = ffi.new("struct input_absinfo[1]")
    -- Linux UAPI EVIOCGABS(code): _IOR('E', 0x40 + code, struct input_absinfo).
    local request = 0x80184540 + code
    if ffi.C.ioctl(self.fd, request, info) == 0 then return info[0] end
end

function Input:_readRanges()
    local x = self:_absInfo(ABS_MT_POSITION_X) or self:_absInfo(ABS_X)
    local y = self:_absInfo(ABS_MT_POSITION_Y) or self:_absInfo(ABS_Y)
    if x then self.ranges.x_min, self.ranges.x_max = x.minimum, x.maximum end
    if y then self.ranges.y_min, self.ranges.y_max = y.minimum, y.maximum end
    self.logger:info("Touch ranges: x=" .. self.ranges.x_min .. ".." .. self.ranges.x_max
        .. " y=" .. self.ranges.y_min .. ".." .. self.ranges.y_max)
end

function Input:_logicalEvent(kind, sec, usec)
    local x, y = self.screen:rawToLogical(self.raw_x, self.raw_y, self.ranges)
    return { kind = kind, x = x, y = y, time = tonumber(sec) + tonumber(usec) / 1000000 }
end

function Input:nextEvent(timeout_ms)
    if #self.queue > 0 then return table.remove(self.queue, 1) end
    local pollfd = ffi.new("struct pollfd[1]")
    pollfd[0].fd, pollfd[0].events = self.fd, POLLIN
    if ffi.C.poll(pollfd, 1, timeout_ms or 500) <= 0 then return nil end
    local events = ffi.new("struct input_event[32]")
    local bytes = ffi.C.read(self.fd, events, ffi.sizeof(events))
    if bytes <= 0 then return nil end
    local count = math.floor(tonumber(bytes) / ffi.sizeof("struct input_event"))
    for index = 0, count - 1 do
        local event = events[index]
        if event.type == EV_ABS then
            if event.code == ABS_MT_POSITION_X or event.code == ABS_X then self.raw_x = event.value
            elseif event.code == ABS_MT_POSITION_Y or event.code == ABS_Y then self.raw_y = event.value
            elseif event.code == ABS_MT_TOUCH_MAJOR then
                self.touch_major_seen = true
                self.active = event.value > 0
            elseif event.code == ABS_MT_TRACKING_ID and not self.touch_major_seen then
                self.active = event.value >= 0
            end
        elseif event.type == EV_KEY and event.code == BTN_TOUCH then
            self.active = event.value > 0
        elseif event.type == EV_SYN and event.code == SYN_REPORT then
            local result
            if self.active and not self.was_active then result = self:_logicalEvent("down", event.time.tv_sec, event.time.tv_usec)
            elseif self.active and self.was_active then result = self:_logicalEvent("move", event.time.tv_sec, event.time.tv_usec)
            elseif not self.active and self.was_active then result = self:_logicalEvent("up", event.time.tv_sec, event.time.tv_usec) end
            self.was_active = self.active
            if result then table.insert(self.queue, result) end
        end
    end
    if #self.queue > 0 then return table.remove(self.queue, 1) end
end

function Input:close()
    if self.fd then ffi.C.close(self.fd); self.fd = nil end
end

return Input
