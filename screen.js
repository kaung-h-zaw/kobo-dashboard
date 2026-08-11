const sharp = require("sharp");

const SCREEN_WIDTH = 758;
const SCREEN_HEIGHT = 1024;

// Dashboard values are currently trusted sample data. Escaping here also keeps
// the image generator safe when real calendar and task services are added.
function escapeXml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&apos;");
}

function renderEvent(event, y) {
  return `
    <text x="46" y="${y}" class="event-time">${escapeXml(event.time)}</text>
    <text x="160" y="${y}" class="item">${escapeXml(event.title)}</text>`;
}

function renderTask(task, y) {
  return `
    <rect x="48" y="${y - 24}" width="25" height="25" fill="white" stroke="black" stroke-width="3"/>
    <text x="94" y="${y}" class="item">${escapeXml(task.title)}</text>`;
}

function renderUpcoming(item, y) {
  return `
    <text x="46" y="${y}" class="upcoming-day">${escapeXml(item.day)}</text>
    <text x="190" y="${y}" class="event-time">${escapeXml(item.time)}</text>
    <text x="304" y="${y}" class="item">${escapeXml(item.title)}</text>`;
}

// Sharp converts this small SVG directly into a two-color PNG. This avoids a
// headless browser and works with Render's normal Node runtime.
async function generateDashboardPng(data) {
  const svg = `
  <svg xmlns="http://www.w3.org/2000/svg" width="${SCREEN_WIDTH}" height="${SCREEN_HEIGHT}" viewBox="0 0 ${SCREEN_WIDTH} ${SCREEN_HEIGHT}">
    <rect width="100%" height="100%" fill="white"/>
    <style>
      text { fill: black; font-family: Arial, Helvetica, sans-serif; }
      .date { font-size: 37px; font-weight: 700; }
      .clock { font-size: 64px; font-weight: 700; }
      .section { font-size: 24px; font-weight: 700; letter-spacing: 2px; }
      .event-time { font-size: 24px; }
      .upcoming-day { font-size: 23px; }
      .item { font-size: 25px; font-weight: 700; }
      .weather-place { font-size: 29px; font-weight: 700; }
      .weather-detail { font-size: 24px; }
      .temperature { font-size: 60px; font-weight: 700; }
      .footer { font-size: 17px; font-weight: 700; letter-spacing: 1px; }
    </style>

    <text x="46" y="78" class="date">${escapeXml(data.date)}</text>
    <text x="712" y="78" text-anchor="end" class="clock">${escapeXml(data.time)}</text>
    <line x1="44" y1="130" x2="714" y2="130" stroke="black" stroke-width="6"/>

    <text x="46" y="180" class="section">TODAY</text>
    ${renderEvent(data.events[0], 231)}
    ${renderEvent(data.events[1], 283)}
    <line x1="44" y1="316" x2="714" y2="316" stroke="black" stroke-width="3"/>

    <text x="46" y="366" class="section">UPCOMING</text>
    ${renderUpcoming(data.upcoming[0], 417)}
    ${renderUpcoming(data.upcoming[1], 469)}
    <line x1="44" y1="502" x2="714" y2="502" stroke="black" stroke-width="3"/>

    <text x="46" y="552" class="section">TASKS</text>
    ${renderTask(data.tasks[0], 603)}
    ${renderTask(data.tasks[1], 655)}
    ${renderTask(data.tasks[2], 707)}
    <line x1="44" y1="742" x2="714" y2="742" stroke="black" stroke-width="3"/>

    <text x="46" y="792" class="section">WEATHER</text>
    <text x="46" y="845" class="weather-place">${escapeXml(data.weather.location)}</text>
    <text x="46" y="885" class="weather-detail">${escapeXml(data.weather.condition)}</text>
    <text x="712" y="867" text-anchor="end" class="temperature">${escapeXml(data.weather.temperature)}</text>

    <text x="379" y="980" text-anchor="middle" class="footer">KOBO DASHBOARD · SAMPLE DATA</text>
  </svg>`;

  return sharp(Buffer.from(svg))
    .grayscale()
    .threshold(128)
    .png({ palette: true, colors: 2, bitdepth: 1, compressionLevel: 9 })
    .toBuffer();
}

module.exports = {
  SCREEN_HEIGHT,
  SCREEN_WIDTH,
  generateDashboardPng,
};
