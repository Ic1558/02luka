import { execSync } from 'child_process';
import fs from 'fs';
import path from 'path';

const [,, id = 'issue-xxx'] = process.argv;
const dir = `memory-bank/tasks/${id}`;
try {
  execSync('npm run test -s', { stdio: 'inherit' });
  const report = `# validation_report\nstatus: PASS\nnotes: unit tests passed\n`;
  fs.writeFileSync(path.join(dir, 'validation_report.md'), report);
  console.log('PASS');
  process.exit(0);
} catch (e) {
  const report = `# validation_report\nstatus: FAIL\nnotes: unit tests failed\n`;
  fs.writeFileSync(path.join(dir, 'validation_report.md'), report);
  process.exit(1);
}
