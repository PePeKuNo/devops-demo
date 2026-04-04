const express = require('express');
const os = require('os');

const app = express();
const port = process.env.PORT || 3000;
let requestCount = 0;

app.use(express.json());
app.use((req, res, next) => {
  requestCount += 1;
  next();
});

let products = [
  { id: 1, name: 'Laptop' },
  { id: 2, name: 'Smartfon' }
];

function getRuntimeStats() {
  return {
    status: 'ok',
    uptimeSeconds: Number(process.uptime().toFixed(3)),
    serverTime: new Date().toISOString(),
    requestCount,
    backendInstanceId: process.env.INSTANCE_ID || os.hostname()
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

app.listen(port, () => {
  console.log(`Backend dziala na porcie ${port}`);
});
