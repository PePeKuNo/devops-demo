const request = require('supertest');
const { createApp } = require('../app');
const { createMemoryCache } = require('../cache');
const { createInMemoryStore } = require('../db');

describe('GET /health', () => {
  test('returns health payload with postgres and redis status fields', async () => {
    let currentTime = Date.parse('2026-04-04T13:30:00.000Z');
    const app = createApp({
      instanceId: 'test-backend',
      now: () => currentTime,
      storage: createInMemoryStore(),
      cache: createMemoryCache()
    });

    currentTime += 1500;

    const response = await request(app).get('/health');

    expect(response.status).toBe(200);
    expect(response.body).toEqual({
      status: 'ok',
      uptimeSeconds: 1.5,
      serverTime: '2026-04-04T13:30:01.500Z',
      requestCount: 1,
      backendInstanceId: 'test-backend',
      postgres: 'up',
      redis: 'up'
    });
  });
});
