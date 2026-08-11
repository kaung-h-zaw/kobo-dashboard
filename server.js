const express = require("express");
const crypto = require("crypto");
const { generateDashboardPng } = require("./screen");

const app = express();
const PORT = process.env.PORT || 3000;
const HOST = "0.0.0.0";
const TIME_ZONE = process.env.TIMEZONE || "Asia/Bangkok";
const REFRESH_RATE_SECONDS = 1800;

// Render terminates HTTPS before forwarding requests to Express.
app.set("trust proxy", true);

// This version keeps its sample data in memory. Later, these functions can read
// from calendar, task, and weather services without changing the routes.
const events = [
  { time: "18:30", title: "Study JavaScript" },
  { time: "20:00", title: "Call family" },
];

const upcoming = [
  { day: "Tomorrow", time: "09:00", title: "University" },
  { day: "Tomorrow", time: "14:00", title: "Project work" },
];

const tasks = [
  { title: "Finish assignment", completed: false },
  { title: "Apply for jobs", completed: false },
  { title: "Buy groceries", completed: false },
];

const weather = {
  location: "Bangkok",
  temperature: "31°C",
  condition: "Partly Cloudy",
};

// Build a fresh dashboard payload for every request so date and time stay current.
function getDashboardData() {
  const now = new Date();

  return {
    date: new Intl.DateTimeFormat("en-US", {
      weekday: "long",
      day: "numeric",
      month: "long",
      timeZone: TIME_ZONE,
    }).format(now),
    time: new Intl.DateTimeFormat("en-GB", {
      hour: "2-digit",
      minute: "2-digit",
      hour12: false,
      timeZone: TIME_ZONE,
    }).format(now),
    events,
    upcoming,
    tasks,
    weather,
  };
}

function hasValidApiKey(request) {
  const expected = process.env.DEVICE_API_KEY;
  const provided = request.get("access-token");

  if (!expected || !provided) return false;

  const expectedBuffer = Buffer.from(expected);
  const providedBuffer = Buffer.from(provided);

  return (
    expectedBuffer.length === providedBuffer.length &&
    crypto.timingSafeEqual(expectedBuffer, providedBuffer)
  );
}

function requireDeviceApiKey(request, response, next) {
  if (!process.env.DEVICE_API_KEY) {
    return response.status(503).json({ error: "DEVICE_API_KEY is not configured" });
  }

  if (!hasValidApiKey(request)) {
    return response.status(401).json({ error: "Invalid access-token" });
  }

  next();
}

function getBaseUrl(request) {
  const configuredBaseUrl = process.env.BASE_URL?.trim();
  if (configuredBaseUrl) return configuredBaseUrl.replace(/\/+$/, "");

  // The fallback makes local development work without extra configuration.
  return `${request.protocol}://${request.get("host")}`;
}

function getScreenFilename() {
  // A minute-specific filename tells the plugin when its cached image is stale.
  const minute = new Date().toISOString().slice(0, 16).replaceAll(/[-:T]/g, "");
  return `kobo-dashboard-${minute}.png`;
}

function renderEvent(event) {
  return `
    <li class="event">
      <time>${event.time}</time>
      <span>${event.title}</span>
    </li>`;
}

function renderTask(task) {
  return `
    <li class="task">
      <span class="checkbox" aria-hidden="true"></span>
      <span>${task.title}</span>
    </li>`;
}

function renderUpcoming(item) {
  return `
    <li class="event upcoming">
      <span class="day">${item.day}</span>
      <time>${item.time}</time>
      <span>${item.title}</span>
    </li>`;
}

// Both browser routes use the same semantic page. Preview mode adds a frame
// around the exact 758 × 1024 Kobo canvas so it is easy to inspect on a laptop.
function renderDashboard({ preview = false } = {}) {
  const data = getDashboardData();
  const pageClass = preview ? "preview" : "device";

  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=758, initial-scale=1">
  <title>Kobo Dashboard</title>
  <style>
    * { box-sizing: border-box; }

    html, body {
      margin: 0;
      padding: 0;
      background: #fff;
      color: #000;
      font-family: Arial, Helvetica, sans-serif;
    }

    body.preview {
      min-width: 758px;
      padding: 24px;
      background: #d8d8d8;
    }

    .dashboard {
      width: 758px;
      height: 1024px;
      overflow: hidden;
      padding: 42px 44px 36px;
      background: #fff;
    }

    .preview .dashboard {
      margin: 0 auto;
      border: 2px solid #000;
    }

    header {
      display: flex;
      align-items: flex-start;
      justify-content: space-between;
      min-height: 150px;
      padding-bottom: 28px;
      border-bottom: 6px solid #000;
    }

    h1 {
      max-width: 440px;
      margin: 0;
      font-size: 39px;
      line-height: 1.12;
    }

    .clock {
      margin: -7px 0 0 20px;
      font-size: 64px;
      font-weight: 700;
      line-height: 1;
      white-space: nowrap;
    }

    main {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 0 34px;
    }

    section {
      min-width: 0;
      padding: 28px 0 24px;
      border-bottom: 3px solid #000;
    }

    section.full { grid-column: 1 / -1; }

    h2 {
      margin: 0 0 19px;
      font-size: 25px;
      line-height: 1;
      letter-spacing: 2px;
      text-transform: uppercase;
    }

    ul {
      margin: 0;
      padding: 0;
      list-style: none;
    }

    .event,
    .task {
      display: flex;
      align-items: center;
      min-height: 49px;
      font-size: 25px;
      font-weight: 700;
      line-height: 1.2;
    }

    .event + .event,
    .task + .task { margin-top: 11px; }

    .event time {
      width: 105px;
      flex: 0 0 105px;
      font-size: 24px;
      font-weight: 400;
    }

    .upcoming .day {
      width: 145px;
      flex: 0 0 145px;
      font-size: 23px;
      font-weight: 400;
    }

    .upcoming time {
      width: 95px;
      flex-basis: 95px;
    }

    .checkbox {
      width: 26px;
      height: 26px;
      flex: 0 0 26px;
      margin-right: 16px;
      border: 3px solid #000;
    }

    .weather-row {
      display: flex;
      align-items: center;
      justify-content: space-between;
    }

    .weather-location {
      margin: 0 0 7px;
      font-size: 28px;
      font-weight: 700;
    }

    .weather-condition {
      margin: 0;
      font-size: 24px;
    }

    .temperature {
      margin: 0 0 0 24px;
      font-size: 60px;
      font-weight: 700;
      line-height: 1;
    }

    footer {
      padding-top: 25px;
      font-size: 18px;
      font-weight: 700;
      letter-spacing: 1px;
      text-align: center;
      text-transform: uppercase;
    }
  </style>
</head>
<body class="${pageClass}">
  <div class="dashboard">
    <header>
      <div>
        <h1>${data.date}</h1>
      </div>
      <p class="clock">${data.time}</p>
    </header>

    <main>
      <section class="full" aria-labelledby="today-heading">
        <h2 id="today-heading">Today</h2>
        <ul>${data.events.map(renderEvent).join("")}</ul>
      </section>

      <section class="full" aria-labelledby="reminders-heading">
        <h2 id="reminders-heading">Upcoming</h2>
        <ul>${data.upcoming.map(renderUpcoming).join("")}</ul>
      </section>

      <section class="full" aria-labelledby="tasks-heading">
        <h2 id="tasks-heading">Tasks</h2>
        <ul>${data.tasks.map(renderTask).join("")}</ul>
      </section>

      <section class="full" aria-labelledby="weather-heading">
        <h2 id="weather-heading">Weather</h2>
        <div class="weather-row">
          <div>
            <p class="weather-location">${data.weather.location}</p>
            <p class="weather-condition">${data.weather.condition}</p>
          </div>
          <p class="temperature">${data.weather.temperature}</p>
        </div>
      </section>
    </main>

    <footer>Kobo dashboard · Sample data</footer>
  </div>
</body>
</html>`;
}

// Normal desktop preview with a border around the Kobo-sized canvas.
app.get("/", (req, res) => {
  res.type("html").send(renderDashboard({ preview: true }));
});

// The unframed, fixed-size page intended for the Kobo browser or a renderer.
app.get("/dashboard", (req, res) => {
  res.type("html").send(renderDashboard());
});

// Data endpoint kept separate so a future TRMNL adapter can reuse the payload.
app.get("/api/dashboard", (req, res) => {
  res.json(getDashboardData());
});

// Official TRMNL KOReader clients fetch screen metadata from this endpoint.
app.get("/api/display", requireDeviceApiKey, (req, res) => {
  const filename = getScreenFilename();
  const imageUrl = new URL("/screens/dashboard.png", getBaseUrl(req));
  imageUrl.searchParams.set("v", filename);

  res.set("Cache-Control", "no-store").json({
    image_url: imageUrl.toString(),
    filename,
    refresh_rate: REFRESH_RATE_SECONDS,
  });
});

// Image downloads are public because the KOReader plugin does not forward the
// access-token when it follows image_url. The browser dashboard is public too.
app.get("/screens/dashboard.png", async (req, res) => {
  const image = await generateDashboardPng(getDashboardData());

  res
    .set("Cache-Control", "no-store")
    .type("png")
    .send(image);
});

app.get("/health", (req, res) => {
  res.json({ status: "ok" });
});

app.listen(PORT, HOST, () => {
  console.log(`Kobo dashboard listening on http://${HOST}:${PORT}`);
});
