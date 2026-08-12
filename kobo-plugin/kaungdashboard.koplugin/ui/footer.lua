local Footer = {}

function Footer.draw(ctx, state)
    local theme = ctx.theme
    local y = ctx.height - theme.footer_height
    ctx:line(theme.margin, y, ctx.width - theme.margin * 2, theme.light, 2)
    local index = state:pageIndex()
    ctx:text(state.current_page:upper(), theme.margin, y + 13, 16, { bold = true })
    ctx:text(index .. " / " .. #state.config.page_order, ctx.width / 2, y + 13, 16, { align = "center", bold = true })
    if state.swipe_count < state.config.hide_swipe_hint_after then
        ctx:text("<  SWIPE     SWIPE  >", ctx.width - theme.margin, y + 13, 15, { align = "right" })
    end
end

return Footer
