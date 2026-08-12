local Navigation = {}
Navigation.__index = Navigation

function Navigation.new(order, start_page, wrap)
    local index = 1
    for candidate, name in ipairs(order) do if name == start_page then index = candidate end end
    return setmetatable({ order = order, index = index, wrap = wrap }, Navigation)
end

function Navigation:current()
    return self.order[self.index]
end

function Navigation:move(delta)
    local old_index = self.index
    local next_index = old_index + delta
    if self.wrap then next_index = ((next_index - 1) % #self.order) + 1
    else next_index = math.max(1, math.min(#self.order, next_index)) end
    self.index = next_index
    return self.order[old_index], self.order[next_index], old_index ~= next_index
end

return Navigation
