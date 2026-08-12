local Json = { null = {} }

local function utf8_character(codepoint)
    if codepoint <= 0x7F then return string.char(codepoint) end
    if codepoint <= 0x7FF then
        return string.char(0xC0 + math.floor(codepoint / 0x40), 0x80 + (codepoint % 0x40))
    end
    if codepoint <= 0xFFFF then
        return string.char(
            0xE0 + math.floor(codepoint / 0x1000),
            0x80 + (math.floor(codepoint / 0x40) % 0x40),
            0x80 + (codepoint % 0x40)
        )
    end
    return string.char(
        0xF0 + math.floor(codepoint / 0x40000),
        0x80 + (math.floor(codepoint / 0x1000) % 0x40),
        0x80 + (math.floor(codepoint / 0x40) % 0x40),
        0x80 + (codepoint % 0x40)
    )
end

function Json.decode(source)
    assert(type(source) == "string", "JSON input must be a string")
    local position, length = 1, #source

    local function fail(message)
        error("JSON decode error at byte " .. position .. ": " .. message, 0)
    end

    local function skip_space()
        while position <= length and source:sub(position, position):match("%s") do
            position = position + 1
        end
    end

    local parse_value

    local function parse_string()
        if source:sub(position, position) ~= '"' then fail("expected string") end
        position = position + 1
        local parts, start = {}, position
        while position <= length do
            local character = source:sub(position, position)
            if character == '"' then
                parts[#parts + 1] = source:sub(start, position - 1)
                position = position + 1
                return table.concat(parts)
            elseif character == "\\" then
                parts[#parts + 1] = source:sub(start, position - 1)
                position = position + 1
                local escape = source:sub(position, position)
                local simple = { ['"'] = '"', ["\\"] = "\\", ["/"] = "/", b = "\b", f = "\f", n = "\n", r = "\r", t = "\t" }
                if simple[escape] then
                    parts[#parts + 1] = simple[escape]
                    position = position + 1
                elseif escape == "u" then
                    local hexadecimal = source:sub(position + 1, position + 4)
                    local codepoint = tonumber(hexadecimal, 16)
                    if not codepoint or #hexadecimal ~= 4 then fail("invalid Unicode escape") end
                    position = position + 5
                    parts[#parts + 1] = utf8_character(codepoint)
                else
                    fail("invalid string escape")
                end
                start = position
            elseif character:byte() < 32 then
                fail("control character in string")
            else
                position = position + 1
            end
        end
        fail("unterminated string")
    end

    local function parse_number()
        local number_text = source:sub(position):match("^-?%d+%.?%d*[eE]?[+-]?%d*")
        local number = number_text and tonumber(number_text)
        if not number then fail("invalid number") end
        position = position + #number_text
        return number
    end

    local function parse_array()
        position = position + 1
        skip_space()
        local result = {}
        if source:sub(position, position) == "]" then position = position + 1; return result end
        while true do
            result[#result + 1] = parse_value()
            skip_space()
            local character = source:sub(position, position)
            if character == "]" then position = position + 1; return result end
            if character ~= "," then fail("expected ',' or ']'") end
            position = position + 1
            skip_space()
        end
    end

    local function parse_object()
        position = position + 1
        skip_space()
        local result = {}
        if source:sub(position, position) == "}" then position = position + 1; return result end
        while true do
            local key = parse_string()
            skip_space()
            if source:sub(position, position) ~= ":" then fail("expected ':'") end
            position = position + 1
            result[key] = parse_value()
            skip_space()
            local character = source:sub(position, position)
            if character == "}" then position = position + 1; return result end
            if character ~= "," then fail("expected ',' or '}'") end
            position = position + 1
            skip_space()
        end
    end

    parse_value = function()
        skip_space()
        local character = source:sub(position, position)
        if character == '"' then return parse_string() end
        if character == "{" then return parse_object() end
        if character == "[" then return parse_array() end
        if character == "-" or character:match("%d") then return parse_number() end
        if source:sub(position, position + 3) == "true" then position = position + 4; return true end
        if source:sub(position, position + 4) == "false" then position = position + 5; return false end
        if source:sub(position, position + 3) == "null" then position = position + 4; return Json.null end
        fail("unexpected value")
    end

    local result = parse_value()
    skip_space()
    if position <= length then fail("trailing content") end
    return result
end

return Json
