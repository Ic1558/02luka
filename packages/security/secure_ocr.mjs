export function assess(rawText="") {
  const txt = String(rawText || "").trim();
  const matches = [];

  const patterns = [
    {tag:"cmd.pipe",     re:/\|\s*(bash|sh|zsh)\b/i, weight:0.9},
    {tag:"cmd.exec",     re:/\b(curl|wget)\b.*\|\s*(bash|sh|zsh)\b/i, weight:0.9},
    {tag:"shell.danger", re:/;\s*(rm\s+-rf|sudo\s+.*|chmod\s+777)\b/i, weight:0.85},
    {tag:"url.exfil",    re:/https?:\/\/[^\s]+/i, weight:0.6},
    {tag:"email",        re:/[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i, weight:0.45},
    {tag:"otp.6d",       re:/\b(\d{6})\b(?!\s*(usd|thb|baht))/i, weight:0.7},
    {tag:"otp.words",    re:/\b(verification|one[-\s]?time|otp|2fa|code|passcode)\b/i, weight:0.65},
    {tag:"secrets",      re:/\b(api[_-]?key|token|secret|password|passphrase)\b/i, weight:0.7},
    {tag:"prompt.ctrl",  re:/\b(ignore\s+previous|do\s+not\s+ask|auto[-\s]?confirm)\b/i, weight:0.55},
  ];

  let score = 0;
  for (const p of patterns) {
    const m = txt.match(p.re);
    if (m) { matches.push(p.tag); score = Math.max(score, p.weight); }
  }

  // escalate if multiple distinct classes hit
  const distinct = new Set(matches.map(s => s.split('.')[0]));
  if (distinct.size >= 3) score = Math.max(score, 0.8);

  return { risk: Number(score.toFixed(2)), matches, raw: txt };
}
