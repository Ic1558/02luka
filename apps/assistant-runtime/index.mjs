import { startApiServer, startUiServer } from '../assistant-api/server.mjs';
import { processQueue, runLoop } from '../../agents/local/orchestrator.mjs';
import readline from 'node:readline/promises';
import { stdin as input, stdout as output } from 'node:process';

function applyEnvDefaults() {
  if (!process.env.CLS_SHELL) {
    process.env.CLS_SHELL = '/bin/bash';
  }
  if (!process.env.CLS_FS_ALLOW) {
    process.env.CLS_FS_ALLOW = `/Volumes/lukadata:/Volumes/hd2:${process.env.HOME || ''}`;
  }
}

function createLoggerFactory(prefix) {
  return (scope) => {
    const label = `[${prefix}:${scope}]`;
    return {
      info: (...args) => console.log(label, ...args),
      warn: (...args) => console.warn(label, ...args),
      error: (...args) => console.error(label, ...args)
    };
  };
}

function createStatusTracker(mode) {
  const state = {
    mode,
    startTime: Date.now(),
    loopActive: false,
    lastRun: null,
    lastProcessed: 0,
    processedTotal: 0,
    lastError: null,
    recentFiles: []
  };

  return {
    setMode(newMode) {
      state.mode = newMode;
    },
    markLoop(active) {
      state.loopActive = active;
    },
    update(result) {
      const processed = result?.processed ?? 0;
      state.lastRun = new Date().toISOString();
      state.lastProcessed = processed;
      state.processedTotal += processed;
      state.lastError = null;
      state.recentFiles = (result?.items || []).map((item) => ({
        file: item.file,
        status: item.result?.status,
        logFile: item.logFile
      }));
    },
    recordError(error) {
      state.lastRun = new Date().toISOString();
      state.lastError = error instanceof Error ? error.message : String(error);
    },
    getStatus() {
      return {
        mode: state.mode,
        loopActive: state.loopActive,
        startTime: new Date(state.startTime).toISOString(),
        uptimeSeconds: Math.round((Date.now() - state.startTime) / 1000),
        lastRun: state.lastRun,
        lastProcessed: state.lastProcessed,
        processedTotal: state.processedTotal,
        lastError: state.lastError,
        recentFiles: state.recentFiles
      };
    }
  };
}

function createServerBundle(statusTracker, loggerFactory) {
  const api = startApiServer({
    logger: loggerFactory('api'),
    statusRef: () => statusTracker.getStatus()
  });
  const ui = startUiServer({ logger: loggerFactory('ui') });

  const close = async () => {
    await Promise.allSettled([api.close(), ui.close()]);
  };

  return { api, ui, close };
}

async function gracefulShutdown({
  statusTracker,
  servers,
  logger,
  reason
}) {
  if (reason) {
    logger.info(`Shutting down (${reason})`);
  }
  statusTracker.markLoop(false);
  await servers.close();
}

export async function run_manual() {
  applyEnvDefaults();
  const logFactory = createLoggerFactory('manual');
  const runtimeLog = logFactory('runtime');
  const statusTracker = createStatusTracker('manual');
  const servers = createServerBundle(statusTracker, logFactory);

  runtimeLog.info('Manual mode ready. Open the UI at', servers.ui.url);
  runtimeLog.info('API health endpoint available at', servers.api.url);

  const rl = readline.createInterface({ input, output });
  rl.setPrompt('assistant> ');

  const orchestratorLog = logFactory('orchestrator');

  let shuttingDown = false;
  const shutdown = async (reason) => {
    if (shuttingDown) return;
    shuttingDown = true;
    try {
      rl.close();
    } catch {
      // ignore
    }
    await gracefulShutdown({ statusTracker, servers, logger: runtimeLog, reason });
  };

  const signalHandler = (signal) => {
    runtimeLog.warn(`Received ${signal}. Finishing up...`);
    shutdown(signal).catch((error) => runtimeLog.error('Shutdown error', error));
  };

  process.once('SIGINT', signalHandler);
  process.once('SIGTERM', signalHandler);

  rl.on('close', () => {
    shutdown('input closed').catch((error) => runtimeLog.error('Shutdown error', error));
  });

  const showHelp = () => {
    console.log('\nCommands:');
    console.log('  help     Show this message');
    console.log('  once     Process queue/inbox/ one time');
    console.log('  status   Print latest orchestrator status');
    console.log('  exit     Stop the assistant');
    console.log('');
  };

  showHelp();
  rl.prompt();

  while (!shuttingDown) {
    let answer;
    try {
      answer = await rl.question('assistant> ');
    } catch {
      break;
    }

    const command = answer.trim().toLowerCase();

    if (!command || command === 'help' || command === '?') {
      showHelp();
    } else if (command === 'once' || command === 'run') {
      runtimeLog.info('Processing queue once...');
      try {
        const result = await processQueue({ verbose: true, logger: orchestratorLog });
        statusTracker.update(result);
        runtimeLog.info(`Completed. Processed ${result.processed} task(s).`);
      } catch (error) {
        statusTracker.recordError(error);
        runtimeLog.error('Processing failed:', error);
      }
    } else if (command === 'status') {
      console.log(JSON.stringify(statusTracker.getStatus(), null, 2));
    } else if (command === 'exit' || command === 'quit') {
      await shutdown('user exit');
      break;
    } else {
      console.log(`Unknown command: ${command}`);
      showHelp();
    }

    if (shuttingDown) break;
    rl.prompt();
  }
}

export async function run_auto() {
  applyEnvDefaults();
  const logFactory = createLoggerFactory('auto');
  const runtimeLog = logFactory('runtime');
  const statusTracker = createStatusTracker('auto');
  statusTracker.markLoop(true);
  const servers = createServerBundle(statusTracker, logFactory);

  runtimeLog.info('Automatic mode engaged (polling every 5 seconds).');
  runtimeLog.info('Manual UI is still available at', servers.ui.url);
  runtimeLog.info('Health endpoint at', servers.api.url);

  const controller = new AbortController();

  const orchestratorLog = logFactory('orchestrator');

  const onCycle = (result) => {
    statusTracker.update(result);
    if (result.processed === 0) {
      orchestratorLog.info('No tasks to process this cycle.');
    }
  };

  const stop = (signal) => {
    runtimeLog.warn(`Received ${signal}. Stopping automatic loop...`);
    controller.abort();
  };

  process.once('SIGINT', stop);
  process.once('SIGTERM', stop);

  try {
    await runLoop({
      intervalMs: 5000,
      verbose: true,
      logger: orchestratorLog,
      signal: controller.signal,
      onCycle
    });
  } catch (error) {
    statusTracker.recordError(error);
    runtimeLog.error('Automatic loop error:', error);
  } finally {
    await gracefulShutdown({
      statusTracker,
      servers,
      logger: runtimeLog,
      reason: controller.signal.aborted ? 'signal received' : 'loop finished'
    });
  }
}

const mode = process.argv[2];
if (mode === 'manual') {
  run_manual().catch((error) => {
    console.error('[manual] fatal error', error);
    process.exitCode = 1;
  });
} else if (mode === 'auto') {
  run_auto().catch((error) => {
    console.error('[auto] fatal error', error);
    process.exitCode = 1;
  });
}
