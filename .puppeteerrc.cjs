const { join } = require("path");

// Keep Chrome inside node_modules, which Render carries from build to runtime.
module.exports = {
  cacheDirectory: join(__dirname, "node_modules", ".cache", "puppeteer"),
};
