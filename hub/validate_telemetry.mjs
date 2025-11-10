#!/usr/bin/env node
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

async function main() {
  try {
    const { default: Ajv } = await import('ajv');
    const { default: addFormats } = await import('ajv-formats');

    const schemaPath = resolve('g/schemas/telemetry_v2.schema.json');
    const dataPath = resolve('hub/system_telemetry_v2.json');

    const schema = JSON.parse(readFileSync(schemaPath, 'utf8'));
    const data = JSON.parse(readFileSync(dataPath, 'utf8'));

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
    if (err?.code === 'ERR_MODULE_NOT_FOUND' || /Cannot find module 'ajv'/.test(String(err))) {
      console.error('❌ Missing dependency: ajv. Run "npm ci" to install dependencies before running validation.');
      process.exit(2);
    }

    console.error('❌ Unexpected error during validation:', err);
    process.exit(3);
  }
}

main();
