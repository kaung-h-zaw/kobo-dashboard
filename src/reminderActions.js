const fs = require("fs/promises");
const path = require("path");

const ACTIONS_FILE = path.join(__dirname, "..", "data", "reminder-actions.json");
const MAX_ACTIONS = 500;

async function readActions() {
  try {
    const data = JSON.parse(await fs.readFile(ACTIONS_FILE, "utf8"));
    return Array.isArray(data) ? data : [];
  } catch (error) {
    if (error.code !== "ENOENT") console.error("Could not read reminder actions.");
    return [];
  }
}

async function writeActions(actions) {
  await fs.mkdir(path.dirname(ACTIONS_FILE), { recursive: true });
  const temporary = `${ACTIONS_FILE}.tmp`;
  await fs.writeFile(temporary, `${JSON.stringify(actions, null, 2)}\n`, { mode: 0o600 });
  await fs.rename(temporary, ACTIONS_FILE);
}

function validateAction(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw new Error("Request body must be an object");
  if (typeof value.id !== "string" || !value.id.trim() || value.id.length > 500) throw new Error("id is invalid");
  if (typeof value.completed !== "boolean") throw new Error("completed must be a boolean");
  return { id: value.id, completed: value.completed, requestedAt: new Date().toISOString() };
}

async function queueAction(value) {
  const action = validateAction(value);
  const actions = (await readActions()).filter((item) => item.id !== action.id);
  actions.push(action);
  await writeActions(actions.slice(-MAX_ACTIONS));
  return action;
}

async function acknowledgeActions(ids) {
  if (!Array.isArray(ids) || ids.some((id) => typeof id !== "string")) throw new Error("ids must be an array of strings");
  const acknowledged = new Set(ids);
  const actions = await readActions();
  await writeActions(actions.filter((action) => !acknowledged.has(action.id)));
  return actions.length - actions.filter((action) => !acknowledged.has(action.id)).length;
}

module.exports = { acknowledgeActions, queueAction, readActions, validateAction };
