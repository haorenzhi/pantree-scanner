/**
 * Local Phase 2 food intelligence.
 *
 * All calculations are transparent rules for the POC. They are intentionally
 * deterministic and local so we can later replace any individual function with a
 * model or better algorithm without rewriting the product surface.
 */

const { LOCAL_RECIPES, ML_OPPORTUNITIES, lookupFoodProfile, normalizeFoodName } = require('./static-data');

const DAY_MS = 24 * 60 * 60 * 1000;

function todayDate() {
  const now = new Date();
  return new Date(now.getFullYear(), now.getMonth(), now.getDate());
}

function parseDate(dateStr) {
  if (!dateStr) return null;
  const parsed = new Date(dateStr);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

function daysUntil(dateStr) {
  const date = parseDate(dateStr);
  if (!date) return null;
  return Math.ceil((date.getTime() - todayDate().getTime()) / DAY_MS);
}

function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value));
}

function toNumber(value, fallback = 0) {
  const number = Number(value);
  return Number.isFinite(number) ? number : fallback;
}

function normalizeFoodItem(food) {
  const profile = lookupFoodProfile(food.name);
  const quantity = toNumber(food.quantity, profile.defaultQuantity || 1);
  const remainingQty = toNumber(
    food.remainingQty,
    food.section === 'used' ? 0 : quantity,
  );
  const daysLeft = daysUntil(food.expDate);
  const remainingShare = quantity > 0 ? clamp(remainingQty / quantity, 0, 1) : 0;
  const price = food.price == null ? null : toNumber(food.price, null);
  const isActive = food.section !== 'used' && remainingQty > 0;
  const isExpired = daysLeft != null && daysLeft < 0;
  const isExpiringSoon = daysLeft != null && daysLeft >= 0 && daysLeft <= 3;

  let expiryRisk = 0;
  if (isActive && daysLeft != null) {
    if (isExpired) {
      expiryRisk = 100;
    } else {
      const timePressure = clamp(90 - daysLeft * 12, 0, 90);
      const perishability = profile.perishable ? 10 : 0;
      const valuePressure = price ? clamp(price / 2, 0, 10) : 0;
      expiryRisk = clamp(Math.round(timePressure + perishability + valuePressure), 0, 100);
    }
  }

  return {
    ...food,
    id: String(food.id),
    canonicalName: profile.key,
    category: food.category || profile.category,
    group: profile.group,
    quantity,
    remainingQty,
    unit: food.unit || profile.defaultUnit || 'item',
    serving: profile.serving,
    nutrition: food.nutrition || profile.nutrition,
    daysUntilExpiration: daysLeft,
    remainingShare,
    price,
    estimatedValueAtRisk: price == null ? null : Number((price * remainingShare).toFixed(2)),
    isActive,
    isExpired,
    isExpiringSoon,
    expiryRisk,
  };
}

function normalizeInventory(foods) {
  return Object.values(foods || {}).map(normalizeFoodItem);
}

function summarizeInventory(items) {
  const active = items.filter((item) => item.isActive);
  const bySection = active.reduce((acc, item) => {
    acc[item.section] = (acc[item.section] || 0) + 1;
    return acc;
  }, {});
  const byCategory = active.reduce((acc, item) => {
    acc[item.category] = (acc[item.category] || 0) + 1;
    return acc;
  }, {});

  return {
    total: items.length,
    active: active.length,
    used: items.filter((item) => item.section === 'used').length,
    bySection,
    byCategory,
  };
}

function buildExpiryRisks(items) {
  return items
    .filter((item) => item.isActive && item.expiryRisk > 0)
    .sort((a, b) => b.expiryRisk - a.expiryRisk)
    .slice(0, 8)
    .map((item) => ({
      id: item.id,
      name: item.name,
      icon: item.icon,
      section: item.section,
      expDate: item.expDate,
      daysUntilExpiration: item.daysUntilExpiration,
      expiryRisk: item.expiryRisk,
      estimatedValueAtRisk: item.estimatedValueAtRisk,
      reason: item.isExpired
        ? 'Expired — confirm safety before eating.'
        : item.daysUntilExpiration <= 3
          ? 'Expiring soon — good candidate for the next meal.'
          : 'Higher risk because it is perishable or valuable.',
    }));
}

function buildWasteSummary(items, events) {
  const discardedEvents = events.filter((event) => event.type === 'discard');
  const valueAtRisk = items.reduce((sum, item) => {
    if (!item.isActive || item.estimatedValueAtRisk == null || item.expiryRisk < 50) return sum;
    return sum + item.estimatedValueAtRisk;
  }, 0);

  const wasteByReason = discardedEvents.reduce((acc, event) => {
    const reason = event.reason || 'unspecified';
    acc[reason] = (acc[reason] || 0) + 1;
    return acc;
  }, {});

  return {
    estimatedValueAtRisk: Number(valueAtRisk.toFixed(2)),
    discardedEvents: discardedEvents.length,
    wasteByReason,
    message: valueAtRisk > 0
      ? `About $${valueAtRisk.toFixed(2)} of food may be at risk if not used soon.`
      : 'No high-value waste risk detected yet.',
  };
}

function buildHealthBalance(items) {
  const active = items.filter((item) => item.isActive);
  const total = active.length || 1;
  const counts = active.reduce((acc, item) => {
    acc[item.category] = (acc[item.category] || 0) + 1;
    return acc;
  }, {});

  const produceShare = (counts.produce || 0) / total;
  const proteinShare = (counts.protein || 0) / total;
  const treatShare = (counts.treat || 0) / total;
  const insights = [];

  if (active.length === 0) {
    insights.push('Scan a receipt or add foods to get local health-balance insights.');
  } else {
    if (produceShare < 0.3) {
      insights.push('Consider adding more fruits or vegetables to improve household food balance.');
    } else {
      insights.push('Good produce coverage is available at home.');
    }

    if (proteinShare < 0.15) {
      insights.push('Protein options look limited; consider eggs, tofu, beans, fish, or lean meats.');
    }

    if (treatShare > 0.25) {
      insights.push('Treats/snacks are a large share of current inventory; keep portions intentional.');
    }

    const expiringProduce = active.filter((item) => item.category === 'produce' && item.daysUntilExpiration != null && item.daysUntilExpiration <= 3);
    if (expiringProduce.length > 0) {
      insights.push(`Use ${expiringProduce[0].name} soon to reduce waste and keep meals fresh.`);
    }
  }

  const score = clamp(Math.round(produceShare * 45 + proteinShare * 30 + (1 - treatShare) * 25), 0, 100);

  return {
    score,
    counts,
    produceShare: Number(produceShare.toFixed(2)),
    proteinShare: Number(proteinShare.toFixed(2)),
    treatShare: Number(treatShare.toFixed(2)),
    label: 'Estimated grocery balance, not medical nutrition advice.',
    insights,
  };
}

function buildSpending(items) {
  const purchasedValue = items.reduce((sum, item) => sum + (item.price || 0), 0);
  const activeValue = items.reduce((sum, item) => {
    if (!item.isActive || item.estimatedValueAtRisk == null) return sum;
    return sum + item.estimatedValueAtRisk;
  }, 0);

  const byCategory = items.reduce((acc, item) => {
    if (!item.price) return acc;
    acc[item.category] = Number(((acc[item.category] || 0) + item.price).toFixed(2));
    return acc;
  }, {});

  return {
    purchasedValue: Number(purchasedValue.toFixed(2)),
    activeEstimatedValue: Number(activeValue.toFixed(2)),
    byCategory,
  };
}

function buildShoppingSuggestions(items, events) {
  const activeNames = new Set(items.filter((item) => item.isActive).map((item) => item.canonicalName));
  const suggestions = [];

  for (const item of items) {
    if (!item.isActive) continue;
    if (item.remainingShare <= 0.25) {
      suggestions.push({
        name: item.name,
        reason: 'Current inventory is low.',
        source: 'remaining-quantity',
        priority: 'high',
      });
    }
  }

  const recentEvents = events
    .filter((event) => ['consume', 'discard'].includes(event.type))
    .slice(-30)
    .reverse();

  for (const event of recentEvents) {
    const key = normalizeFoodName(event.foodName || event.name || '');
    if (!key || activeNames.has(key)) continue;
    if (suggestions.some((suggestion) => normalizeFoodName(suggestion.name) === key)) continue;
    suggestions.push({
      name: event.foodName || event.name,
      reason: event.type === 'consume'
        ? 'Recently consumed and no active matching item is left.'
        : 'Recently discarded; only restock if you still plan to use it.',
      source: `event-${event.type}`,
      priority: event.type === 'consume' ? 'medium' : 'low',
    });
  }

  return suggestions.slice(0, 8);
}

function buildMealIdeas(items) {
  const active = items.filter((item) => item.isActive);
  const activeNames = new Set(active.map((item) => item.canonicalName));
  const expiringNames = new Set(
    active
      .filter((item) => item.daysUntilExpiration != null && item.daysUntilExpiration <= 3)
      .map((item) => item.canonicalName),
  );

  return LOCAL_RECIPES.map((recipe) => {
    const matched = recipe.ingredients.filter((ingredient) => activeNames.has(ingredient));
    const missing = recipe.ingredients.filter((ingredient) => !activeNames.has(ingredient));
    const expiringMatches = recipe.ingredients.filter((ingredient) => expiringNames.has(ingredient));
    const matchScore = Math.round((matched.length / recipe.ingredients.length) * 100);

    return {
      ...recipe,
      matched,
      missing,
      expiringMatches,
      matchScore,
    };
  })
    .filter((recipe) => recipe.matched.length > 0)
    .sort((a, b) => {
      if (b.expiringMatches.length !== a.expiringMatches.length) {
        return b.expiringMatches.length - a.expiringMatches.length;
      }
      return b.matchScore - a.matchScore;
    })
    .slice(0, 5);
}

function buildMlReadiness(items, events) {
  const confirmedMealEvents = events.filter((event) => event.type === 'consume' && event.source === 'meal-photo-confirmed').length;
  const correctionEvents = events.filter((event) => event.type === 'edit' && event.source === 'receipt-correction').length;

  return {
    privacyMode: 'local-first; no cloud training in this POC',
    usefulDataAlreadyCollectable: [
      'confirmed consume/discard/restock events',
      'receipt OCR item names and user corrections',
      'remaining quantity edits',
      'expiration outcomes',
    ],
    readinessSignals: {
      inventoryItems: items.length,
      eventCount: events.length,
      confirmedMealEvents,
      correctionEvents,
    },
    opportunities: ML_OPPORTUNITIES,
  };
}

function buildPhase2Summary(foods, events) {
  const items = normalizeInventory(foods);

  return {
    generatedAt: new Date().toISOString(),
    privacy: {
      mode: 'local-only POC',
      externalApisEnabled: false,
      storage: 'bridge-server local JSON files',
      note: 'No personal food, receipt, or meal data is sent to third-party services by Phase 2 routes.',
    },
    inventory: summarizeInventory(items),
    healthBalance: buildHealthBalance(items),
    expiryRisks: buildExpiryRisks(items),
    waste: buildWasteSummary(items, events || []),
    spending: buildSpending(items),
    shoppingSuggestions: buildShoppingSuggestions(items, events || []),
    mealIdeas: buildMealIdeas(items),
    mlReadiness: buildMlReadiness(items, events || []),
  };
}

module.exports = {
  normalizeFoodItem,
  normalizeInventory,
  buildPhase2Summary,
};
