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

// Sharp converts this small SVG directly into a two-color PNG. This avoids a
// headless browser and works with Render's normal Node runtime.
async function generateDashboardPng(data) {
  const svg = `
  <svg xmlns="http://www.w3.org/2000/svg" width="${SCREEN_WIDTH}" height="${SCREEN_HEIGHT}" viewBox="0 0 ${SCREEN_WIDTH} ${SCREEN_HEIGHT}">
    <rect width="100%" height="100%" fill="white"/>
    <style>
      text { fill: black; font-family: Arial, Helvetica, sans-serif; }
      .label { font-size: 22px; font-weight: 700; letter-spacing: 3px; }
      .date { font-size: 37px; font-weight: 700; }
      .clock { font-size: 64px; font-weight: 700; }
      .section { font-size: 24px; font-weight: 700; letter-spacing: 2px; }
      .event-time { font-size: 24px; }
      .item { font-size: 25px; font-weight: 700; }
      .weather-place { font-size: 29px; font-weight: 700; }
      .weather-detail { font-size: 24px; }
      .temperature { font-size: 60px; font-weight: 700; }
      .footer { font-size: 17px; font-weight: 700; letter-spacing: 1px; }
    </style>

    <text x="46" y="66" class="label">TODAY</text>
    <text x="46" y="118" class="date">${escapeXml(data.date)}</text>
    <text x="712" y="78" text-anchor="end" class="clock">${escapeXml(data.time)}</text>
    <line x1="44" y1="158" x2="714" y2="158" stroke="black" stroke-width="6"/>

    <text x="46" y="208" class="section">TODAY</text>
    ${renderEvent(data.events[0], 259)}
    ${renderEvent(data.events[1], 311)}
    <line x1="44" y1="344" x2="714" y2="344" stroke="black" stroke-width="3"/>

    <text x="46" y="394" class="section">UPCOMING REMINDERS</text>
    ${renderEvent(data.events[0], 445)}
    ${renderEvent(data.events[1], 497)}
    <line x1="44" y1="530" x2="714" y2="530" stroke="black" stroke-width="3"/>

    <text x="46" y="580" class="section">TASKS</text>
    ${renderTask(data.tasks[0], 631)}
    ${renderTask(data.tasks[1], 683)}
    ${renderTask(data.tasks[2], 735)}
    <line x1="44" y1="770" x2="714" y2="770" stroke="black" stroke-width="3"/>

    <text x="46" y="820" class="section">WEATHER</text>
    <text x="46" y="873" class="weather-place">${escapeXml(data.weather.location)}</text>
    <text x="46" y="913" class="weather-detail">${escapeXml(data.weather.condition)}</text>
    <text x="712" y="895" text-anchor="end" class="temperature">${escapeXml(data.weather.temperature)}</text>

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

