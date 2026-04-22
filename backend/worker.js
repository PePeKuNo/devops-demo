const { createRedisCache } = require('./cache');
const { createPostgresStore } = require('./db');
const { JOBS_QUEUE_KEY } = require('./app');

function sleep(ms) {
  return new Promise((resolve) => {
    setTimeout(resolve, ms);
  });
}

async function startWorker() {
  const workerId = process.env.WORKER_ID || 'worker';
  const storage = await createPostgresStore();
  await storage.init();

  const cache = await createRedisCache();
  let stopping = false;

  async function cleanup() {
    await Promise.allSettled([
      cache.disconnect(),
      storage.close()
    ]);
  }

  async function shutdown(signal) {
    if (stopping) {
      return;
    }

    stopping = true;
    console.log(`[${workerId}] Otrzymano ${signal}, zamykanie workera...`);
    await cleanup();
    process.exit(0);
  }

  for (const signal of ['SIGINT', 'SIGTERM']) {
    process.on(signal, () => {
      void shutdown(signal);
    });
  }

  console.log(`[${workerId}] Worker nasluchuje kolejki ${JOBS_QUEUE_KEY}`);

  while (!stopping) {
    try {
      const payload = await cache.pop(JOBS_QUEUE_KEY);
      if (!payload) {
        await sleep(2000);
        continue;
      }

      const job = JSON.parse(payload);
      await storage.healthCheck();
      await cache.setEx(
        `worker:last-processed:${workerId}`,
        300,
        JSON.stringify({
          ...job,
          processedAt: new Date().toISOString()
        })
      );
      console.log(
        `[${workerId}] Przetworzono zadanie ${job.type} dla item=${job.itemId} z backendu ${job.createdBy}`
      );
    } catch (error) {
      if (stopping) {
        break;
      }

      console.error(`[${workerId}] Blad przetwarzania zadania: ${error.message}`);
      await sleep(1000);
    }
  }
}

if (require.main === module) {
  startWorker().catch((error) => {
    console.error(`Nie udalo sie uruchomic workera: ${error.message}`);
    process.exit(1);
  });
}

module.exports = {
  startWorker
};
