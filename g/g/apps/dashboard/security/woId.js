/**
 * Work Order ID Security Validation
 * Prevents path traversal attacks by enforcing strict ID format
 */

const path = require('path');

// Allowlist: Only alphanumeric, underscore, and hyphen allowed
// This completely prevents ../ and / characters
const WO_ID_REGEX = /^[A-Za-z0-9_-]+$/;

// Maximum ID length to prevent DoS and filesystem issues
// 255 is a reasonable limit that works with most filesystems
const MAX_ID_LENGTH = 255;

/**
 * Sanitize and normalize a work order ID
 * - Trims whitespace
 * - Validates format
 * - Returns normalized ID (or throws if invalid)
 * @param {string} id - The work order ID to sanitize
 * @returns {string} Sanitized and normalized ID
 * @throws {Error} If ID is invalid
 */
function sanitizeWoId(id) {
  if (typeof id !== 'string') {
    const err = new Error('Invalid work-order id: must be a string');
    err.statusCode = 400;
    throw err;
  }
  
  // Trim whitespace
  const trimmed = id.trim();
  
  if (trimmed.length === 0) {
    const err = new Error('Invalid work-order id: cannot be empty');
    err.statusCode = 400;
    throw err;
  }
  
  if (trimmed.length > MAX_ID_LENGTH) {
    const err = new Error(`Invalid work-order id: exceeds maximum length of ${MAX_ID_LENGTH} characters`);
    err.statusCode = 400;
    throw err;
  }
  
  if (!WO_ID_REGEX.test(trimmed)) {
    const err = new Error('Invalid work-order id: must contain only alphanumeric characters, underscores, and hyphens');
    err.statusCode = 400;
    throw err;
  }
  
  return trimmed;
}

/**
 * Assert that a work order ID is valid
 * @param {string} id - The work order ID to validate
 * @throws {Error} If ID is invalid
 */
function assertValidWoId(id) {
  sanitizeWoId(id); // Use sanitize for consistent validation
}

/**
 * Get the safe file path for a work order state file
 * Validates ID and ensures path stays within STATE_DIR
 * @param {string} STATE_DIR - Base directory for state files
 * @param {string} id - Work order ID (will be sanitized)
 * @returns {string} Resolved absolute path to state file
 * @throws {Error} If ID is invalid or path escapes STATE_DIR
 */
function woStatePath(STATE_DIR, id) {
  // First: Sanitize and validate ID format (rejects . and / characters)
  const sanitizedId = sanitizeWoId(id);
  
  // Second: Resolve paths and verify containment
  const base = path.resolve(STATE_DIR);
  const full = path.resolve(path.join(base, sanitizedId + '.json'));
  
  // Ensure resolved path is within base directory
  if (!full.startsWith(base + path.sep)) {
    const err = new Error('Invalid work-order path: path traversal detected');
    err.statusCode = 400;
    throw err;
  }
  
  return full;
}

module.exports = { 
  assertValidWoId,
  sanitizeWoId,
  woStatePath,
  WO_ID_REGEX,
  MAX_ID_LENGTH
};
