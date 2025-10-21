import path from 'node:path';
import fs from 'node:fs/promises';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const rootDir = path.resolve(__dirname, '..', '..');

const DATA_DIR = process.env.BOSS_DB_DIR || path.join(rootDir, 'data');
const DB_PATH = process.env.BOSS_DB_PATH || path.join(DATA_DIR, 'operations.json');

const DEFAULT_STATE = {
  runs: [],
  runSteps: [],
  runLogs: [],
  memoryHits: [],
  memoryItems: [],
  approvals: [],
  telemetryDaily: [],
  counters: {
    logs: 0
  }
};

let state = null;
let queue = Promise.resolve();

function normalizeState(value) {
  if (!value || typeof value !== 'object') {
    return structuredClone(DEFAULT_STATE);
  }

  return {
    ...structuredClone(DEFAULT_STATE),
    ...value,
    runs: Array.isArray(value.runs) ? value.runs : [],
    runSteps: Array.isArray(value.runSteps) ? value.runSteps : [],
    runLogs: Array.isArray(value.runLogs) ? value.runLogs : [],
    memoryHits: Array.isArray(value.memoryHits) ? value.memoryHits : [],
    memoryItems: Array.isArray(value.memoryItems) ? value.memoryItems : [],
    approvals: Array.isArray(value.approvals) ? value.approvals : [],
    telemetryDaily: Array.isArray(value.telemetryDaily) ? value.telemetryDaily : [],
    counters: {
      ...structuredClone(DEFAULT_STATE.counters),
      ...(value.counters || {})
    }
  };
}

async function ensureState() {
  if (state) {
    return state;
  }

  try {
    const raw = await fs.readFile(DB_PATH, 'utf8');
    state = normalizeState(JSON.parse(raw));
  } catch (error) {
    if (error.code === 'ENOENT') {
      state = structuredClone(DEFAULT_STATE);
      await persist();
    } else {
      throw error;
    }
  }

  return state;
}

async function persist() {
  if (!state) return;
  await fs.mkdir(DATA_DIR, { recursive: true });
  await fs.writeFile(DB_PATH, JSON.stringify(state, null, 2), 'utf8');
}

function enqueue(task) {
  queue = queue.then(task, (error) => {
    // Re-throw after resetting the queue to keep later tasks running
    queue = Promise.resolve();
    throw error;
  });
  return queue;
}

export function readStore(callback) {
  return enqueue(async () => {
    const current = await ensureState();
    const snapshot = structuredClone(current);
    return callback(snapshot);
  });
}

export function writeStore(callback) {
  return enqueue(async () => {
    const current = await ensureState();
    const result = await callback(current);
    await persist();
    return result;
  });
}

export async function resetStore() {
  state = structuredClone(DEFAULT_STATE);
  await persist();
}

export function getStorePath() {
  return DB_PATH;
}

