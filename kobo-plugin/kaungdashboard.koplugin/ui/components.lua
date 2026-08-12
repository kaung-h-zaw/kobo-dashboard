local Font = require("ui/font")
local RenderText = require("ui/rendertext")

local Components = {}

function Components.newContext(bb, width, height, theme)
    local ctx = { bb = bb, width = width, height = height, theme = theme, targets = {} }

    function ctx:text(text, x, y, size, options)
        options = options or {}
        local face = Font:getFace(options.face or "cfont", size)
        local metrics = RenderText:sizeUtf8Text(0, options.max_width or self.width, face, text, true, options.bold)
        if options.align == "center" then
            x = x - math.floor(metrics.x / 2)
        elseif options.align == "right" then
            x = x - math.floor(metrics.x)
        end
        local _, ascender = face.ftsize:getHeightAndAscender()
        RenderText:renderUtf8Text(self.bb, x, y + math.floor(ascender), face, text, true, options.bold,
            options.color or self.theme.foreground, options.max_width)
        return { w = math.floor(metrics.x), h = math.ceil(metrics.y_top + metrics.y_bottom) }
    end

    function ctx:line(x, y, width, color, thickness)
        self.bb:paintRect(x, y, width, thickness or self.theme.line, color or self.theme.foreground)
    end

    function ctx:box(x, y, width, height, options)
        options = options or {}
        if options.fill then self.bb:paintRect(x, y, width, height, options.fill) end
        self.bb:paintBorder(x, y, width, height, options.thickness or self.theme.line,
            options.color or self.theme.foreground)
    end

    function ctx:addTarget(kind, id, x, y, width, height)
        table.insert(self.targets, { kind = kind, id = id, x = x, y = y, w = width, h = height })
    end

    return ctx
end

function Components.sectionTitle(ctx, title, y)
    ctx:text(title, ctx.theme.margin, y, 20, { bold = true })
    ctx:line(ctx.theme.margin, y + 29, ctx.width - ctx.theme.margin * 2, ctx.theme.light, 2)
    return y + 42
end

function Components.card(ctx, title, y, id)
    local x = ctx.theme.margin
    local width = ctx.width - x * 2
    local height = ctx.theme.touch_height
    ctx:box(x, y, width, height, { thickness = 2 })
    ctx:text(title, x + 22, y + 17, 23, { bold = false, max_width = width - 44 })
    if id then ctx:addTarget("kanban", id, x, y, width, height) end
    return y + height + 10
end

return Components
