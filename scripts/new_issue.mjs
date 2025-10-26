import fs from 'fs';
const [,, id = 'issue-xxx', title = 'Untitled'] = process.argv;
const dir = `memory-bank/tasks/${id}`;
fs.mkdirSync(`${dir}/code`, { recursive: true });
fs.mkdirSync(`${dir}/tests`, { recursive: true });

function fill(t) {
  return t.replace('{{ISSUE_ID}}', id).replace('{{TITLE}}', title).replace('{{OWNER}}', '@me');
}

const T = p => fs.readFileSync(p, 'utf8');
fs.writeFileSync(`${dir}/draft-spec.md`, T('templates/draft-spec.md'));
fs.writeFileSync(`${dir}/requirement.md`, fill(T('templates/requirement.md')));
fs.writeFileSync(`${dir}/pre-dev-analysis.md`, T('templates/pre-dev-analysis.md'));
fs.writeFileSync(`${dir}/tech-auditor-checklist.md`, T('templates/tech-auditor-checklist.md'));

// starter code & test
fs.writeFileSync(`${dir}/code/main.ts`,
`export function add(a:number,b:number){return a+b}
`);
fs.writeFileSync(`${dir}/tests/main.test.ts`,
`import { describe, it, expect } from 'vitest';
import { add } from '../code/main';
describe('add', () => { it('adds', () => { expect(add(2,3)).toBe(5); }); });
`);
console.log('Created', dir);
