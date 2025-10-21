import express from 'express';
import cors from 'cors';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const UI_DIR = path.resolve(__dirname, '../assistant-ui');

function normalizeLogger(logger) {
  if (!logger) return console;
  return {
    info: (...args) => (logger.info ? logger.info(...args) : console.log(...args)),
    warn: (...args) => (logger.warn ? logger.warn(...args) : console.warn(...args)),
    error: (...args) => (logger.error ? logger.error(...args) : console.error(...args))
  };
}

export function startApiServer({ port = 4000, logger, statusRef } = {}) {
  const log = normalizeLogger(logger);
  const app = express();
  app.disable('x-powered-by');
  app.use(cors());
  app.use(express.json({ limit: '1mb' }));

  app.get('/healthz', (_req, res) => {
    const status = typeof statusRef === 'function'
      ? statusRef()
      : statusRef && typeof statusRef.getStatus === 'function'
        ? statusRef.getStatus()
        : statusRef || {};

    res.json({
      ok: true,
      timestamp: new Date().toISOString(),
      ...status
    });
  });

  app.get('/status', (_req, res) => {
    const status = typeof statusRef === 'function'
      ? statusRef()
      : statusRef && typeof statusRef.getStatus === 'function'
        ? statusRef.getStatus()
        : statusRef || {};

    res.json(status);
  });

  const server = app.listen(port, '0.0.0.0', () => {
    log.info(`🩺 Assistant API ready at http://localhost:${port}/healthz`);
  });

  const close = () => new Promise((resolve, reject) => {
    server.close((err) => {
      if (err) {
        log.error('Failed to stop API server', err);
        reject(err);
      } else {
        log.info('✅ API server stopped');
        resolve();
      }
    });
  });

  return { server, close, url: `http://localhost:${port}/healthz` };
}

export function startUiServer({ port = 8080, logger } = {}) {
  const log = normalizeLogger(logger);
  const app = express();
  app.disable('x-powered-by');
  app.use(cors());
  app.use(express.static(UI_DIR, { extensions: ['html'] }));

  app.get('/', (_req, res) => {
    res.redirect('/luka.html');
  });

  const server = app.listen(port, '0.0.0.0', () => {
    log.info(`🖥️  Assistant UI available at http://localhost:${port}/luka.html`);
  });

  const close = () => new Promise((resolve, reject) => {
    server.close((err) => {
      if (err) {
        log.error('Failed to stop UI server', err);
        reject(err);
      } else {
        log.info('✅ UI server stopped');
        resolve();
      }
    });
  });

  return { server, close, url: `http://localhost:${port}/luka.html`, rootDir: UI_DIR };
}
