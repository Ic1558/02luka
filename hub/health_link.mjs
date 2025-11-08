#!/usr/bin/env node
/**
 * Phase 20.3 - Unified Health Dashboard Linker
 *
 * Combines multiple health/status sources into a single health_link.json:
 * - hub/mcp_health.json (Phase 20.2)
 * - hub/mcp_registry.json (Phase 20.1)
 * - hub/index.json (Phase 20.0)
 *
 * Usage: node hub/health_link.mjs
 */

import { readFile, writeFile, mkdir } from 'fs/promises';
import { existsSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const ROOT = join(__dirname, '..');

// Paths
const PATHS = {
  registry: join(ROOT, 'hub/mcp_registry.json'),
  health: join(ROOT, 'hub/mcp_health.json'),
  index: join(ROOT, 'hub/index.json'),
  output: join(ROOT, 'hub/health_link.json'),
};

/**
 * Safely read JSON file, return null if not exists or invalid
 */
async function readJsonSafe(path) {
  try {
    if (!existsSync(path)) {
      console.warn(`⚠️  File not found (skipping): ${path}`);
      return null;
    }
    const content = await readFile(path, 'utf-8');
    return JSON.parse(content);
  } catch (err) {
    console.error(`❌ Error reading ${path}:`, err.message);
    return null;
  }
}

/**
 * Merge registry + health by matching server names
 */
function mergeMcpData(registry, health) {
  const result = {
    registry: [],
    health: [],
  };

  // Add registry data
  if (registry?.servers) {
    result.registry = Array.isArray(registry.servers)
      ? registry.servers
      : Object.entries(registry.servers).map(([name, config]) => ({
          name,
          ...config,
        }));
  }

  // Add health data
  if (health?.checks) {
    result.health = health.checks;
  }

  return result;
}

/**
 * Extract light artifact list (limit to 50 most recent)
 */
function extractArtifacts(index) {
  if (!index?.artifacts || !Array.isArray(index.artifacts)) {
    return [];
  }

  return index.artifacts
    .slice(0, 50)
    .map(artifact => ({
      rel: artifact.rel || artifact.path,
      size: artifact.size,
      updated_at: artifact.updated_at || artifact.mtime,
    }));
}

/**
 * Calculate summary statistics
 */
function calculateSummary(mcp, artifacts) {
  const summary = {
    mcp_servers_total: 0,
    mcp_healthy: 0,
    artifacts_total: artifacts.length,
  };

  // Count MCP servers
  if (mcp.registry) {
    summary.mcp_servers_total = mcp.registry.length;
  }

  // Count healthy servers
  if (mcp.health) {
    summary.mcp_healthy = mcp.health.filter(h => h.ok === true).length;
  }

  return summary;
}

/**
 * Main linker function
 */
async function linkHealth() {
  console.log('🔗 Phase 20.3 - Unified Health Linker');
  console.log('=====================================\n');

  // Read input files
  console.log('📖 Reading input files...');
  const [registry, health, index] = await Promise.all([
    readJsonSafe(PATHS.registry),
    readJsonSafe(PATHS.health),
    readJsonSafe(PATHS.index),
  ]);

  // Track what we found
  const inputs = {
    registry: registry !== null,
    health: health !== null,
    index: index !== null,
  };

  console.log('✓ Input status:', inputs);

  // Merge data
  const mcp = mergeMcpData(registry, health);
  const artifacts = extractArtifacts(index);
  const summary = calculateSummary(mcp, artifacts);

  // Build output
  const output = {
    _meta: {
      created_by: 'GG_Agent_02luka',
      created_at: new Date().toISOString(),
      source: 'health_link.mjs',
      inputs,
    },
    summary,
    mcp,
    artifacts,
  };

  // Ensure hub directory exists
  await mkdir(dirname(PATHS.output), { recursive: true });

  // Write output
  await writeFile(PATHS.output, JSON.stringify(output, null, 2), 'utf-8');

  console.log('\n✅ Health link created successfully!');
  console.log(`📄 Output: ${PATHS.output}`);
  console.log('\n📊 Summary:');
  console.log(`   MCP Servers: ${summary.mcp_servers_total} total, ${summary.mcp_healthy} healthy`);
  console.log(`   Artifacts:   ${summary.artifacts_total} items`);

  return output;
}

// Run if executed directly
if (import.meta.url === `file://${process.argv[1]}`) {
  linkHealth().catch(err => {
    console.error('❌ Fatal error:', err);
    process.exit(1);
  });
}

export { linkHealth };
