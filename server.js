const express = require("express");
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
const { generateDashboardPng, renderDashboardHtml } = require("./screen");

const app = express();
const PORT = process.env.PORT || 3000;
const HOST = "0.0.0.0";
const TIME_ZONE = process.env.TIMEZONE || "Asia/Bangkok";
const REFRESH_RATE_SECONDS = 1800;
const SCREEN_URL_LIFETIME_SECONDS = 300;

// Render terminates HTTPS before forwarding requests to Express.
app.set("trust proxy", true);
app.use(express.json({ limit: "256kb" }));

function getBaseUrl(request) {
  const configuredBaseUrl = process.env.BASE_URL?.trim();
  if (configuredBaseUrl) return configuredBaseUrl.replace(/\/+$/, "");
  return `${request.protocol}://${request.get("host")}`;
}

function getScreenFilename() {
  const minute = new Date().toISOString().slice(0, 16).replaceAll(/[-:T]/g, "");
  return `kobo-dashboard-${minute}.png`;
}

function getPreviewData() {
  const now = new Date();
  return buildDashboardData(buildPreviewAppleData(now), {
    now,
    timeZone: TIME_ZONE,
  });
}

// Public browser preview uses sample data so private Apple data is never exposed.
app.get("/", (request, response) => {
  response.type("html").send(renderDashboardHtml(getPreviewData(), { preview: true }));
});

app.get("/dashboard", (request, response) => {
  response.type("html").send(renderDashboardHtml(getPreviewData()));
});

// Preserve the original public dashboard API with non-private preview data.
app.get("/api/dashboard", (request, response) => {
  const now = new Date();
  const preview = buildPreviewAppleData(now);
  const dashboard = buildDashboardData(preview, { now, timeZone: TIME_ZONE });

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

// Official TRMNL KOReader clients fetch screen metadata from this endpoint.
app.get("/api/display", requireDeviceAuthentication, (request, response) => {
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
    refresh_rate: REFRESH_RATE_SECONDS,
  });
});

app.get("/screens/dashboard.png", requireScreenSignature, async (request, response) => {
  const appleData = await readAppleData();
  const dashboard = buildDashboardData(appleData, { timeZone: TIME_ZONE });
  const image = await generateDashboardPng(dashboard, {
    rotate: process.env.KOBO_ROTATE_IMAGE === "true",
  });

  response.set("Cache-Control", "private, no-store").type("png").send(image);
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
});
