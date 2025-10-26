import fs from 'fs';
import path from 'path';
const root = 'memory-bank/tasks';
const issues = fs.readdirSync(root).filter(d => d.startsWith('issue-'));
const rows = issues.map(id => {
  const dir = path.join(root, id);
  const hasReq = fs.existsSync(path.join(dir, 'requirement.md'));
  const hasPlan = fs.existsSync(path.join(dir, 'pre-dev-analysis.md'));
  const hasCode = fs.existsSync(path.join(dir, 'code/main.ts'));
  const hasTests = fs.existsSync(path.join(dir, 'tests/main.test.ts'));
  const auditor = fs.existsSync(path.join(dir, 'validation_report.md')) ? 'present' : 'pending';
  return { id, hasReq, hasPlan, hasCode, hasTests, auditor };
});
const yaml = [
  '# Kubricate v1 Issue Index',
  'issues:'
].concat(rows.map(r => `  - id: ${r.id}\n    req: ${r.hasReq}\n    plan: ${r.hasPlan}\n    code: ${r.hasCode}\n    tests: ${r.hasTests}\n    auditor: ${r.auditor}`)).join('\n');
fs.writeFileSync(`${root}/_index.yaml`, yaml + '\n');
console.log('Updated index:', `${root}/_index.yaml`);
