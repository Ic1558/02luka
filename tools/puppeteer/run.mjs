import yargs from 'yargs';
import { hideBin } from 'yargs/helpers';
import { launch } from './lib/browser.mjs';
import { addLabel, ensureTitlePrefix, rerunAllChecks, closePR, createFromCompare, mergePR } from './tasks/github_pr.mjs';

const argv = yargs(hideBin(process.argv))
  .command('pr-label', 'เพิ่ม label ให้ PR', y=>y.option('url',{demandOption:true}).option('label',{default:'run-smoke'}))
  .command('pr-title-optin', 'เติม prefix ในหัวข้อ PR', y=>y.option('url',{demandOption:true}).option('prefix',{default:'[run-smoke]'}))
  .command('pr-rerun', 'Re-run checks', y=>y.option('url',{demandOption:true}))
  .command('pr-close', 'Close PR (พร้อมคอมเมนต์ถ้าต้องการ)', y=>y.option('url',{demandOption:true}).option('comment'))
  .command('pr-merge', 'Merge PR (squash/merge/rebase)', y=>y
    .option('url',  { demandOption:true })
    .option('mode', { default:'squash', choices:['squash','merge','rebase'] })
    .option('delete-branch', { type:'boolean', default:true })
  )
  .command('compare-open', 'เปิด PR จากหน้า compare', y=>y.option('compareUrl',{demandOption:true}).option('title').option('body'))
  .option('profile', { describe:'Chrome user data dir', type:'string'})
  .option('headless', { default:false, type:'boolean'})
  .demandCommand(1)
  .help()
  .argv;

const { browser, page } = await launch({ userDataDir: argv.profile, headless: argv.headless });

try {
  const cmd = argv._[0];
  if (cmd === 'pr-label') await addLabel({ page, prUrl: argv.url, label: argv.label });
  if (cmd === 'pr-title-optin') await ensureTitlePrefix({ page, prUrl: argv.url, prefix: argv.prefix });
  if (cmd === 'pr-rerun') await rerunAllChecks({ page, prUrl: argv.url });
  if (cmd === 'pr-close') await closePR({ page, prUrl: argv.url, comment: argv.comment });
  if (cmd === 'pr-merge') await mergePR({ page, prUrl: argv.url, mode: argv.mode, deleteBranch: argv.deleteBranch });
  if (cmd === 'compare-open') await createFromCompare({ page, compareUrl: argv.compareUrl, title: argv.title, body: argv.body });
} finally {
  await new Promise(resolve => setTimeout(resolve, 600));
  await browser.close();
}
