#!/usr/bin/env node
/* eslint-disable no-console */

const assert = require('assert');
const fs = require('fs');
const http = require('http');
const os = require('os');
const path = require('path');

const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'pantree-phase2-'));
process.env.PANTREE_FOODS_FILE = path.join(tempDir, 'foods.json');
process.env.PANTREE_EVENTS_FILE = path.join(tempDir, 'events.json');

const express = require('express');
const {
  FOOD_PROFILES,
  LOCAL_RECIPES,
  ML_OPPORTUNITIES,
  normalizeFoodName,
  lookupFoodProfile,
} = require('./static-data');
const {
  FOODS_FILE,
  EVENTS_FILE,
  readFoods,
  writeFoods,
  readEvents,
  writeEvents,
  appendEvent,
} = require('./data-store');
const {
  normalizeFoodItem,
  normalizeInventory,
  buildPhase2Summary,
} = require('./intelligence');
const { VALID_EVENT_TYPES, createFoodEvent } = require('./event-service');
const { createPhase2Router } = require('./routes');

const tests = [];

function test(name, fn) {
  tests.push({ name, fn });
}

function resetFiles() {
  writeFoods({});
  writeEvents([]);
}

function isoDateFromToday(offsetDays) {
  const date = new Date();
  date.setDate(date.getDate() + offsetDays);
  return date.toISOString().slice(0, 10);
}

function sampleFoods() {
  return {
    101: {
      id: 101,
      name: 'Spinach',
      icon: '🥬',
      section: 'fridge',
      buyDate: isoDateFromToday(-2),
      expDate: isoDateFromToday(2),
      price: 4,
      quantity: 1,
      remainingQty: 1,
    },
    102: {
      id: 102,
      name: 'Eggs',
      icon: '🥚',
      section: 'fridge',
      buyDate: isoDateFromToday(-3),
      expDate: isoDateFromToday(12),
      price: 3.6,
      quantity: 12,
      remainingQty: 2,
    },
    103: {
      id: 103,
      name: 'Rice',
      icon: '🍚',
      section: 'shelf',
      buyDate: isoDateFromToday(-20),
      expDate: isoDateFromToday(260),
      price: 6,
      quantity: 1,
      remainingQty: 1,
    },
    104: {
      id: 104,
      name: 'Chips',
      icon: '🍽️',
      section: 'shelf',
      buyDate: isoDateFromToday(-1),
      expDate: isoDateFromToday(30),
      price: 5,
      quantity: 1,
      remainingQty: 1,
    },
  };
}

function requestJson(server, method, route, body) {
  const address = server.address();
  const payload = body == null ? null : JSON.stringify(body);

  return new Promise((resolve, reject) => {
    const req = http.request({
      hostname: '127.0.0.1',
      port: address.port,
      path: route,
      method,
      headers: payload ? {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(payload),
      } : undefined,
    }, (res) => {
      let raw = '';
      res.setEncoding('utf8');
      res.on('data', (chunk) => { raw += chunk; });
      res.on('end', () => {
        try {
          resolve({
            status: res.statusCode,
            body: raw ? JSON.parse(raw) : null,
          });
        } catch (err) {
          reject(err);
        }
      });
    });

    req.on('error', reject);
    if (payload) req.write(payload);
    req.end();
  });
}

test('feature completion checklist maps every Phase 2 planned feature to implementation data', () => {
  assert.ok(Object.keys(FOOD_PROFILES).length >= 20, 'local cache has common food profiles');
  assert.ok(LOCAL_RECIPES.length >= 5, 'local recipes are available');
  assert.ok(ML_OPPORTUNITIES.length >= 4, 'ML opportunities are documented in data');
  assert.ok(VALID_EVENT_TYPES.has('consume'));
  assert.ok(VALID_EVENT_TYPES.has('discard'));
});

test('normalizeFoodName cleans punctuation, casing, and whitespace', () => {
  assert.strictEqual(normalizeFoodName('  Baby-SPINACH!!  '), 'baby-spinach');
  assert.strictEqual(normalizeFoodName('Whole   Milk 2%'), 'whole milk 2');
});

test('lookupFoodProfile resolves exact names, aliases, and unknown foods locally', () => {
  assert.strictEqual(lookupFoodProfile('Spinach').category, 'produce');
  assert.strictEqual(lookupFoodProfile('baby spinach').key, 'spinach');
  assert.strictEqual(lookupFoodProfile('unmapped grocery item').category, 'unknown');
  assert.strictEqual(lookupFoodProfile(''), null);
});

test('data-store reads, writes, appends, and creates only test-local runtime files', () => {
  resetFiles();
  assert.strictEqual(FOODS_FILE, process.env.PANTREE_FOODS_FILE);
  assert.strictEqual(EVENTS_FILE, process.env.PANTREE_EVENTS_FILE);

  writeFoods(sampleFoods());
  assert.strictEqual(readFoods()['101'].name, 'Spinach');

  appendEvent({ id: 'evt_1', type: 'consume', foodId: '101' });
  assert.deepStrictEqual(readEvents().map((event) => event.id), ['evt_1']);
});

test('normalizeFoodItem enriches food with local profile, quantity, value, and expiry risk', () => {
  const item = normalizeFoodItem(sampleFoods()['101']);
  assert.strictEqual(item.id, '101');
  assert.strictEqual(item.canonicalName, 'spinach');
  assert.strictEqual(item.category, 'produce');
  assert.strictEqual(item.isActive, true);
  assert.strictEqual(item.estimatedValueAtRisk, 4);
  assert.ok(item.expiryRisk > 50, `expected high risk, got ${item.expiryRisk}`);
});

test('normalizeFoodItem treats used or empty food as inactive', () => {
  const item = normalizeFoodItem({ ...sampleFoods()['101'], section: 'used', remainingQty: 0 });
  assert.strictEqual(item.isActive, false);
  assert.strictEqual(item.expiryRisk, 0);
});

test('normalizeInventory converts food maps into enriched arrays', () => {
  const items = normalizeInventory(sampleFoods());
  assert.strictEqual(items.length, 4);
  assert.deepStrictEqual(items.map((item) => item.id), ['101', '102', '103', '104']);
});

test('buildPhase2Summary produces privacy, risk, health, shopping, meal, spending, and ML insights', () => {
  const summary = buildPhase2Summary(sampleFoods(), [
    { id: 'evt_old', type: 'consume', foodName: 'Milk', createdAt: new Date().toISOString() },
  ]);

  assert.strictEqual(summary.privacy.externalApisEnabled, false);
  assert.strictEqual(summary.inventory.active, 4);
  assert.ok(summary.healthBalance.score > 0);
  assert.ok(summary.healthBalance.insights.length > 0);
  assert.ok(summary.expiryRisks.some((risk) => risk.name === 'Spinach'));
  assert.ok(summary.shoppingSuggestions.some((suggestion) => suggestion.name === 'Eggs'));
  assert.ok(summary.shoppingSuggestions.some((suggestion) => suggestion.name === 'Milk'));
  assert.ok(summary.mealIdeas.some((meal) => meal.id === 'spinach-egg-scramble'));
  assert.strictEqual(summary.spending.purchasedValue, 18.6);
  assert.ok(summary.mlReadiness.opportunities.some((item) => item.area === 'Meal photo recognition'));
});

test('createFoodEvent consumes food, records an event, and keeps inventory active when remaining quantity stays above zero', () => {
  resetFiles();
  writeFoods(sampleFoods());

  const result = createFoodEvent({ type: 'consume', foodId: 102, amount: 1, unit: 'count' });
  assert.strictEqual(result.event.type, 'consume');
  assert.strictEqual(result.event.foodName, 'Eggs');
  assert.strictEqual(readFoods()['102'].remainingQty, 1);
  assert.strictEqual(readFoods()['102'].section, 'fridge');
  assert.strictEqual(readEvents().length, 1);
});

test('createFoodEvent marks food used when consumption reaches zero', () => {
  resetFiles();
  writeFoods(sampleFoods());

  createFoodEvent({ type: 'consume', foodId: 102, amount: 2, unit: 'count' });
  assert.strictEqual(readFoods()['102'].remainingQty, 0);
  assert.strictEqual(readFoods()['102'].section, 'used');
  assert.ok(readFoods()['102'].usedAt);
});

test('createFoodEvent discards food with a local reason and waste event', () => {
  resetFiles();
  writeFoods(sampleFoods());

  createFoodEvent({ type: 'discard', foodId: 101, reason: 'expired-or-spoiled' });
  assert.strictEqual(readFoods()['101'].section, 'used');
  assert.strictEqual(readFoods()['101'].discardReason, 'expired-or-spoiled');
  assert.strictEqual(readEvents()[0].reason, 'expired-or-spoiled');
});

test('createFoodEvent opens, moves, and restocks inventory modularly', () => {
  resetFiles();
  writeFoods(sampleFoods());

  createFoodEvent({ type: 'open', foodId: 103, openedAt: '2026-05-03T00:00:00.000Z' });
  assert.strictEqual(readFoods()['103'].openedAt, '2026-05-03T00:00:00.000Z');

  createFoodEvent({ type: 'move', foodId: 103, section: 'freezer' });
  assert.strictEqual(readFoods()['103'].section, 'freezer');

  createFoodEvent({ type: 'restock', foodId: 103, amount: 2, unit: 'bag' });
  assert.strictEqual(readFoods()['103'].quantity, 3);
  assert.strictEqual(readFoods()['103'].remainingQty, 3);
  assert.strictEqual(readEvents().length, 3);
});

test('createFoodEvent validates unsupported types and missing foods', () => {
  resetFiles();
  writeFoods(sampleFoods());

  assert.throws(() => createFoodEvent({ type: 'dance', foodId: 101 }), /Unsupported event type/);
  assert.throws(() => createFoodEvent({ type: 'consume', foodId: 'missing' }), /foodId is required/);
});

test('phase2 routes expose privacy, summary, events, and event creation over Express', async () => {
  resetFiles();
  writeFoods(sampleFoods());

  const app = express();
  app.use(express.json());
  app.use('/api/phase2', createPhase2Router());

  const server = await new Promise((resolve) => {
    const nextServer = app.listen(0, () => resolve(nextServer));
  });

  try {
    const privacy = await requestJson(server, 'GET', '/api/phase2/privacy');
    assert.strictEqual(privacy.status, 200);
    assert.strictEqual(privacy.body.externalApisEnabled, false);

    const summary = await requestJson(server, 'GET', '/api/phase2/summary');
    assert.strictEqual(summary.status, 200);
    assert.strictEqual(summary.body.inventory.active, 4);

    const eventResult = await requestJson(server, 'POST', '/api/phase2/events', {
      type: 'consume',
      foodId: 102,
      amount: 1,
      unit: 'count',
    });
    assert.strictEqual(eventResult.status, 200);
    assert.strictEqual(eventResult.body.event.type, 'consume');

    const events = await requestJson(server, 'GET', '/api/phase2/events');
    assert.strictEqual(events.status, 200);
    assert.strictEqual(events.body.events.length, 1);
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
});

async function run() {
  let failed = 0;

  for (const { name, fn } of tests) {
    try {
      resetFiles();
      await fn();
      console.log(`✓ ${name}`);
    } catch (err) {
      failed += 1;
      console.error(`✗ ${name}`);
      console.error(err.stack || err.message);
    }
  }

  fs.rmSync(tempDir, { recursive: true, force: true });

  if (failed > 0) {
    console.error(`\n${failed} Phase 2 test(s) failed.`);
    process.exit(1);
  }

  console.log(`\n${tests.length} Phase 2 unit/integration tests passed.`);
}

run();
