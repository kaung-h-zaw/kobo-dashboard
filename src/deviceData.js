function einkText(value, fallback = "") {
  if (typeof value !== "string") return fallback;
  return value.replaceAll("°", " ");
}

function deviceWeather(weather) {
  const fallbackForecast = [];
  const forecast = Array.isArray(weather?.forecast) ? weather.forecast : fallbackForecast;
  return {
    location: einkText(weather?.location, "Prawet District"),
    temperature: einkText(weather?.temperature, "31 C"),
    condition: einkText(weather?.condition, "Partly Cloudy"),
    apparentTemperature: einkText(weather?.apparentTemperature || weather?.temperature, "31 C"),
    high: einkText(weather?.high, "-- C"),
    low: einkText(weather?.low, "-- C"),
    humidity: einkText(weather?.humidity, "--%"),
    windSpeed: einkText(weather?.windSpeed, "-- KM/H").toUpperCase(),
    forecast: forecast.slice(0, 4).map((day) => ({
      day: einkText(day.day, "---").toUpperCase(),
      condition: einkText(day.condition, "Unknown").toUpperCase(),
      high: einkText(day.high, "-- C"),
      low: einkText(day.low, "-- C"),
    })),
  };
}

function deviceEvents(rows) {
  return rows
    .filter((row) => row.kind === "event")
    .map((row) => ({
      time: einkText(row.time, "--:--").toUpperCase(),
      title: einkText(row.title, "Untitled event"),
      calendar: einkText(row.calendar),
    }));
}

function deviceReminders(rows) {
  let group = "TODAY";
  const reminders = [];
  for (const row of rows) {
    if (row.kind === "label") {
      group = row.label === "COMPLETED" ? "COMPLETED" : (row.label === "UPCOMING" ? "UPCOMING" : "TODAY");
    } else if (row.kind === "reminder") {
      reminders.push({
        id: einkText(row.id),
        group,
        title: einkText(row.title, "Untitled reminder"),
        due: row.suffix ? `Due ${einkText(row.suffix)}` : null,
        completed: Boolean(row.completed),
      });
    }
  }
  return reminders;
}

function buildDeviceData(dashboard, { generatedAt = new Date() } = {}) {
  return {
    version: 1,
    generatedAt: generatedAt.toISOString(),
    syncedAt: dashboard.lastSynced,
    refreshSeconds: 300,
    weather: deviceWeather(dashboard.weather),
    events: deviceEvents(dashboard.todayEvents),
    upcomingEvents: deviceEvents(dashboard.upcomingEvents),
    reminders: deviceReminders(dashboard.reminders),
  };
}

module.exports = { buildDeviceData, deviceReminders, deviceWeather };
