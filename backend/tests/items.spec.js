const request = require('supertest');
const { createApp } = require('../app');
const { createMemoryCache } = require('../cache');
const { createInMemoryStore } = require('../db');

describe('GET /items', () => {
  test('returns backend instance header for load-balancing verification', async () => {
    const app = createApp({
      instanceId: 'backend_1',
      storage: createInMemoryStore(),
      cache: createMemoryCache()
    });

    const response = await request(app).get('/items');

    expect(response.status).toBe(200);
    expect(response.headers['x-backend-instance']).toBe('backend_1');
    expect(Array.isArray(response.body)).toBe(true);
  });
});
