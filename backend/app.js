const express = require('express');
const os = require('os');
const { createMemoryCache } = require('./cache');
const { createInMemoryStore } = require('./db');

const STATS_CACHE_KEY = 'stats:total-products';
const STATS_CACHE_TTL_SECONDS = 10;

function asyncHandler(handler) {
  return (req, res, next) => {
    Promise.resolve(handler(req, res, next)).catch(next);
  };
}

function normalizeHealthStatus(value) {
  return value === 'up' || value === true ? 'up' : 'down';
}

function createApp(options = {}) {
  const app = express();
  const now = options.now || (() => Date.now());
  const storage = options.storage || createInMemoryStore(options.products);
  const cache = options.cache || createMemoryCache();
  const startedAt = now();
  const backendInstanceId = options.instanceId || process.env.INSTANCE_ID || os.hostname();
  const responseSignature = options.responseSignature;
  let requestCount = 0;

  app.use(express.json());
  app.use((req, res, next) => {
    requestCount += 1;
    next();
  });

  function getRuntimeStats() {
    const stats = {
      status: 'ok',
      uptimeSeconds: Number(((now() - startedAt) / 1000).toFixed(3)),
      serverTime: new Date(now()).toISOString(),
      requestCount,
      backendInstanceId
    };

    if (responseSignature) {
      stats.responseSignature = responseSignature;
    }

    return stats;
  }

  app.get('/health', asyncHandler(async (req, res) => {
    const [postgresResult, redisResult] = await Promise.allSettled([
      storage.healthCheck(),
      cache.healthCheck()
    ]);

    const postgres = postgresResult.status === 'fulfilled'
      ? normalizeHealthStatus(postgresResult.value)
      : 'down';
    const redis = redisResult.status === 'fulfilled'
      ? normalizeHealthStatus(redisResult.value)
      : 'down';
    const isHealthy = postgres === 'up' && redis === 'up';

    res.status(isHealthy ? 200 : 503).json({
      ...getRuntimeStats(),
      status: isHealthy ? 'ok' : 'degraded',
      postgres,
      redis
    });
  }));

  app.get('/items', asyncHandler(async (req, res) => {
    const products = await storage.listItems();
    res.json(products);
  }));

  app.post('/items', asyncHandler(async (req, res) => {
    const newProduct = await storage.createItem(req.body.name || 'Nowy produkt');
    try {
      await cache.del(STATS_CACHE_KEY);
    } catch (error) {
      console.error(`Nie udalo sie uniewaznic cache stats: ${error.message}`);
    }

    res.status(201).json(newProduct);
  }));

  app.get('/stats', asyncHandler(async (req, res) => {
    let totalProducts;
    let cachedTotalProducts = null;

    try {
      cachedTotalProducts = await cache.get(STATS_CACHE_KEY);
    } catch (error) {
      console.error(`Nie udalo sie odczytac cache stats: ${error.message}`);
    }

    if (cachedTotalProducts != null) {
      totalProducts = Number(cachedTotalProducts);
      res.set('X-Cache', 'HIT');
    } else {
      totalProducts = await storage.countItems();

      try {
        await cache.setEx(STATS_CACHE_KEY, STATS_CACHE_TTL_SECONDS, String(totalProducts));
      } catch (error) {
        console.error(`Nie udalo sie zapisac cache stats: ${error.message}`);
      }

      res.set('X-Cache', 'MISS');
    }

    res.json({
      totalProducts,
      ...getRuntimeStats()
    });
  }));

  app.use((error, req, res, next) => {
    if (res.headersSent) {
      next(error);
      return;
    }

    res.status(500).json({
      error: 'internal_error',
      message: error.message
    });
  });

  return app;
}

module.exports = {
  createApp,
  STATS_CACHE_KEY,
  STATS_CACHE_TTL_SECONDS
};
