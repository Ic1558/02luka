#!/usr/bin/env node
import fs from 'fs';
try {
  const { default: Ajv } = await import('ajv');
  const { default: addFormats } = await import('ajv-formats');
  const schema = JSON.parse(fs.readFileSync('./config/schemas/mcp_health.schema.json','utf8'));
  const data   = JSON.parse(fs.readFileSync('./hub/mcp_health.json','utf8'));
  const ajv = new Ajv({ strict:true, allErrors:true });
  addFormats(ajv);
  const valid = ajv.validate(schema, data);
  if (!valid) {
    console.error('❌ Schema validation failed:', JSON.stringify(ajv.errors,null,2));
    process.exit(1);
  }
  console.log('✅ Schema validation passed');
  process.exit(0);
} catch (err) {
  const s = String(err||'');
  if (s.includes("Cannot find module 'ajv'") || s.includes('ERR_MODULE_NOT_FOUND')) {
    console.error('❌ Missing dependency: ajv. Run "npm ci" before validation.');
    process.exit(2);
  }
  console.error('❌ Unexpected error during validation:', err);
  process.exit(3);
}
