const express = require('express');

const { readEvents, readFoods } = require('./data-store');
const { buildPhase2Summary } = require('./intelligence');
const { createFoodEvent } = require('./event-service');

function createPhase2Router() {
  const router = express.Router();

  router.get('/summary', (req, res) => {
    const foods = readFoods();
    const events = readEvents();
    res.json(buildPhase2Summary(foods, events));
  });

  router.get('/events', (req, res) => {
    res.json({ events: readEvents() });
  });

  router.post('/events', (req, res) => {
    try {
      const result = createFoodEvent(req.body || {});
      res.json(result);
    } catch (err) {
      res.status(err.statusCode || 500).json({ error: err.message });
    }
  });

  router.get('/privacy', (req, res) => {
    res.json({
      mode: 'local-only POC',
      externalApisEnabled: false,
      dataFiles: ['bridge-server/pantree-data.json', 'bridge-server/pantree-events.json'],
      note: 'Phase 2 routes do not call third-party APIs. Keep runtime JSON files out of Git to protect household food data.',
    });
  });

  return router;
}

module.exports = { createPhase2Router };
