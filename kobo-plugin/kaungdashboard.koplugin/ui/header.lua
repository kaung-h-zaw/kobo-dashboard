local Header = {}

function Header.draw(ctx, title)
    local theme = ctx.theme
    ctx:text(title:upper(), theme.margin, 17, 27, { bold = true })
    ctx:text(os.date("%a %d %b  %H:%M"):upper(), ctx.width - 136, 21, 18, { align = "right", bold = true })
    local exit_x, exit_y, exit_w, exit_h = ctx.width - 122, 9, 88, 42
    ctx:box(exit_x, exit_y, exit_w, exit_h, { thickness = 2 })
    ctx:text("EXIT", exit_x + exit_w / 2, exit_y + 10, 18, { align = "center", bold = true })
    ctx:addTarget("exit", "exit", exit_x, exit_y, exit_w, exit_h)
    ctx:line(theme.margin, theme.header_height - 2, ctx.width - theme.margin * 2)
end

return Header
