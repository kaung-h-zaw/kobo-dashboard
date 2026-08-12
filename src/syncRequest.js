const fs = require("fs/promises");
const path = require("path");
const crypto = require("crypto");

const REQUEST_FILE = path.join(__dirname, "..", "data", "sync-request.json");

async function readSyncRequest() {
  try {
    return JSON.parse(await fs.readFile(REQUEST_FILE, "utf8"));
  } catch (error) {
    if (error.code !== "ENOENT") console.error("Could not read sync request state.");
    return null;
  }
}

async function writeSyncRequest(value) {
  await fs.mkdir(path.dirname(REQUEST_FILE), { recursive: true });
  const temporary = `${REQUEST_FILE}.tmp`;
  await fs.writeFile(temporary, `${JSON.stringify(value, null, 2)}\n`, { mode: 0o600 });
  await fs.rename(temporary, REQUEST_FILE);
}

async function createSyncRequest() {
  const value = { id: crypto.randomUUID(), requestedAt: new Date().toISOString(), completedAt: null };
  await writeSyncRequest(value);
  return value;
}

async function completeSyncRequest() {
  const value = await readSyncRequest();
  if (!value || value.completedAt) return value;
  value.completedAt = new Date().toISOString();
  await writeSyncRequest(value);
  return value;
}

module.exports = { completeSyncRequest, createSyncRequest, readSyncRequest };
