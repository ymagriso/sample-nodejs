const { test } = require('node:test');
const assert = require('node:assert/strict');
const request = require('supertest');

const app = require('../app');

test('GET /my-app returns Hello, World!', async () => {
    const res = await request(app).get('/my-app');
    assert.equal(res.status, 200);
    assert.equal(res.text, 'Hello, World!');
});

test('GET /about returns the description', async () => {
    const res = await request(app).get('/about');
    assert.equal(res.status, 200);
    assert.match(res.text, /sample Node\.js application/);
});

test('GET /ready returns 200 Ready', async () => {
    const res = await request(app).get('/ready');
    assert.equal(res.status, 200);
    assert.equal(res.text, 'Ready');
});

test('GET /live returns 200 Alive', async () => {
    const res = await request(app).get('/live');
    assert.equal(res.status, 200);
    assert.equal(res.text, 'Alive');
});

test('GET /metrics exposes Prometheus metrics including root_access_total', async () => {
    await request(app).get('/my-app');
    const res = await request(app).get('/metrics');
    assert.equal(res.status, 200);
    assert.match(res.headers['content-type'], /text\/plain/);
    assert.match(res.text, /# TYPE root_access_total counter/);
    assert.match(res.text, /^root_access_total [1-9]\d*$/m);
    assert.match(res.text, /process_cpu_user_seconds_total/);
});

test('unknown route returns 404', async () => {
    const res = await request(app).get('/does-not-exist');
    assert.equal(res.status, 404);
});
