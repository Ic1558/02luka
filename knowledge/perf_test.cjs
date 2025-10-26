#!/usr/bin/env node
/**
 * Performance test - multiple queries in same process
 */

const { getEmbedding } = require('./embedder.cjs');

async function main() {
  console.log('Testing embedding performance across multiple queries...\n');

  const queries = [
    'first query test',
    'second query test',
    'third query test',
    'fourth query test',
    'fifth query test'
  ];

  for (let i = 0; i < queries.length; i++) {
    const start = Date.now();
    const result = await getEmbedding(queries[i], { withMetadata: true });
    const duration = Date.now() - start;

    console.log(`Query ${i + 1}: ${duration}ms (cached: ${result.cached})`);
  }
}

main().catch(console.error);
