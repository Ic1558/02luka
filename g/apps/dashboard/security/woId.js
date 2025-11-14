/**
 * Work Order ID Security Validation
 * Prevents path traversal attacks by enforcing strict ID format
 */

const path = require('path');

// Allowlist: Only alphanumeric, underscore, and hyphen allowed
// This completely prevents ../ and / characters
const WO_ID_REGEX = /^[A-Za-z0-9_-]+$/;

/**
 * Assert that a work order ID is valid
 * @param {string} id - The work order ID to validate
 * @throws {Error} If ID is invalid
 */
function assertValidWoId(id) {
  if (typeof id !== 'string' || !WO_ID_REGEX.test(id)) {
    const err = new Error('Invalid work-order id');
    err.statusCode = 400;
    throw err;
  }
}

/**
 * Get the safe file path for a work order state file
 * Validates ID and ensures path stays within STATE_DIR
 * @param {string} STATE_DIR - Base directory for state files
 * @param {string} id - Work order ID
 * @returns {string} Resolved absolute path to state file
 * @throws {Error} If ID is invalid or path escapes STATE_DIR
 */
function woStatePath(STATE_DIR, id) {
  // First: Validate ID format (rejects . and / characters)
  assertValidWoId(id);
  
  // Second: Resolve paths and verify containment
  const base = path.resolve(STATE_DIR);
  const full = path.resolve(path.join(base, id + '.json'));
  
  // Ensure resolved path is within base directory
  if (!full.startsWith(base + path.sep)) {
    const err = new Error('Invalid work-order path');
    err.statusCode = 400;
    throw err;
  }
  
  return full;
}

module.exports = { 
  assertValidWoId,
  woStatePath,
  WO_ID_REGEX 
};
