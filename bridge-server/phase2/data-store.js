/**
 * Local runtime storage for Phase 2 POC.
 *
 * Runtime files are intentionally local JSON files and should stay ignored by
 * Git. This keeps household inventory and consumption history private during
 * the proof of concept.
 */

const fs = require('fs');
const path = require('path');

const BRIDGE_ROOT = path.join(__dirname, '..');
const FOODS_FILE = process.env.PANTREE_FOODS_FILE || path.join(BRIDGE_ROOT, 'pantree-data.json');
const EVENTS_FILE = process.env.PANTREE_EVENTS_FILE || path.join(BRIDGE_ROOT, 'pantree-events.json');

function ensureJsonFile(filePath, fallback) {
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  if (!fs.existsSync(filePath)) {
    fs.writeFileSync(filePath, JSON.stringify(fallback, null, 2));
  }
}

function readJson(filePath, fallback) {
  try {
    ensureJsonFile(filePath, fallback);
    return JSON.parse(fs.readFileSync(filePath, 'utf-8'));
  } catch (err) {
    console.error(`[phase2:data] Failed to read ${filePath}:`, err.message);
    return fallback;
  }
}

function writeJson(filePath, data) {
  fs.writeFileSync(filePath, JSON.stringify(data, null, 2));
}

function readFoods() {
  return readJson(FOODS_FILE, {});
}

function writeFoods(foods) {
  writeJson(FOODS_FILE, foods || {});
}

function readEvents() {
  return readJson(EVENTS_FILE, []);
}

function writeEvents(events) {
  writeJson(EVENTS_FILE, Array.isArray(events) ? events : []);
}

function appendEvent(event) {
  const events = readEvents();
  events.push(event);
  writeEvents(events);
  return event;
}

module.exports = {
  FOODS_FILE,
  EVENTS_FILE,
  readFoods,
  writeFoods,
  readEvents,
  writeEvents,
  appendEvent,
};
