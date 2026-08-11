const { join } = require("path");

// Render does not carry downloaded browsers from build to runtime. Install into
// the running instance's writable /tmp directory instead.
module.exports = {
  cacheDirectory: process.env.RENDER
    ? join("/tmp", "kobo-dashboard-chrome")
    : join(__dirname, "render-chrome"),
};
