local Logger = {}
Logger.__index = Logger

function Logger.new(path, debug_enabled)
    return setmetatable({ path = path, debug_enabled = debug_enabled }, Logger)
end

function Logger:write(level, message)
    if level == "DEBUG" and not self.debug_enabled then return end
    local file = io.open(self.path, "a")
    if not file then return end
    file:write(os.date("%Y-%m-%d %H:%M:%S"), " [", level, "] ", tostring(message), "\n")
    file:close()
end

function Logger:info(message) self:write("INFO", message) end
function Logger:debug(message) self:write("DEBUG", message) end
function Logger:error(message) self:write("ERROR", message) end

return Logger
