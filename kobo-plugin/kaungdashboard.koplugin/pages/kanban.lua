local Components = require("ui/components")

local Kanban = { title = "Kanban" }
local sections = {
    { status = "todo", title = "TO DO" },
    { status = "in_progress", title = "IN PROGRESS" },
    { status = "done", title = "DONE" },
}

function Kanban.draw(ctx, state)
    local y = ctx.theme.header_height + 14
    for _, section in ipairs(sections) do
        y = Components.sectionTitle(ctx, section.title, y)
        local had_items = false
        for _, item in ipairs(state.kanban) do
            if item.status == section.status then
                had_items = true
                y = Components.card(ctx, item.title, y, item.id)
            end
        end
        if not had_items then
            ctx:text("No items", ctx.theme.margin + 18, y + 4, 19, { color = ctx.theme.muted })
            y = y + 38
        end
        y = y + 6
    end
end

return Kanban
