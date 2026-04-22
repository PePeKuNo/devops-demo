const { createClient } = require('redis');

function createMemoryCache() {
  const store = new Map();
  const queues = new Map();

  function readEntry(key) {
    const entry = store.get(key);
    if (!entry) {
      return null;
    }

    if (entry.expiresAt <= Date.now()) {
      store.delete(key);
      return null;
    }

    return entry.value;
  }

  return {
    async get(key) {
      return readEntry(key);
    },
    async setEx(key, ttlSeconds, value) {
      store.set(key, {
        value,
        expiresAt: Date.now() + (ttlSeconds * 1000)
      });
    },
    async del(key) {
      store.delete(key);
    },
    async enqueue(key, value) {
      const queue = queues.get(key) || [];
      queue.unshift(value);
      queues.set(key, queue);
    },
    async pop(key) {
      const queue = queues.get(key) || [];
      if (queue.length === 0) {
        return null;
      }

      return queue.pop();
    },
    async healthCheck() {
      return 'up';
    },
    async disconnect() {}
  };
}

async function createRedisCache(config = {}) {
  const client = createClient({
    url: config.url || process.env.REDIS_URL || `redis://${process.env.REDIS_HOST || 'localhost'}:${process.env.REDIS_PORT || '6379'}`
  });

  client.on('error', (error) => {
    if (typeof config.onError === 'function') {
      config.onError(error);
      return;
    }

    console.error(`Redis error: ${error.message}`);
  });

  await client.connect();

  return {
    async get(key) {
      return client.get(key);
    },
    async setEx(key, ttlSeconds, value) {
      await client.setEx(key, ttlSeconds, value);
    },
    async del(key) {
      await client.del(key);
    },
    async enqueue(key, value) {
      await client.lPush(key, value);
    },
    async pop(key) {
      return client.rPop(key);
    },
    async healthCheck() {
      await client.ping();
      return 'up';
    },
    async disconnect() {
      if (client.isOpen) {
        await client.quit();
      }
    }
  };
}

module.exports = {
  createMemoryCache,
  createRedisCache
};
