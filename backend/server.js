const { createApp } = require('./app');
const { createRedisCache } = require('./cache');
const { createPostgresStore } = require('./db');

async function startServer() {
  const storage = await createPostgresStore();
  await storage.init();

  const cache = await createRedisCache();
  const responseSignature = 'server.js response v3';
  const app = createApp({ storage, cache, responseSignature });
  const port = Number(process.env.PORT || 3000);

  const server = app.listen(port, () => {
    console.log(`Backend dziala na porcie ${port}`);
  });

  async function cleanup() {
    await Promise.allSettled([
      cache.disconnect(),
      storage.close()
    ]);
  }

  async function shutdown(signal) {
    console.log(`Otrzymano ${signal}, zamykanie serwera...`);

    server.close(() => {
      cleanup()
        .then(() => process.exit(0))
        .catch((error) => {
          console.error(`Blad przy zamykaniu zasobow: ${error.message}`);
          process.exit(1);
        });
    });

    setTimeout(() => {
      console.error('Wymuszone zatrzymanie procesu po przekroczeniu limitu czasu.');
      process.exit(1);
    }, 10000).unref();
  }

  for (const signal of ['SIGINT', 'SIGTERM']) {
    process.on(signal, () => {
      void shutdown(signal);
    });
  }

  return server;
}

if (require.main === module) {
  startServer().catch((error) => {
    console.error(`Nie udalo sie uruchomic backendu: ${error.message}`);
    process.exit(1);
  });
}

module.exports = {
  startServer
};
