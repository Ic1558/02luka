// @created_by: GG_Agent_02luka
// @phase: 20
// @file: health_check.mjs
// Health check endpoint for Hub Dashboard index staleness monitoring

import fsp from 'fs/promises';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const INDEX_PATH = process.env.HUB_INDEX_PATH || path.join(__dirname, 'index.json');

export async function healthCheck() {
  try {
    const stat = await fsp.stat(INDEX_PATH);
    const data = JSON.parse(await fsp.readFile(INDEX_PATH, 'utf8'));

    const ageMs = Date.now() - new Date(data._meta.created_at).getTime();
    const ageMin = Math.floor(ageMs / 60000);

    // Determine status based on age
    let status = 'healthy';
    if (ageMin >= 30) status = 'error';
    else if (ageMin >= 20) status = 'stale';

    return {
      status,
      index: {
        path: INDEX_PATH,
        total_items: data._meta.total,
        last_updated: data._meta.created_at,
        age_minutes: ageMin,
        size_kb: Math.round(stat.size / 1024),
        mem_root: data._meta.mem_root
      },
      thresholds: {
        stale_after_minutes: 20,
        error_after_minutes: 30,
        expected_refresh_minutes: 15
      },
      timestamp: new Date().toISOString()
    };
  } catch (err) {
    return {
      status: 'error',
      error: err.message,
      index: {
        path: INDEX_PATH,
        exists: false
      },
      timestamp: new Date().toISOString()
    };
  }
}

// CLI usage: node hub/health_check.mjs
if (import.meta.url === `file://${process.argv[1]}`) {
  healthCheck().then(result => {
    console.log(JSON.stringify(result, null, 2));
    // Exit with error code if not healthy
    process.exit(result.status === 'healthy' ? 0 : 1);
  });
}
