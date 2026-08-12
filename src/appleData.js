const fs = require("fs/promises");
const path = require("path");

const DATA_DIRECTORY = path.join(__dirname, "..", "data");
const DATA_FILE = path.join(DATA_DIRECTORY, "apple-data.json");
const MAX_ITEMS = 500;

const EMPTY_APPLE_DATA = Object.freeze({
  syncedAt: null,
  reminders: [],
  events: [],
});

function isPlainObject(value) {
  return Boolean(value) && typeof value === "object" && !Array.isArray(value);
}

function requiredString(value, field, maxLength = 500) {
  if (typeof value !== "string" || value.trim() === "") {
    throw new Error(`${field} must be a non-empty string`);
  }

  if (value.length > maxLength) throw new Error(`${field} is too long`);
  return value;
}

function optionalString(value, field, maxLength = 5000) {
  if (value === undefined || value === null) return null;
  if (typeof value !== "string") throw new Error(`${field} must be a string or null`);
  if (value.length > maxLength) throw new Error(`${field} is too long`);
  return value;
}

function isoDate(value, field, { optional = false } = {}) {
  if (optional && (value === undefined || value === null)) return null;
  const normalized = requiredString(value, field, 100);
  if (Number.isNaN(Date.parse(normalized))) throw new Error(`${field} must be an ISO date`);
  return new Date(normalized).toISOString();
}

function validateReminder(reminder, index) {
  if (!isPlainObject(reminder)) throw new Error(`reminders[${index}] must be an object`);

  const priority = reminder.priority ?? 0;
  if (!Number.isInteger(priority) || priority < 0 || priority > 9) {
    throw new Error(`reminders[${index}].priority must be an integer from 0 to 9`);
  }

  if (typeof reminder.completed !== "boolean") {
    throw new Error(`reminders[${index}].completed must be a boolean`);
  }

  return {
    id: requiredString(reminder.id, `reminders[${index}].id`),
    title: requiredString(reminder.title, `reminders[${index}].title`),
    notes: optionalString(reminder.notes, `reminders[${index}].notes`),
    dueDate: isoDate(reminder.dueDate, `reminders[${index}].dueDate`, { optional: true }),
    dueTime: optionalString(reminder.dueTime, `reminders[${index}].dueTime`, 20),
    priority,
    completed: reminder.completed,
    list: requiredString(reminder.list, `reminders[${index}].list`),
  };
}

function validateEvent(event, index) {
  if (!isPlainObject(event)) throw new Error(`events[${index}] must be an object`);
  if (typeof event.allDay !== "boolean") {
    throw new Error(`events[${index}].allDay must be a boolean`);
  }

  const startDate = isoDate(event.startDate, `events[${index}].startDate`);
  const endDate = isoDate(event.endDate, `events[${index}].endDate`);
  if (new Date(endDate) < new Date(startDate)) {
    throw new Error(`events[${index}].endDate must not be before startDate`);
  }

  return {
    id: requiredString(event.id, `events[${index}].id`),
    title: requiredString(event.title, `events[${index}].title`),
    startDate,
    endDate,
    calendar: requiredString(event.calendar, `events[${index}].calendar`),
    allDay: event.allDay,
    location: optionalString(event.location, `events[${index}].location`, 1000),
    notes: optionalString(event.notes, `events[${index}].notes`),
  };
}

function validateAppleData(payload, { allowEmptySync = false } = {}) {
  if (!isPlainObject(payload)) throw new Error("Request body must be a JSON object");
  if (!Array.isArray(payload.reminders)) throw new Error("reminders must be an array");
  if (!Array.isArray(payload.events)) throw new Error("events must be an array");
  if (payload.reminders.length > MAX_ITEMS || payload.events.length > MAX_ITEMS) {
    throw new Error(`reminders and events are limited to ${MAX_ITEMS} items each`);
  }

  return {
    syncedAt:
      allowEmptySync && payload.syncedAt === null
        ? null
        : isoDate(payload.syncedAt, "syncedAt"),
    reminders: payload.reminders.map(validateReminder),
    events: payload.events.map(validateEvent),
  };
}

async function readAppleData() {
  try {
    const contents = await fs.readFile(DATA_FILE, "utf8");
    return validateAppleData(JSON.parse(contents), { allowEmptySync: true });
  } catch (error) {
    if (error.code !== "ENOENT") {
      console.error("Could not read Apple sync data; using empty data.");
    }
    return { ...EMPTY_APPLE_DATA, reminders: [], events: [] };
  }
}

async function writeAppleData(data) {
  await fs.mkdir(DATA_DIRECTORY, { recursive: true });
  const temporaryFile = `${DATA_FILE}.tmp`;
  await fs.writeFile(temporaryFile, `${JSON.stringify(data, null, 2)}\n`, {
    encoding: "utf8",
    mode: 0o600,
  });
  await fs.rename(temporaryFile, DATA_FILE);
}

module.exports = {
  EMPTY_APPLE_DATA,
  readAppleData,
  validateAppleData,
  writeAppleData,
};
