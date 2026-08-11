const PREVIEW_APPLE_DATA = {
  syncedAt: new Date().toISOString(),
  reminders: [
    { id: "1", title: "Finish assignment", dueDate: null, dueTime: null, priority: 1, completed: false, list: "Reminders" },
    { id: "2", title: "Buy groceries", dueDate: null, dueTime: null, priority: 0, completed: false, list: "Reminders" },
    { id: "3", title: "Apply for jobs", dueDate: null, dueTime: null, priority: 0, completed: false, list: "Reminders" },
  ],
  events: [],
};

const weather = {
  location: "Bangkok",
  temperature: "31°C",
  condition: "Partly Cloudy",
};

function dateKey(date, timeZone) {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(date);
  const values = Object.fromEntries(parts.map((part) => [part.type, part.value]));
  return `${values.year}-${values.month}-${values.day}`;
}

function truncate(value, length) {
  if (!value) return "";
  return value.length <= length ? value : `${value.slice(0, length - 1)}…`;
}

function timeLabel(date, timeZone) {
  return new Intl.DateTimeFormat("en-GB", {
    timeZone,
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  }).format(date);
}

function upcomingDayLabel(date, now, timeZone) {
  const tomorrow = new Date(now.getTime() + 24 * 60 * 60 * 1000);
  if (dateKey(date, timeZone) === dateKey(tomorrow, timeZone)) return "TOMORROW";

  return new Intl.DateTimeFormat("en-GB", {
    timeZone,
    weekday: "short",
    day: "numeric",
    month: "short",
  })
    .format(date)
    .toUpperCase();
}

function reminderCategory(reminder, now, timeZone) {
  if (!reminder.dueDate) return "NO DATE";
  const due = new Date(reminder.dueDate);
  const today = dateKey(now, timeZone);
  const dueDay = dateKey(due, timeZone);
  if (dueDay < today) return "OVERDUE";
  if (dueDay === today) return "TODAY";
  return "UPCOMING";
}

function reminderSuffix(reminder, timeZone) {
  if (!reminder.dueDate) return "";
  if (reminder.dueTime) return reminder.dueTime;
  return new Intl.DateTimeFormat("en-GB", {
    timeZone,
    weekday: "short",
  })
    .format(new Date(reminder.dueDate))
    .toUpperCase();
}

function formatReminders(reminders, now, timeZone) {
  const rows = [];
  let previousCategory;

  for (const reminder of reminders) {
    const category = reminderCategory(reminder, now, timeZone);
    if (category !== previousCategory) {
      rows.push({ kind: "label", label: category });
      previousCategory = category;
    }

    rows.push({
      kind: "reminder",
      marker: reminder.priority > 0 && reminder.priority <= 4 ? "[!]" : "[ ]",
      title: truncate(reminder.title, 17),
      suffix: reminderSuffix(reminder, timeZone),
    });

    if (rows.length >= 9) break;
  }

  return rows.length ? rows.slice(0, 9) : [{ kind: "empty", title: "No reminders" }];
}

function formatTodayEvents(events, now, timeZone) {
  const today = dateKey(now, timeZone);
  return events
    .filter((event) => dateKey(new Date(event.startDate), timeZone) === today)
    .sort((left, right) => {
      if (left.allDay !== right.allDay) return left.allDay ? -1 : 1;
      return new Date(left.startDate) - new Date(right.startDate);
    })
    .slice(0, 8)
    .map((event) => ({
      time: event.allDay ? "All day" : timeLabel(new Date(event.startDate), timeZone),
      title: truncate(event.title, 18),
    }));
}

function formatUpcomingEvents(events, now, timeZone) {
  const today = dateKey(now, timeZone);
  const rows = [];
  let previousDay;

  for (const event of events) {
    const start = new Date(event.startDate);
    const day = dateKey(start, timeZone);
    if (day <= today) continue;

    const label = upcomingDayLabel(start, now, timeZone);
    if (label !== previousDay) {
      rows.push({ kind: "label", label });
      previousDay = label;
    }
    rows.push({
      kind: "event",
      time: event.allDay ? "All day" : timeLabel(start, timeZone),
      title: truncate(event.title, 18),
    });
    if (rows.length >= 9) break;
  }

  return rows.length ? rows.slice(0, 9) : [{ kind: "empty", title: "No upcoming events" }];
}

function buildDashboardData(appleData, { now = new Date(), timeZone = "Asia/Bangkok" } = {}) {
  const events = [...appleData.events].sort(
    (left, right) => new Date(left.startDate) - new Date(right.startDate),
  );

  return {
    date: new Intl.DateTimeFormat("en-GB", {
      timeZone,
      weekday: "short",
      day: "numeric",
      month: "short",
    }).format(now),
    time: timeLabel(now, timeZone),
    weather,
    todayEvents: formatTodayEvents(events, now, timeZone),
    reminders: formatReminders(appleData.reminders, now, timeZone),
    upcomingEvents: formatUpcomingEvents(events, now, timeZone),
    lastSynced: appleData.syncedAt
      ? timeLabel(new Date(appleData.syncedAt), timeZone)
      : "Never",
    refreshedAt: timeLabel(now, timeZone),
  };
}

function buildPreviewAppleData(now = new Date()) {
  const todayStart = new Date(now);
  todayStart.setHours(18, 30, 0, 0);
  const todayEnd = new Date(todayStart.getTime() + 60 * 60 * 1000);
  const callStart = new Date(now);
  callStart.setHours(20, 0, 0, 0);
  const callEnd = new Date(callStart.getTime() + 30 * 60 * 1000);
  const tomorrow = new Date(now.getTime() + 24 * 60 * 60 * 1000);
  tomorrow.setHours(9, 0, 0, 0);

  return {
    ...PREVIEW_APPLE_DATA,
    events: [
      { id: "1", title: "Study JavaScript", startDate: todayStart.toISOString(), endDate: todayEnd.toISOString(), calendar: "Calendar", allDay: false },
      { id: "2", title: "Call family", startDate: callStart.toISOString(), endDate: callEnd.toISOString(), calendar: "Calendar", allDay: false },
      { id: "3", title: "University", startDate: tomorrow.toISOString(), endDate: new Date(tomorrow.getTime() + 60 * 60 * 1000).toISOString(), calendar: "Calendar", allDay: false },
    ],
  };
}

module.exports = {
  buildDashboardData,
  buildPreviewAppleData,
};
