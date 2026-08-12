local Kanban = { name = "kanban", title = "Kanban" }
local sections = {
    { "todo", "TO DO", 24 },
    { "in_progress", "IN PROGRESS", 355 },
    { "done", "DONE", 686 },
}

local function status_count(state, status)
    local count = 0
    for _, item in ipairs(state.kanbanItems) do
        if item.status == status then count = count + 1 end
    end
    return count
end

local function wrap_title(title)
    if #title <= 16 then return title, nil end
    local split = 16
    while split > 1 and title:sub(split, split) ~= " " do split = split - 1 end
    if split == 1 then return title:sub(1, 16), title:sub(17, 29) .. (#title > 29 and "..." or "") end
    local second = title:sub(split + 1)
    if #second > 16 then second = second:sub(1, 13) .. "..." end
    return title:sub(1, split - 1), second
end

function Kanban.draw(renderer, state, index, count)
    renderer:beginPage(Kanban.title, index, count)

    for _, section in ipairs(sections) do
        local status, title, x = section[1], section[2], section[3]
        local width = 314
        renderer:box(x, 86, width, 610, 1)
        renderer:fill(x + 1, 87, width - 2, 54, "BLACK")
        renderer:text(title, x + 16, 103, 2, { bold = true, color = "WHITE" })
        renderer:text(tostring(status_count(state, status)), x + width - 34, 103, 2, { bold = true, color = "WHITE" })

        local y = 158
        local found = false
        for _, item in ipairs(state.kanbanItems) do
            if item.status == status then
                found = true
                local rect = { x = x + 12, y = y, w = width - 24, h = 88 }
                renderer:box(rect.x, rect.y, rect.w, rect.h, 1)
                renderer:label(status == "in_progress" and "Doing" or title, rect.x + 14, rect.y + 10, { scale = 1 })
                local first_line, second_line = wrap_title(item.title)
                renderer:text(first_line, rect.x + 14, rect.y + 32, 2, {
                    bold = true,
                    color = status == "done" and "GRAY6" or "BLACK",
                })
                if second_line then
                    renderer:text(second_line, rect.x + 14, rect.y + 62, 1, {
                        bold = true,
                        color = status == "done" and "GRAY6" or "BLACK",
                    })
                end
                renderer:addTarget("kanban", item.id, rect.x, rect.y, rect.w, rect.h)
                y = y + 102
            end
        end
        if not found then
            renderer:text("NO ITEMS", x + 24, 174, 2, { color = "GRAY6" })
        end
    end

    renderer:endPage(Kanban.name)
    return renderer.targets
end

return Kanban
