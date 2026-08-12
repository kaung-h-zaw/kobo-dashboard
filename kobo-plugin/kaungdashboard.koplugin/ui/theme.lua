local Blitbuffer = require("ffi/blitbuffer")

return {
    background = Blitbuffer.COLOR_WHITE,
    foreground = Blitbuffer.COLOR_BLACK,
    muted = Blitbuffer.COLOR_DARK_GRAY,
    light = Blitbuffer.COLOR_LIGHT_GRAY,
    margin = 34,
    header_height = 62,
    footer_height = 44,
    line = 2,
    touch_height = 62,
}
