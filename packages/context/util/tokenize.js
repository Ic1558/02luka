/**
 * Tokenize text into normalized tokens.
 * @param {string} text
 * @returns {string[]}
 */
function tokenize(text) {
  if (!text) {
    return [];
  }

  return text
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, ' ')
    .split(/\s+/)
    .filter(Boolean);
}

module.exports = {
  tokenize
};
