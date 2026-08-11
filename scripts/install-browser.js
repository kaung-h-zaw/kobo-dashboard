const fs = require("fs");
const path = require("path");
const {
  Browser,
  computeExecutablePath,
  detectBrowserPlatform,
  install,
} = require("@puppeteer/browsers");
const { PUPPETEER_REVISIONS } = require("puppeteer-core/internal/revisions.js");
const puppeteerConfig = require("../.puppeteerrc.cjs");

async function installBrowser() {
  const browser = Browser.CHROME;
  const buildId = PUPPETEER_REVISIONS.chrome;
  const platform = detectBrowserPlatform();
  const cacheDir = puppeteerConfig.cacheDirectory;

  if (!platform) throw new Error("Puppeteer could not detect this build platform");

  const executablePath = computeExecutablePath({
    browser,
    buildId,
    cacheDir,
    platform,
  });

  if (fs.existsSync(executablePath)) {
    console.log("Puppeteer Chrome installation verified.");
    return;
  }

  // Render can restore a partially extracted browser from its build cache.
  // Remove only this exact Chrome version before asking Puppeteer to retry it.
  const browserDirectory = path.join(cacheDir, browser, `${platform}-${buildId}`);
  const expectedCacheRoot = `${path.resolve(cacheDir)}${path.sep}`;
  const resolvedBrowserDirectory = path.resolve(browserDirectory);

  if (!resolvedBrowserDirectory.startsWith(expectedCacheRoot)) {
    throw new Error("Refusing to clean a browser directory outside the Puppeteer cache");
  }

  if (fs.existsSync(browserDirectory)) {
    console.log(`Removing incomplete Puppeteer Chrome ${buildId} installation.`);
    fs.rmSync(browserDirectory, { recursive: true, force: true });
  }

  await install({
    browser,
    buildId,
    cacheDir,
    platform,
    downloadProgressCallback: "default",
  });

  if (!fs.existsSync(executablePath)) {
    throw new Error("Puppeteer Chrome installation could not be verified");
  }

  console.log("Puppeteer Chrome installation verified.");
}

installBrowser().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
