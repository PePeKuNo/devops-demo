const request = require('supertest');
const { createApp } = require('../app');
const { createMemoryCache } = require('../cache');
const { createInMemoryStore } = require('../db');

describe('GET /stats', () => {
  test('uses Redis-style cache header and keeps runtime metrics fresh', async () => {
    let currentTime = Date.parse('2026-04-04T13:35:00.000Z');
    const app = createApp({
      instanceId: 'stats-backend',
      now: () => currentTime,
      storage: createInMemoryStore(),
      cache: createMemoryCache()
    });

    await request(app)
      .post('/items')
      .send({ name: 'Monitor' })
      .expect(201);

    currentTime += 2500;

    const firstResponse = await request(app).get('/stats');

    expect(firstResponse.status).toBe(200);
    expect(firstResponse.headers['x-cache']).toBe('MISS');
    expect(firstResponse.body).toEqual({
      totalProducts: 3,
      status: 'ok',
      uptimeSeconds: 2.5,
      serverTime: '2026-04-04T13:35:02.500Z',
      requestCount: 2,
      backendInstanceId: 'stats-backend'
    });

    currentTime += 1000;

    const secondResponse = await request(app).get('/stats');

    expect(secondResponse.status).toBe(200);
    expect(secondResponse.headers['x-cache']).toBe('HIT');
    expect(secondResponse.body).toEqual({
      totalProducts: 3,
      status: 'ok',
      uptimeSeconds: 3.5,
      serverTime: '2026-04-04T13:35:03.500Z',
      requestCount: 3,
      backendInstanceId: 'stats-backend'
    });
  });
});
