const fs = require("fs");
const puppeteer = require("puppeteer");

// Fail the Render build instead of deploying without the browser required for PNG rendering.
const executablePath = puppeteer.executablePath();

if (!fs.existsSync(executablePath)) {
  throw new Error("Puppeteer Chrome installation could not be verified");
}

console.log("Puppeteer Chrome installation verified.");
