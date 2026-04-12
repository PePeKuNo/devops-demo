const { Pool } = require('pg');

const defaultProducts = [
  { id: 1, name: 'Laptop' },
  { id: 2, name: 'Smartfon' }
];

function cloneProducts(products) {
  return products.map((product, index) => ({
    id: product.id ?? index + 1,
    name: product.name
  }));
}

function createInMemoryStore(initialProducts = defaultProducts) {
  const products = cloneProducts(initialProducts);

  return {
    async init() {},
    async healthCheck() {
      return 'up';
    },
    async listItems() {
      return cloneProducts(products);
    },
    async createItem(name) {
      const newProduct = {
        id: products.length + 1,
        name
      };

      products.push(newProduct);
      return { ...newProduct };
    },
    async countItems() {
      return products.length;
    },
    async close() {}
  };
}

async function createPostgresStore(config = {}) {
  const pool = new Pool({
    host: config.host || process.env.POSTGRES_HOST || 'localhost',
    port: Number(config.port || process.env.POSTGRES_PORT || 5432),
    database: config.database || process.env.POSTGRES_DB || 'products',
    user: config.user || process.env.POSTGRES_USER || 'products',
    password: config.password || process.env.POSTGRES_PASSWORD || 'products',
    max: Number(config.max || process.env.POSTGRES_POOL_MAX || 10),
    idleTimeoutMillis: Number(config.idleTimeoutMillis || process.env.POSTGRES_IDLE_TIMEOUT_MS || 10000)
  });

  pool.on('error', (error) => {
    console.error(`PostgreSQL pool error: ${error.message}`);
  });

  async function init() {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS items (
        id SERIAL PRIMARY KEY,
        name TEXT NOT NULL,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
    `);

    const result = await pool.query('SELECT COUNT(*)::int AS total FROM items');
    if (result.rows[0].total === 0) {
      for (const product of defaultProducts) {
        await pool.query(
          'INSERT INTO items (name) VALUES ($1)',
          [product.name]
        );
      }
    }
  }

  return {
    init,
    async healthCheck() {
      await pool.query('SELECT 1');
      return 'up';
    },
    async listItems() {
      const result = await pool.query(
        'SELECT id, name FROM items ORDER BY id ASC'
      );
      return result.rows;
    },
    async createItem(name) {
      const result = await pool.query(
        'INSERT INTO items (name) VALUES ($1) RETURNING id, name',
        [name]
      );
      return result.rows[0];
    },
    async countItems() {
      const result = await pool.query('SELECT COUNT(*)::int AS total FROM items');
      return result.rows[0].total;
    },
    async close() {
      await pool.end();
    }
  };
}

module.exports = {
  createInMemoryStore,
  createPostgresStore,
  defaultProducts
};
