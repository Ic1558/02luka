/**
 * Build a token budget summary for downstream model orchestration.
 * @param {{target: number, used: number}} params
 * @returns {{target: number, used: number, remaining: number, status: 'ok'|'tight'|'exceeded'}}
 */
function buildTokenBudget({ target, used }) {
  const remaining = Math.max(0, target - used);
  let status = 'ok';
  if (remaining < target * 0.2) {
    status = remaining === 0 ? 'exceeded' : 'tight';
  }
  return {
    target,
    used,
    remaining,
    status
  };
}

module.exports = {
  buildTokenBudget
};
