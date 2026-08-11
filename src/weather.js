const FALLBACK_WEATHER = Object.freeze({
  location: "Bangkok",
  temperature: "31°C",
  condition: "Partly Cloudy",
});

const CACHE_MILLISECONDS = 15 * 60 * 1000;
let cachedWeather;
let cachedAt = 0;
let pendingRequest;

function weatherCondition(code) {
  if (code === 0) return "Clear Sky";
  if (code === 1) return "Mainly Clear";
  if (code === 2) return "Partly Cloudy";
  if (code === 3) return "Overcast";
  if (code === 45 || code === 48) return "Fog";
  if ([51, 53, 55, 56, 57].includes(code)) return "Drizzle";
  if ([61, 63, 65, 66, 67].includes(code)) return "Rain";
  if ([71, 73, 75, 77].includes(code)) return "Snow";
  if ([80, 81, 82].includes(code)) return "Rain Showers";
  if ([85, 86].includes(code)) return "Snow Showers";
  if ([95, 96, 99].includes(code)) return "Thunderstorm";
  return "Unknown";
}

function environmentNumber(name, fallback) {
  const value = Number(process.env[name]);
  return Number.isFinite(value) ? value : fallback;
}

async function fetchWeather() {
  const location = process.env.WEATHER_LOCATION?.trim() || FALLBACK_WEATHER.location;
  const latitude = environmentNumber("WEATHER_LATITUDE", 13.7563);
  const longitude = environmentNumber("WEATHER_LONGITUDE", 100.5018);
  const timeZone = process.env.TIMEZONE || "Asia/Bangkok";
  const url = new URL("https://api.open-meteo.com/v1/forecast");
  url.searchParams.set("latitude", String(latitude));
  url.searchParams.set("longitude", String(longitude));
  url.searchParams.set("current", "temperature_2m,weather_code");
  url.searchParams.set("timezone", timeZone);

  const response = await fetch(url, { signal: AbortSignal.timeout(5000) });
  if (!response.ok) throw new Error(`Weather API returned HTTP ${response.status}`);

  const payload = await response.json();
  const temperature = payload?.current?.temperature_2m;
  const code = payload?.current?.weather_code;
  if (!Number.isFinite(temperature) || !Number.isInteger(code)) {
    throw new Error("Weather API returned incomplete current conditions");
  }

  return {
    location,
    temperature: `${Math.round(temperature)}°C`,
    condition: weatherCondition(code),
  };
}

async function getWeather() {
  if (cachedWeather && Date.now() - cachedAt < CACHE_MILLISECONDS) {
    return cachedWeather;
  }
  if (pendingRequest) return pendingRequest;

  pendingRequest = fetchWeather()
    .then((weather) => {
      cachedWeather = weather;
      cachedAt = Date.now();
      return weather;
    })
    .catch(() => {
      console.warn("Weather refresh failed; using cached or fallback conditions.");
      return cachedWeather || FALLBACK_WEATHER;
    })
    .finally(() => {
      pendingRequest = undefined;
    });

  return pendingRequest;
}

module.exports = {
  FALLBACK_WEATHER,
  getWeather,
  weatherCondition,
};
