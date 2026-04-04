const express = require('express');
const os = require('os');

const defaultProducts = [
  { id: 1, name: 'Laptop' },
  { id: 2, name: 'Smartfon' }
];

function createApp(options = {}) {
  const app = express();
  const now = options.now || (() => Date.now());
  const startedAt = now();
  const backendInstanceId = options.instanceId || process.env.INSTANCE_ID || os.hostname();
  let requestCount = 0;
  let products = options.products ? [...options.products] : [...defaultProducts];

  app.use(express.json());
  app.use((req, res, next) => {
    requestCount += 1;
    next();
  });

  function getRuntimeStats() {
    return {
      status: 'ok',
      uptimeSeconds: Number(((now() - startedAt) / 1000).toFixed(3)),
      serverTime: new Date(now()).toISOString(),
      requestCount,
      backendInstanceId
    };
  }

  app.get('/health', (req, res) => {
    res.json(getRuntimeStats());
  });

  app.get('/items', (req, res) => {
    res.json(products);
  });

  app.post('/items', (req, res) => {
    const newProduct = {
      id: products.length + 1,
      name: req.body.name || 'Nowy produkt'
    };

    products.push(newProduct);
    res.status(201).json(newProduct);
  });

  app.get('/stats', (req, res) => {
    res.json({
      totalProducts: products.length,
      ...getRuntimeStats()
    });
  });

  return app;
}

module.exports = { createApp };
