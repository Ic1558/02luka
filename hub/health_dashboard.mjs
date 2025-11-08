#!/usr/bin/env node
/**
 * Health Dashboard Linker - Phase 20.3
 *
 * Combines hub/mcp_health.json + hub/index.json into unified dashboard
 * Output: hub/health_dashboard.json
 *
 * Purpose:
 * - Single source of truth for Hub Dashboard
 * - Unified MCP health + file status in one JSON
 * - Schema-validated output
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

// Get __dirname equivalent in ES modules
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Configuration
const CONFIG = {
  repoRoot: path.join(__dirname, '..'),
  mcpHealthFile: path.join(__dirname, 'mcp_health.json'),
  indexFile: path.join(__dirname, 'index.json'),
  outputFile: path.join(__dirname, 'health_dashboard.json'),
  schemaFile: path.join(__dirname, '../config/schemas/health_dashboard.schema.json'),
};

// Utility: Read JSON file with fallback
function readJSONFile(filePath, fallback = null) {
  try {
    if (!fs.existsSync(filePath)) {
      console.warn(`⚠️  File not found: ${filePath}, using fallback`);
      return fallback;
    }
    const content = fs.readFileSync(filePath, 'utf8');
    return JSON.parse(content);
  } catch (error) {
    console.error(`❌ Error reading ${filePath}:`, error.message);
    return fallback;
  }
}

// Utility: Write JSON file
function writeJSONFile(filePath, data) {
  try {
    const content = JSON.stringify(data, null, 2);
    fs.writeFileSync(filePath, content, 'utf8');
    console.log(`✅ Written: ${filePath}`);
    return true;
  } catch (error) {
    console.error(`❌ Error writing ${filePath}:`, error.message);
    return false;
  }
}

// Validate against JSON schema (basic validation)
function validateSchema(data, schemaPath) {
  try {
    if (!fs.existsSync(schemaPath)) {
      console.warn(`⚠️  Schema not found: ${schemaPath}, skipping validation`);
      return true;
    }

    const schema = readJSONFile(schemaPath);
    if (!schema) {
      console.warn(`⚠️  Could not load schema, skipping validation`);
      return true;
    }

    // Basic validation - check required fields
    if (schema.required) {
      for (const field of schema.required) {
        if (!(field in data)) {
          console.error(`❌ Validation failed: Missing required field '${field}'`);
          return false;
        }
      }
    }

    // Check properties exist
    if (schema.properties) {
      for (const [key, value] of Object.entries(data)) {
        if (!(key in schema.properties)) {
          console.warn(`⚠️  Unknown field '${key}' not in schema`);
        }
      }
    }

    console.log(`✅ Schema validation passed`);
    return true;
  } catch (error) {
    console.error(`❌ Schema validation error:`, error.message);
    return false;
  }
}

// Main: Merge health data
function mergeHealthDashboard() {
  console.log('🚀 Starting Health Dashboard Linker...\n');

  // Read input files
  const mcpHealth = readJSONFile(CONFIG.mcpHealthFile, []);
  const indexData = readJSONFile(CONFIG.indexFile, []);

  console.log(`📊 MCP Health entries: ${Array.isArray(mcpHealth) ? mcpHealth.length : 'N/A'}`);
  console.log(`📊 Index file entries: ${Array.isArray(indexData) ? indexData.length : 'N/A'}\n`);

  // Create unified dashboard
  const dashboard = {
    _meta: {
      created_by: 'GG_Agent_02luka',
      created_at: new Date().toISOString(),
      source: 'health_dashboard.mjs',
      unified: true,
      version: '1.0.0',
    },
    mcp: Array.isArray(mcpHealth) ? mcpHealth : [],
    files: Array.isArray(indexData) ? indexData : [],
  };

  // Validate against schema
  if (!validateSchema(dashboard, CONFIG.schemaFile)) {
    console.error('❌ Schema validation failed, aborting');
    process.exit(1);
  }

  // Write output
  if (!writeJSONFile(CONFIG.outputFile, dashboard)) {
    console.error('❌ Failed to write output file');
    process.exit(1);
  }

  // Summary
  console.log('\n📈 Dashboard Summary:');
  console.log(`   - MCP entries: ${dashboard.mcp.length}`);
  console.log(`   - File entries: ${dashboard.files.length}`);
  console.log(`   - Created: ${dashboard._meta.created_at}`);
  console.log(`   - Output: ${CONFIG.outputFile}\n`);
  console.log('✅ Health Dashboard Linker completed successfully');
}

// Run
try {
  mergeHealthDashboard();
} catch (error) {
  console.error('❌ Fatal error:', error);
  process.exit(1);
}
