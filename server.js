const express = require("express");
const fs = require("fs");
const path = require("path");
const {
  createScreenSignature,
  requireAppleDataAuthentication,
  requireAppleSyncAuthentication,
  requireDeviceAuthentication,
  requireScreenSignature,
} = require("./src/auth");
const {
  readAppleData,
  validateAppleData,
  writeAppleData,
} = require("./src/appleData");
const { buildDashboardData, buildPreviewAppleData } = require("./src/dashboard");
const { buildDeviceData } = require("./src/deviceData");
const { acknowledgeActions, queueAction, readActions } = require("./src/reminderActions");
const { completeSyncRequest, createSyncRequest, readSyncRequest } = require("./src/syncRequest");
const { getWeather } = require("./src/weather");
const {
  generateDashboardPng,
  renderDashboardHtml,
} = require("./screen");

const app = express();
const PORT = process.env.PORT || 3000;
const HOST = "0.0.0.0";
const TIME_ZONE = process.env.TIMEZONE || "Asia/Bangkok";
const REFRESH_RATE_SECONDS = 1800;
const PREPARING_REFRESH_RATE_SECONDS = 60;
const SCREEN_URL_LIFETIME_SECONDS = 300;
const FALLBACK_SCREEN_PATH = path.join(
  __dirname,
  "public",
  "screens",
  "dashboard-fallback.png",
);

// The native trmnl-kobo client expects image_url to return an image immediately.
// Always keep a valid PNG available while a newer Framework render is prepared.
let cachedScreen = fs.readFileSync(FALLBACK_SCREEN_PATH);
let cachedScreenReady = false;
let cachedScreenUpdatedAt = new Date(0);
let screenRefreshPromise;
let screenRefreshQueued = false;

// Render terminates HTTPS before forwarding requests to Express.
app.set("trust proxy", true);
app.use(express.json({ limit: "256kb" }));
app.use(express.static(path.join(__dirname, "public"), {
  index: false,
  maxAge: "1d",
  // Puppeteer renders HTML with a null origin, so local Framework fonts need
  // an explicit CORS header to load in generated PNGs as well as previews.
  setHeaders(response) {
    response.setHeader("Access-Control-Allow-Origin", "*");
  },
}));

function getBaseUrl(request) {
  const configuredBaseUrl = process.env.BASE_URL?.trim();
  if (configuredBaseUrl) return configuredBaseUrl.replace(/\/+$/, "");
  return `${request.protocol}://${request.get("host")}`;
}

function getRendererBaseUrl() {
  const configuredBaseUrl = process.env.BASE_URL?.trim();
  if (configuredBaseUrl) return configuredBaseUrl.replace(/\/+$/, "");
  return `http://127.0.0.1:${PORT}`;
}

function getScreenFilename() {
  const screenDate = cachedScreenReady ? cachedScreenUpdatedAt : new Date();
  const minute = screenDate.toISOString().slice(0, 16).replaceAll(/[-:T]/g, "");
  return `kobo-dashboard-${minute}.png`;
}

function queueScreenRefresh(reason) {
  if (screenRefreshPromise) {
    screenRefreshQueued = true;
    return screenRefreshPromise;
  }

  screenRefreshPromise = (async () => {
    const appleData = await readAppleData();
    const weather = await getWeather();
    const dashboard = buildDashboardData(appleData, { timeZone: TIME_ZONE, weather });
    const image = await generateDashboardPng(dashboard, {
      assetBaseUrl: getRendererBaseUrl(),
      rotate: process.env.KOBO_ROTATE_IMAGE !== "false",
    });

    // Replace the cache only after a complete PNG has been generated.
    cachedScreen = image;
    cachedScreenReady = true;
    cachedScreenUpdatedAt = new Date();
    console.log(`Dashboard screen cache refreshed (${reason}).`);
  })()
    .catch((error) => {
      console.error("Dashboard screen refresh failed:", error?.message || "Unknown error");
    })
    .finally(() => {
      screenRefreshPromise = undefined;
      if (screenRefreshQueued) {
        screenRefreshQueued = false;
        queueScreenRefresh("queued update");
      }
    });

  return screenRefreshPromise;
}

async function getPreviewData() {
  const now = new Date();
  const weather = await getWeather();
  return buildDashboardData(buildPreviewAppleData(now), {
    now,
    timeZone: TIME_ZONE,
    weather,
  });
}

// Public browser preview uses sample data so private Apple data is never exposed.
app.get("/", async (request, response) => {
  response.type("html").send(renderDashboardHtml(await getPreviewData(), {
    preview: true,
    assetBaseUrl: getBaseUrl(request),
  }));
});

app.get("/dashboard", async (request, response) => {
  response.type("html").send(renderDashboardHtml(await getPreviewData(), {
    assetBaseUrl: getBaseUrl(request),
  }));
});

// Full-size browser preview of the locally vendored TRMNL Framework screen.
app.get("/preview/trmnl", async (request, response) => {
  response.type("html").send(renderDashboardHtml(await getPreviewData(), {
    preview: true,
    assetBaseUrl: getBaseUrl(request),
  }));
});

// Preserve the original public dashboard API with non-private preview data.
app.get("/api/dashboard", async (request, response) => {
  const now = new Date();
  const preview = buildPreviewAppleData(now);
  const weather = await getWeather();
  const dashboard = buildDashboardData(preview, { now, timeZone: TIME_ZONE, weather });

  response.json({
    date: dashboard.date,
    time: dashboard.time,
    events: preview.events,
    upcoming: dashboard.upcomingEvents,
    tasks: preview.reminders,
    weather: dashboard.weather,
  });
});

app.post("/api/apple-sync", requireAppleSyncAuthentication, async (request, response) => {
  let data;
  try {
    data = validateAppleData(request.body);
  } catch (error) {
    return response.status(400).json({ error: error.message });
  }

  await writeAppleData(data);
  await completeSyncRequest();
  queueScreenRefresh("Apple sync");
  response.json({
    status: "ok",
    syncedAt: data.syncedAt,
    reminders: data.reminders.length,
    events: data.events.length,
  });
});

app.get("/api/apple-data", requireAppleDataAuthentication, async (request, response) => {
  response.set("Cache-Control", "no-store").json(await readAppleData());
});

// Structured real data for the standalone interactive Kobo application.
app.get("/api/device-data", requireDeviceAuthentication, async (request, response) => {
  const now = new Date();
  const appleData = await readAppleData();
  const weather = await getWeather();
  const dashboard = buildDashboardData(appleData, { now, timeZone: TIME_ZONE, weather });
  response
    .set("Cache-Control", "private, no-store")
    .json(buildDeviceData(dashboard, { generatedAt: now }));
});

app.post("/api/sync-request", requireDeviceAuthentication, async (request, response) => {
  const syncRequest = await createSyncRequest();
  response.status(202).json({ status: "waiting", ...syncRequest });
});

app.get("/api/sync-request", requireAppleDataAuthentication, async (request, response) => {
  const syncRequest = await readSyncRequest();
  response.set("Cache-Control", "no-store").json({
    status: syncRequest?.completedAt ? "complete" : "waiting",
    ...(syncRequest || {}),
  });
});

app.post("/api/reminder-actions", requireDeviceAuthentication, async (request, response) => {
  try {
    const action = await queueAction(request.body);
    await createSyncRequest();
    response.status(202).json({ status: "queued", id: action.id, completed: action.completed });
  } catch (error) {
    response.status(400).json({ error: error.message });
  }
});

app.get("/api/reminder-actions", requireAppleDataAuthentication, async (request, response) => {
  response.set("Cache-Control", "no-store").json({ actions: await readActions() });
});

app.post("/api/reminder-actions/ack", requireAppleDataAuthentication, async (request, response) => {
  try {
    const acknowledged = await acknowledgeActions(request.body?.ids);
    response.json({ status: "ok", acknowledged });
  } catch (error) {
    response.status(400).json({ error: error.message });
  }
});

// Official TRMNL KOReader clients fetch screen metadata from this endpoint.
app.get("/api/display", requireDeviceAuthentication, (request, response) => {
  // Refresh for the next device cycle without delaying this response or image.
  queueScreenRefresh("device request");

  const filename = getScreenFilename();
  const expiresAt = Math.floor(Date.now() / 1000) + SCREEN_URL_LIFETIME_SECONDS;
  const signature = createScreenSignature(filename, expiresAt);

  if (!signature) {
    return response.status(503).json({ error: "Screen signing is not configured" });
  }

  const imageUrl = new URL("/screens/dashboard.png", getBaseUrl(request));
  imageUrl.searchParams.set("v", filename);
  imageUrl.searchParams.set("expires", String(expiresAt));
  imageUrl.searchParams.set("signature", signature);

  response.set("Cache-Control", "no-store").json({
    image_url: imageUrl.toString(),
    filename,
    refresh_rate: cachedScreenReady
      ? REFRESH_RATE_SECONDS
      : PREPARING_REFRESH_RATE_SECONDS,
  });
});

app.get("/screens/dashboard.png", requireScreenSignature, (request, response) => {
  response
    .set("Cache-Control", "private, no-store")
    .set("X-Dashboard-Screen", cachedScreenReady ? "live" : "preparing")
    .type("png")
    .send(cachedScreen);
});

app.get("/health", (request, response) => {
  response.json({ status: "ok" });
});

// Return controlled JSON errors for malformed or oversized JSON bodies.
app.use((error, request, response, next) => {
  if (error?.type === "entity.too.large") {
    return response.status(413).json({ error: "Request body is too large" });
  }
  if (error instanceof SyntaxError && error.status === 400) {
    return response.status(400).json({ error: "Malformed JSON" });
  }
  console.error("Unhandled server error.");
  response.status(500).json({ error: "Internal server error" });
});

app.listen(PORT, HOST, () => {
  console.log(`Kobo dashboard listening on http://${HOST}:${PORT}`);
  queueScreenRefresh("server startup");
});
