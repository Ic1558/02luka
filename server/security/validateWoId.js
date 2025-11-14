const path = require("path");

const WO_ID_REGEX = /^[A-Za-z0-9_-]+$/;

function validateWorkOrderId(id) {
  if (typeof id !== "string" || !WO_ID_REGEX.test(id)) {
    const err = new Error("Invalid work-order id");
    err.statusCode = 400;
    throw err;
  }
  return id;
}

function resolveWoStatePath(baseDir, id) {
  validateWorkOrderId(id);
  const base = path.resolve(baseDir);
  const target = path.resolve(path.join(base, `${id}.json`));
  if (!target.startsWith(base + path.sep)) {
    const err = new Error("Invalid work-order path");
    err.statusCode = 400;
    throw err;
  }
  return target;
}

module.exports = { validateWorkOrderId, resolveWoStatePath };
