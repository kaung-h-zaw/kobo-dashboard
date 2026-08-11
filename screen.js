const puppeteer = require("puppeteer");
const sharp = require("sharp");

const SCREEN_WIDTH = 1024;
const SCREEN_HEIGHT = 758;

let browserPromise;

function escapeHtml(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function renderEmptyItem(message) {
  return `
    <div class="item">
      <div class="content">
        <span class="description">${escapeHtml(message)}</span>
      </div>
    </div>`;
}

function renderEventItem(event) {
  const details = [event.calendar, event.location].filter(Boolean).join(" · ");
  return `
    <div class="item">
      <div class="meta"></div>
      <div class="content">
        <span class="title" data-clamp="1">${escapeHtml(event.title)}</span>
        ${details ? `<span class="description" data-clamp="1">${escapeHtml(details)}</span>` : ""}
        <div class="flex gap--small">
          <span class="label label--underline">${escapeHtml(event.time)}</span>
        </div>
      </div>
    </div>`;
}

function renderReminderItem(reminder) {
  const labels = [reminder.suffix, reminder.list].filter(Boolean);
  return `
    <div class="item${reminder.priority ? " item--emphasis-2" : ""}">
      <div class="meta"></div>
      <div class="content">
        <span class="title" data-clamp="1">${escapeHtml(reminder.marker)} ${escapeHtml(reminder.title)}</span>
        ${reminder.notes ? `<span class="description" data-clamp="1">${escapeHtml(reminder.notes)}</span>` : ""}
        ${labels.length ? `<div class="flex gap--small">${labels.map((label) => `<span class="label label--underline">${escapeHtml(label)}</span>`).join("")}</div>` : ""}
      </div>
    </div>`;
}

function renderGroupedRows(rows, itemRenderer, emptyMessage) {
  if (!rows.length) return renderEmptyItem(emptyMessage);

  return rows
    .map((row) => {
      if (row.kind === "label") {
        return `<span class="label label--small">${escapeHtml(row.label)}</span>`;
      }
      if (row.kind === "empty") return renderEmptyItem(row.title);
      return itemRenderer(row);
    })
    .join("");
}

function renderTrmnlScreen(data) {
  const todayItems = data.todayEvents.length
    ? data.todayEvents.map(renderEventItem).join("")
    : renderEmptyItem("No events today");
  const reminders = renderGroupedRows(data.reminders, renderReminderItem, "No reminders");
  const upcoming = renderGroupedRows(data.upcomingEvents, renderEventItem, "No upcoming events");

  return `
    <div class="screen screen--byod_custom screen--1bit screen--fonts-trmnl screen--no-bleed" data-device="kobo-nia">
      <div class="view view--full">
        <div class="layout">
          <div class="grid grid--cols-3 gap--medium h--full">
            <section class="flex flex--col flex--stretch-x gap--small">
              <div class="flex flex--row flex--between flex--center-y">
                <span class="title">Apple Calendar</span>
                <span class="value value--large">${escapeHtml(data.time)}</span>
              </div>
              <span class="label">${escapeHtml(data.date)}</span>
              <div class="divider"></div>
              <div class="flex flex--col gap--small" data-overflow="true" data-overflow-counter="true" data-overflow-max-height="520">
                ${todayItems}
              </div>
            </section>

            <section class="flex flex--col flex--stretch-x gap--small">
              <span class="title">Apple Reminders</span>
              <span class="label">Open tasks</span>
              <div class="divider"></div>
              <div class="flex flex--col gap--small" data-overflow="true" data-overflow-counter="true" data-overflow-max-height="520">
                ${reminders}
              </div>
            </section>

            <section class="flex flex--col flex--stretch-x gap--small">
              <span class="title">Upcoming Calendar</span>
              <span class="label">Next 7 days</span>
              <div class="divider"></div>
              <div class="flex flex--col gap--small" data-overflow="true" data-overflow-counter="true" data-overflow-max-height="520">
                ${upcoming}
              </div>
            </section>
          </div>
        </div>

        <div class="title_bar">
          <span class="title">Kobo Dashboard</span>
          <span class="instance">Synced ${escapeHtml(data.lastSynced)} · ${escapeHtml(data.weather.location)} ${escapeHtml(data.weather.temperature)} · ${escapeHtml(data.weather.condition)}</span>
        </div>
      </div>
    </div>`;
}

function renderDashboardHtml(data, { preview = false, assetBaseUrl = "" } = {}) {
  const base = assetBaseUrl.replace(/\/+$/, "");
  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=1024, initial-scale=1">
  <title>Kobo Dashboard · TRMNL Framework</title>
  <link rel="stylesheet" href="${escapeHtml(base)}/trmnl/plugins.min.css">
  <style>
    html, body { margin: 0; }
    body { background: ${preview ? "#d8d8d8" : "#fff"}; }
    body > .screen { margin: ${preview ? "24px auto" : "0"}; }
    .screen[data-device="kobo-nia"] {
      --screen-w: ${SCREEN_WIDTH}px;
      --screen-h: ${SCREEN_HEIGHT}px;
      --screen-w-original: ${SCREEN_WIDTH}px;
      --screen-h-original: ${SCREEN_HEIGHT}px;
    }
    .screen[data-device="kobo-nia"] .grid > section,
    .screen[data-device="kobo-nia"] [data-overflow] {
      min-width: 0;
      overflow: hidden;
    }
  </style>
</head>
<body class="environment trmnl">
  ${renderTrmnlScreen(data)}
  <script src="${escapeHtml(base)}/trmnl/plugins.min.js"></script>
</body>
</html>`;
}

async function getBrowser() {
  if (!browserPromise) {
    browserPromise = puppeteer
      .launch({
        headless: true,
        args: ["--no-sandbox", "--disable-setuid-sandbox", "--disable-dev-shm-usage"],
      })
      .then((browser) => {
        browser.once("disconnected", () => {
          browserPromise = undefined;
        });
        return browser;
      })
      .catch((error) => {
        browserPromise = undefined;
        throw error;
      });
  }
  return browserPromise;
}

async function generateDashboardPng(data, { rotate = true, assetBaseUrl = "" } = {}) {
  const browser = await getBrowser();
  const page = await browser.newPage();

  try {
    await page.setViewport({ width: SCREEN_WIDTH, height: SCREEN_HEIGHT, deviceScaleFactor: 1 });
    await page.setContent(renderDashboardHtml(data, { assetBaseUrl }), {
      waitUntil: "domcontentloaded",
    });
    await page.evaluate(async () => {
      await document.fonts.ready;
      await new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve)));
    });

    const logicalPng = await page.screenshot({
      type: "png",
      clip: { x: 0, y: 0, width: SCREEN_WIDTH, height: SCREEN_HEIGHT },
    });

    let pipeline = sharp(logicalPng).grayscale().threshold(128);
    if (rotate) pipeline = pipeline.rotate(90);

    return pipeline
      .png({ palette: true, colors: 2, bitdepth: 1, compressionLevel: 9 })
      .toBuffer();
  } finally {
    await page.close();
  }
}

module.exports = {
  SCREEN_HEIGHT,
  SCREEN_WIDTH,
  generateDashboardPng,
  renderDashboardHtml,
  renderTrmnlScreen,
};
