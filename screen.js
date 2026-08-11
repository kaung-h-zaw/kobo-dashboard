const sharp = require("sharp");

const SCREEN_WIDTH = 1024;
const SCREEN_HEIGHT = 758;

function escapeXml(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&apos;");
}

function renderSimpleRows(rows, startX, startY) {
  if (!rows.length) {
    return `<text x="${startX}" y="${startY}" class="muted">No events</text>`;
  }

  return rows
    .map(
      (row, index) => `
        <text x="${startX}" y="${startY + index * 55}" class="row-time">${escapeXml(row.time)}</text>
        <text x="${startX + 86}" y="${startY + index * 55}" class="row-title">${escapeXml(row.title)}</text>`,
    )
    .join("");
}

function renderReminderRows(rows, startX, startY) {
  let y = startY;
  return rows
    .map((row) => {
      if (row.kind === "label") {
        const output = `<text x="${startX}" y="${y}" class="group-label">${escapeXml(row.label)}</text>`;
        y += 38;
        return output;
      }
      if (row.kind === "empty") {
        const output = `<text x="${startX}" y="${y}" class="muted">${escapeXml(row.title)}</text>`;
        y += 48;
        return output;
      }

      const suffix = row.suffix
        ? `<text x="${startX + 296}" y="${y}" text-anchor="end" class="row-suffix">${escapeXml(row.suffix)}</text>`
        : "";
      const output = `
        <text x="${startX}" y="${y}" class="marker">${escapeXml(row.marker)}</text>
        <text x="${startX + 50}" y="${y}" class="row-title">${escapeXml(row.title)}</text>
        ${suffix}`;
      y += 48;
      return output;
    })
    .join("");
}

function renderUpcomingRows(rows, startX, startY) {
  let y = startY;
  return rows
    .map((row) => {
      if (row.kind === "label") {
        const output = `<text x="${startX}" y="${y}" class="group-label">${escapeXml(row.label)}</text>`;
        y += 40;
        return output;
      }
      if (row.kind === "empty") {
        const output = `<text x="${startX}" y="${y}" class="muted">${escapeXml(row.title)}</text>`;
        y += 48;
        return output;
      }

      const output = `
        <text x="${startX}" y="${y}" class="row-time">${escapeXml(row.time)}</text>
        <text x="${startX + 86}" y="${y}" class="row-title">${escapeXml(row.title)}</text>`;
      y += 52;
      return output;
    })
    .join("");
}

function renderDashboardSvg(data) {
  return `
  <svg xmlns="http://www.w3.org/2000/svg" width="${SCREEN_WIDTH}" height="${SCREEN_HEIGHT}" viewBox="0 0 ${SCREEN_WIDTH} ${SCREEN_HEIGHT}">
    <rect width="100%" height="100%" fill="white"/>
    <style>
      text { fill: black; font-family: Arial, Helvetica, sans-serif; }
      .top-date { font-size: 34px; font-weight: 700; }
      .top-time { font-size: 48px; font-weight: 700; }
      .weather { font-size: 28px; font-weight: 700; }
      .weather-detail { font-size: 17px; }
      .section { font-size: 25px; font-weight: 700; letter-spacing: 2px; }
      .group-label { font-size: 17px; font-weight: 700; letter-spacing: 1px; }
      .row-time { font-size: 21px; }
      .row-title { font-size: 22px; font-weight: 700; }
      .row-suffix { font-size: 17px; }
      .marker { font-size: 20px; font-weight: 700; }
      .muted { font-size: 21px; }
      .footer { font-size: 18px; font-weight: 700; }
    </style>
    <clipPath id="left-column"><rect x="22" y="104" width="310" height="588"/></clipPath>
    <clipPath id="center-column"><rect x="356" y="104" width="310" height="588"/></clipPath>
    <clipPath id="right-column"><rect x="692" y="104" width="310" height="588"/></clipPath>

    <text x="30" y="59" class="top-date">${escapeXml(data.date)}</text>
    <text x="512" y="61" text-anchor="middle" class="top-time">${escapeXml(data.time)}</text>
    <text x="994" y="48" text-anchor="end" class="weather">${escapeXml(data.weather.location)} ${escapeXml(data.weather.temperature)}</text>
    <text x="994" y="72" text-anchor="end" class="weather-detail">${escapeXml(data.weather.condition)}</text>
    <line x1="22" y1="92" x2="1002" y2="92" stroke="black" stroke-width="3"/>

    <line x1="341" y1="110" x2="341" y2="698" stroke="black" stroke-width="2"/>
    <line x1="682" y1="110" x2="682" y2="698" stroke="black" stroke-width="2"/>

    <g clip-path="url(#left-column)">
      <text x="30" y="137" class="section">TODAY</text>
      ${renderSimpleRows(data.todayEvents, 30, 188)}
    </g>

    <g clip-path="url(#center-column)">
      <text x="365" y="137" class="section">REMINDERS</text>
      ${renderReminderRows(data.reminders, 365, 179)}
    </g>

    <g clip-path="url(#right-column)">
      <text x="700" y="137" class="section">UPCOMING</text>
      ${renderUpcomingRows(data.upcomingEvents, 700, 179)}
    </g>

    <line x1="22" y1="704" x2="1002" y2="704" stroke="black" stroke-width="3"/>
    <text x="30" y="738" class="footer">Last synced: ${escapeXml(data.lastSynced)}</text>
    <text x="994" y="738" text-anchor="end" class="footer">Dashboard refreshed: ${escapeXml(data.refreshedAt)}</text>
  </svg>`;
}

function renderDashboardHtml(data, { preview = false } = {}) {
  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=1024, initial-scale=1">
  <title>Kobo Dashboard</title>
  <style>
    * { box-sizing: border-box; }
    html, body { margin: 0; background: ${preview ? "#d8d8d8" : "#fff"}; }
    body { min-width: 1024px; padding: ${preview ? "24px" : "0"}; }
    .screen { width: 1024px; height: 758px; margin: 0 auto; background: #fff; ${preview ? "border: 2px solid #000;" : ""} }
    svg { display: block; width: 1024px; height: 758px; }
  </style>
</head>
<body><main class="screen">${renderDashboardSvg(data)}</main></body>
</html>`;
}

async function generateDashboardPng(data, { rotate = false } = {}) {
  let pipeline = sharp(Buffer.from(renderDashboardSvg(data)))
    .grayscale()
    .threshold(128);

  if (rotate) pipeline = pipeline.rotate(90);

  return pipeline
    .png({ palette: true, colors: 2, bitdepth: 1, compressionLevel: 9 })
    .toBuffer();
}

module.exports = {
  SCREEN_HEIGHT,
  SCREEN_WIDTH,
  generateDashboardPng,
  renderDashboardHtml,
  renderDashboardSvg,
};
