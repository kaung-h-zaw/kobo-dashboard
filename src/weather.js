const FALLBACK_WEATHER = Object.freeze({
  location: "Prawet District",
  temperature: "31°C",
  condition: "Partly Cloudy",
  apparentTemperature: "34°C",
  high: "34°C",
  low: "27°C",
  humidity: "68%",
  windSpeed: "9 km/h",
  forecast: [
    { day: "THU", condition: "Cloudy", high: "33°C", low: "27°C" },
    { day: "FRI", condition: "Rain", high: "32°C", low: "26°C" },
    { day: "SAT", condition: "Sunny", high: "34°C", low: "27°C" },
    { day: "SUN", condition: "Cloudy", high: "33°C", low: "26°C" },
  ],
});

const CACHE_MILLISECONDS = 5 * 60 * 1000;
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
  const location = process.env.WEATHER_LOCATION?.trim() || "Prawet District";
  const latitude = environmentNumber("WEATHER_LATITUDE", 13.717);
  const longitude = environmentNumber("WEATHER_LONGITUDE", 100.694);
  const timeZone = process.env.TIMEZONE || "Asia/Bangkok";
  const url = new URL("https://api.open-meteo.com/v1/forecast");
  url.searchParams.set("latitude", String(latitude));
  url.searchParams.set("longitude", String(longitude));
  url.searchParams.set(
    "current",
    "temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,wind_speed_10m",
  );
  url.searchParams.set("daily", "weather_code,temperature_2m_max,temperature_2m_min");
  url.searchParams.set("forecast_days", "5");
  url.searchParams.set("timezone", timeZone);

  const response = await fetch(url, { signal: AbortSignal.timeout(5000) });
  if (!response.ok) throw new Error(`Weather API returned HTTP ${response.status}`);

  const payload = await response.json();
  const temperature = payload?.current?.temperature_2m;
  const apparentTemperature = payload?.current?.apparent_temperature;
  const humidity = payload?.current?.relative_humidity_2m;
  const windSpeed = payload?.current?.wind_speed_10m;
  const code = payload?.current?.weather_code;
  const daily = payload?.daily;
  if (
    !Number.isFinite(temperature) ||
    !Number.isFinite(apparentTemperature) ||
    !Number.isFinite(humidity) ||
    !Number.isFinite(windSpeed) ||
    !Number.isInteger(code) ||
    !Array.isArray(daily?.time) ||
    !Array.isArray(daily?.weather_code) ||
    !Array.isArray(daily?.temperature_2m_max) ||
    !Array.isArray(daily?.temperature_2m_min) ||
    daily.time.length < 5 ||
    daily.weather_code.length < 5 ||
    daily.temperature_2m_max.length < 5 ||
    daily.temperature_2m_min.length < 5 ||
    !daily.weather_code.slice(0, 5).every(Number.isInteger) ||
    !daily.temperature_2m_max.slice(0, 5).every(Number.isFinite) ||
    !daily.temperature_2m_min.slice(0, 5).every(Number.isFinite)
  ) {
    throw new Error("Weather API returned incomplete current conditions");
  }

  const formatTemperature = (value) => `${Math.round(value)}°C`;
  const dayFormatter = new Intl.DateTimeFormat("en-US", {
    weekday: "short",
    timeZone: "UTC",
  });
  const forecast = daily.time.slice(1, 5).map((date, index) => ({
    day: dayFormatter.format(new Date(`${date}T12:00:00Z`)).toUpperCase(),
    condition: weatherCondition(daily.weather_code[index + 1]),
    high: formatTemperature(daily.temperature_2m_max[index + 1]),
    low: formatTemperature(daily.temperature_2m_min[index + 1]),
  }));

  return {
    location,
    temperature: formatTemperature(temperature),
    condition: weatherCondition(code),
    apparentTemperature: formatTemperature(apparentTemperature),
    high: formatTemperature(daily.temperature_2m_max[0]),
    low: formatTemperature(daily.temperature_2m_min[0]),
    humidity: `${Math.round(humidity)}%`,
    windSpeed: `${Math.round(windSpeed)} km/h`,
    forecast,
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
