local Kanban = { name = "kanban", title = "Kanban" }
local sections = { {"todo", "TO DO"}, {"in_progress", "IN PROGRESS"}, {"done", "DONE"} }

function Kanban.draw(renderer, state, index, count)
    renderer:beginPage(Kanban.title, index, count)
    local y = 84
    for _, section in ipairs(sections) do
        y = renderer:section(section[2], y)
        local found = false
        for _, item in ipairs(state.kanbanItems) do
            if item.status == section[1] then
                found = true
                local rect = { x = 44, y = y, w = 936, h = 54 }
                renderer:box(rect.x, rect.y, rect.w, rect.h, 2)
                renderer:text(item.title, rect.x + 18, rect.y + 12, 3)
                renderer:addTarget("kanban", item.id, rect.x, rect.y, rect.w, rect.h)
                y = y + 64
            end
        end
        if not found then renderer:text("No items", 55, y + 7, 2, { color = "GRAY6" }); y = y + 42 end
        y = y + 5
    end
    renderer:endPage(Kanban.name)
    return renderer.targets
end

return Kanban
