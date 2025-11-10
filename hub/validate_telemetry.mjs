#!/usr/bin/env node
import fs from 'fs';

const readJson = (path) => {
  try {
    return JSON.parse(fs.readFileSync(path, 'utf8'));
  } catch (err) {
    console.error(`❌ Failed to read ${path}:`, err.message || err);
    process.exit(1);
  }
};

try {
  const { default: Ajv } = await import('ajv');
  const { default: addFormats } = await import('ajv-formats');

  const schema = readJson('./g/schemas/telemetry_v2.schema.json');
  const data = readJson('./hub/system_telemetry_v2.json');

  const ajv = new Ajv({ strict: false, allErrors: true });
  addFormats(ajv);

  const valid = ajv.validate(schema, data);
  if (!valid) {
    console.error('❌ Schema validation failed:');
    console.error(JSON.stringify(ajv.errors, null, 2));
    process.exit(1);
  }

  console.log('✅ Schema validation passed');
  process.exit(0);
} catch (err) {
  console.error('❌ Validation step error:', err.message || err);
  if (/Cannot find module \'ajv\'|ERR_MODULE_NOT_FOUND/.test(String(err))) {
    console.error('Missing dependency: ajv. Run "npm ci" to install dependencies.');
    process.exit(2);
  }
  process.exit(3);
}
