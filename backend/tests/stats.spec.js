const request = require('supertest');
const { createApp } = require('../app');

describe('GET /stats', () => {
  test('returns product count and cumulative request count after item creation', async () => {
    let currentTime = Date.parse('2026-04-04T13:35:00.000Z');
    const app = createApp({
      instanceId: 'stats-backend',
      now: () => currentTime
    });

    await request(app)
      .post('/items')
      .send({ name: 'Monitor' })
      .expect(201);

    currentTime += 2500;

    const response = await request(app).get('/stats');

    expect(response.status).toBe(200);
    expect(response.body).toEqual({
      totalProducts: 3,
      status: 'ok',
      uptimeSeconds: 2.5,
      serverTime: '2026-04-04T13:35:02.500Z',
      requestCount: 2,
      backendInstanceId: 'stats-backend'
    });
  });
});
