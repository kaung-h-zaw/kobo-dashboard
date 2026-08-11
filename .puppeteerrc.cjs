const { join } = require("path");

// Keep Chromium inside the Render build so it is available at runtime.
module.exports = {
  cacheDirectory: join(__dirname, ".cache", "puppeteer"),
};
