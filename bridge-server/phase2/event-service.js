/**
 * Local food event service for Phase 2.
 *
 * It updates current inventory only for simple POC actions while preserving a
 * local event history for future analytics and ML training data.
 */

const { appendEvent, readFoods, writeFoods } = require('./data-store');
const { normalizeFoodItem } = require('./intelligence');

const VALID_EVENT_TYPES = new Set(['consume', 'discard', 'open', 'move', 'restock', 'edit', 'purchase']);

function makeEventId() {
  return `evt_${Date.now()}_${Math.floor(Math.random() * 100000)}`;
}

function toNumber(value, fallback = null) {
  const number = Number(value);
  return Number.isFinite(number) ? number : fallback;
}

function createFoodEvent(payload = {}) {
  const type = payload.type;
  if (!VALID_EVENT_TYPES.has(type)) {
    const err = new Error(`Unsupported event type: ${type}`);
    err.statusCode = 400;
    throw err;
  }

  const foods = readFoods();
  const foodId = payload.foodId != null ? String(payload.foodId) : null;
  const foodKey = foodId && Object.prototype.hasOwnProperty.call(foods, foodId)
    ? foodId
    : Object.keys(foods).find((key) => String(foods[key].id) === foodId);

  const existingFood = foodKey ? foods[foodKey] : null;
  if (!existingFood && ['consume', 'discard', 'open', 'move', 'restock'].includes(type)) {
    const err = new Error('foodId is required and must match an existing food item for this event type');
    err.statusCode = 404;
    throw err;
  }

  let updatedFood = existingFood ? normalizeFoodItem(existingFood) : null;
  const eventAmount = toNumber(payload.amount, null);
  const amount = eventAmount == null && updatedFood
    ? Math.min(1, Math.max(updatedFood.remainingQty, 0))
    : eventAmount;
  const unit = payload.unit || updatedFood?.unit || 'item';

  const event = {
    id: makeEventId(),
    type,
    foodId: updatedFood?.id || foodId || null,
    foodName: updatedFood?.name || payload.foodName || payload.name || null,
    amount,
    unit,
    reason: payload.reason || null,
    note: payload.note || null,
    source: payload.source || 'phase2-dashboard',
    createdAt: new Date().toISOString(),
  };

  if (updatedFood) {
    const foodToSave = { ...foods[foodKey] };

    if (type === 'consume') {
      const current = updatedFood.remainingQty;
      const consumed = amount == null ? current : amount;
      const nextRemaining = Math.max(0, current - consumed);
      foodToSave.quantity = updatedFood.quantity;
      foodToSave.remainingQty = Number(nextRemaining.toFixed(2));
      foodToSave.unit = unit;
      if (nextRemaining <= 0) {
        foodToSave.section = 'used';
        foodToSave.usedAt = event.createdAt;
      }
    }

    if (type === 'discard') {
      foodToSave.quantity = updatedFood.quantity;
      foodToSave.remainingQty = 0;
      foodToSave.unit = unit;
      foodToSave.section = 'used';
      foodToSave.discardedAt = event.createdAt;
      foodToSave.discardReason = payload.reason || 'unspecified';
    }

    if (type === 'open') {
      foodToSave.openedAt = payload.openedAt || event.createdAt;
    }

    if (type === 'move' && payload.section) {
      foodToSave.section = payload.section;
    }

    if (type === 'restock') {
      const restockAmount = amount == null ? updatedFood.quantity : amount;
      foodToSave.quantity = Number((updatedFood.quantity + restockAmount).toFixed(2));
      foodToSave.remainingQty = Number((updatedFood.remainingQty + restockAmount).toFixed(2));
      foodToSave.unit = unit;
      if (foodToSave.section === 'used') {
        foodToSave.section = payload.section || 'fridge';
      }
    }

    foods[foodKey] = foodToSave;
    writeFoods(foods);
    updatedFood = foodToSave;
  }

  appendEvent(event);

  return {
    event,
    food: updatedFood,
  };
}

module.exports = {
  VALID_EVENT_TYPES,
  createFoodEvent,
};
