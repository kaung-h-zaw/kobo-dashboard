const { join } = require("path");

// Use a normal build-output directory because Render prunes .cache directories
// between its build and runtime environments.
module.exports = {
  cacheDirectory: join(__dirname, "render-chrome"),
};
