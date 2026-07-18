/**
 * Phase 2 local-only intelligence cache.
 *
 * This module intentionally does not call external APIs. It gives the POC
 * enough local nutrition/category/recipe context to validate the product flow
 * while keeping private household food data on the user's machine.
 */

const FOOD_PROFILES = {
  apples: {
    aliases: ['apple'],
    category: 'produce',
    group: 'fruit',
    defaultUnit: 'item',
    defaultQuantity: 1,
    serving: { quantity: 1, unit: 'item' },
    nutrition: { calories: 95, protein: 0.5, carbs: 25, fat: 0.3, fiber: 4.4 },
    perishable: true,
  },
  bananas: {
    aliases: ['banana'],
    category: 'produce',
    group: 'fruit',
    defaultUnit: 'item',
    defaultQuantity: 1,
    serving: { quantity: 1, unit: 'item' },
    nutrition: { calories: 105, protein: 1.3, carbs: 27, fat: 0.4, fiber: 3.1 },
    perishable: true,
  },
  blueberries: {
    aliases: ['blueberry'],
    category: 'produce',
    group: 'fruit',
    defaultUnit: 'cup',
    defaultQuantity: 1,
    serving: { quantity: 1, unit: 'cup' },
    nutrition: { calories: 84, protein: 1.1, carbs: 21, fat: 0.5, fiber: 3.6 },
    perishable: true,
  },
  strawberries: {
    aliases: ['strawberry'],
    category: 'produce',
    group: 'fruit',
    defaultUnit: 'cup',
    defaultQuantity: 1,
    serving: { quantity: 1, unit: 'cup' },
    nutrition: { calories: 49, protein: 1, carbs: 12, fat: 0.5, fiber: 3 },
    perishable: true,
  },
  broccoli: {
    aliases: ['broccoli crown'],
    category: 'produce',
    group: 'vegetable',
    defaultUnit: 'head',
    defaultQuantity: 1,
    serving: { quantity: 1, unit: 'cup' },
    nutrition: { calories: 31, protein: 2.5, carbs: 6, fat: 0.3, fiber: 2.4 },
    perishable: true,
  },
  spinach: {
    aliases: ['baby spinach'],
    category: 'produce',
    group: 'vegetable',
    defaultUnit: 'bag',
    defaultQuantity: 1,
    serving: { quantity: 2, unit: 'cups' },
    nutrition: { calories: 14, protein: 1.7, carbs: 2.2, fat: 0.2, fiber: 1.4 },
    perishable: true,
  },
  lettuce: {
    aliases: ['romaine', 'greens'],
    category: 'produce',
    group: 'vegetable',
    defaultUnit: 'head',
    defaultQuantity: 1,
    serving: { quantity: 2, unit: 'cups' },
    nutrition: { calories: 16, protein: 1, carbs: 3, fat: 0.2, fiber: 2 },
    perishable: true,
  },
  tomatoes: {
    aliases: ['tomato'],
    category: 'produce',
    group: 'vegetable',
    defaultUnit: 'item',
    defaultQuantity: 1,
    serving: { quantity: 1, unit: 'item' },
    nutrition: { calories: 22, protein: 1.1, carbs: 4.8, fat: 0.2, fiber: 1.5 },
    perishable: true,
  },
  carrots: {
    aliases: ['carrot'],
    category: 'produce',
    group: 'vegetable',
    defaultUnit: 'bag',
    defaultQuantity: 1,
    serving: { quantity: 1, unit: 'cup' },
    nutrition: { calories: 52, protein: 1.2, carbs: 12, fat: 0.3, fiber: 3.6 },
    perishable: true,
  },
  milk: {
    aliases: ['whole milk', '2% milk', 'almond milk', 'oat milk'],
    category: 'dairy',
    group: 'dairy',
    defaultUnit: 'carton',
    defaultQuantity: 1,
    serving: { quantity: 1, unit: 'cup' },
    nutrition: { calories: 149, protein: 7.7, carbs: 12, fat: 8, fiber: 0 },
    perishable: true,
  },
  eggs: {
    aliases: ['egg'],
    category: 'protein',
    group: 'dairy',
    defaultUnit: 'count',
    defaultQuantity: 12,
    serving: { quantity: 1, unit: 'egg' },
    nutrition: { calories: 72, protein: 6.3, carbs: 0.4, fat: 4.8, fiber: 0 },
    perishable: true,
  },
  yogurt: {
    aliases: ['greek yogurt'],
    category: 'dairy',
    group: 'dairy',
    defaultUnit: 'container',
    defaultQuantity: 1,
    serving: { quantity: 1, unit: 'container' },
    nutrition: { calories: 120, protein: 12, carbs: 9, fat: 4, fiber: 0 },
    perishable: true,
  },
  cheese: {
    aliases: ['cheddar cheese', 'mozzarella', 'swiss cheese'],
    category: 'dairy',
    group: 'dairy',
    defaultUnit: 'pack',
    defaultQuantity: 1,
    serving: { quantity: 1, unit: 'oz' },
    nutrition: { calories: 113, protein: 7, carbs: 0.4, fat: 9, fiber: 0 },
    perishable: true,
  },
  chicken: {
    aliases: ['chicken breast', 'chicken thighs', 'fried chicken'],
    category: 'protein',
    group: 'meat',
    defaultUnit: 'lb',
    defaultQuantity: 1,
    serving: { quantity: 4, unit: 'oz' },
    nutrition: { calories: 187, protein: 35, carbs: 0, fat: 4, fiber: 0 },
    perishable: true,
  },
  salmon: {
    aliases: ['fish', 'fillet'],
    category: 'protein',
    group: 'seafood',
    defaultUnit: 'lb',
    defaultQuantity: 1,
    serving: { quantity: 4, unit: 'oz' },
    nutrition: { calories: 233, protein: 25, carbs: 0, fat: 14, fiber: 0 },
    perishable: true,
  },
  beef: {
    aliases: ['ground beef', 'steak'],
    category: 'protein',
    group: 'meat',
    defaultUnit: 'lb',
    defaultQuantity: 1,
    serving: { quantity: 4, unit: 'oz' },
    nutrition: { calories: 287, protein: 23, carbs: 0, fat: 21, fiber: 0 },
    perishable: true,
  },
  tofu: {
    aliases: ['firm tofu'],
    category: 'protein',
    group: 'plant-protein',
    defaultUnit: 'block',
    defaultQuantity: 1,
    serving: { quantity: 3, unit: 'oz' },
    nutrition: { calories: 80, protein: 8, carbs: 2, fat: 4, fiber: 1 },
    perishable: true,
  },
  bread: {
    aliases: ['sliced bread', 'loaf'],
    category: 'grain',
    group: 'bakery',
    defaultUnit: 'loaf',
    defaultQuantity: 1,
    serving: { quantity: 1, unit: 'slice' },
    nutrition: { calories: 80, protein: 3, carbs: 15, fat: 1, fiber: 1 },
    perishable: true,
  },
  rice: {
    aliases: ['white rice', 'brown rice'],
    category: 'grain',
    group: 'pantry',
    defaultUnit: 'bag',
    defaultQuantity: 1,
    serving: { quantity: 0.25, unit: 'cup dry' },
    nutrition: { calories: 170, protein: 3, carbs: 37, fat: 1, fiber: 1 },
    perishable: false,
  },
  pasta: {
    aliases: ['spaghetti', 'noodles'],
    category: 'grain',
    group: 'pantry',
    defaultUnit: 'box',
    defaultQuantity: 1,
    serving: { quantity: 2, unit: 'oz dry' },
    nutrition: { calories: 200, protein: 7, carbs: 42, fat: 1, fiber: 2 },
    perishable: false,
  },
  beans: {
    aliases: ['black beans', 'kidney beans'],
    category: 'protein',
    group: 'plant-protein',
    defaultUnit: 'can',
    defaultQuantity: 1,
    serving: { quantity: 0.5, unit: 'cup' },
    nutrition: { calories: 110, protein: 7, carbs: 20, fat: 0.5, fiber: 7 },
    perishable: false,
  },
  cereal: {
    aliases: ['granola'],
    category: 'grain',
    group: 'pantry',
    defaultUnit: 'box',
    defaultQuantity: 1,
    serving: { quantity: 1, unit: 'cup' },
    nutrition: { calories: 160, protein: 4, carbs: 34, fat: 2, fiber: 3 },
    perishable: false,
  },
  chips: {
    aliases: ['potato chips', 'snack'],
    category: 'treat',
    group: 'snack',
    defaultUnit: 'bag',
    defaultQuantity: 1,
    serving: { quantity: 1, unit: 'oz' },
    nutrition: { calories: 150, protein: 2, carbs: 15, fat: 10, fiber: 1 },
    perishable: false,
  },
};

const LOCAL_RECIPES = [
  {
    id: 'spinach-egg-scramble',
    name: 'Spinach Egg Scramble',
    ingredients: ['eggs', 'spinach', 'cheese'],
    minutes: 12,
    healthGoal: 'protein + greens',
  },
  {
    id: 'chicken-rice-bowl',
    name: 'Chicken Rice Bowl',
    ingredients: ['chicken', 'rice', 'broccoli', 'carrots'],
    minutes: 25,
    healthGoal: 'balanced dinner',
  },
  {
    id: 'salmon-salad',
    name: 'Salmon Salad',
    ingredients: ['salmon', 'lettuce', 'tomatoes'],
    minutes: 18,
    healthGoal: 'omega-3 + vegetables',
  },
  {
    id: 'fruit-yogurt-bowl',
    name: 'Fruit Yogurt Bowl',
    ingredients: ['yogurt', 'blueberries', 'strawberries', 'bananas'],
    minutes: 5,
    healthGoal: 'quick breakfast',
  },
  {
    id: 'bean-pasta',
    name: 'Bean Pasta',
    ingredients: ['beans', 'pasta', 'tomatoes', 'cheese'],
    minutes: 20,
    healthGoal: 'pantry protein',
  },
  {
    id: 'toast-eggs-fruit',
    name: 'Toast, Eggs, and Fruit',
    ingredients: ['bread', 'eggs', 'apples'],
    minutes: 10,
    healthGoal: 'simple breakfast',
  },
];

const ML_OPPORTUNITIES = [
  {
    area: 'Meal photo recognition',
    dataToCollect: 'User-confirmed meal photos linked to inventory items.',
    model: 'Small Core ML image classifier with inventory-aware top-k filtering.',
    latencyTarget: '<100 ms for candidate ranking after image embedding on modern iPhone.',
    privacy: 'Train/export only from local confirmed labels unless user opts in.',
  },
  {
    area: 'Receipt OCR correction',
    dataToCollect: 'Raw OCR line, corrected item name, store context, parser confidence.',
    model: 'Lightweight text normalization / ranking model.',
    latencyTarget: '<20 ms per line on-device or local backend.',
    privacy: 'Receipt text can reveal household habits, so keep corrections local.',
  },
  {
    area: 'Restock prediction',
    dataToCollect: 'Purchase, consume, discard, and restock event timestamps.',
    model: 'Personal time-series or rules-first model with local online updates.',
    latencyTarget: '<10 ms during shopping-list generation.',
    privacy: 'No cloud training needed; household behavior stays local.',
  },
  {
    area: 'Waste-risk prediction',
    dataToCollect: 'Expiration outcomes, discard reasons, remaining quantity, price.',
    model: 'Small gradient boosted tree or logistic model exported to Core ML.',
    latencyTarget: '<10 ms for each inventory item.',
    privacy: 'Use transparent local features and explain why each item is risky.',
  },
];

function normalizeFoodName(name = '') {
  return String(name)
    .toLowerCase()
    .replace(/[^a-z0-9\s-]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function lookupFoodProfile(name = '') {
  const normalized = normalizeFoodName(name);
  if (!normalized) return null;

  if (FOOD_PROFILES[normalized]) {
    return { key: normalized, ...FOOD_PROFILES[normalized] };
  }

  for (const [key, profile] of Object.entries(FOOD_PROFILES)) {
    if (normalized.includes(key) || key.includes(normalized)) {
      return { key, ...profile };
    }
    if ((profile.aliases || []).some((alias) => normalized.includes(alias) || alias.includes(normalized))) {
      return { key, ...profile };
    }
  }

  return {
    key: normalized,
    aliases: [],
    category: 'unknown',
    group: 'unknown',
    defaultUnit: 'item',
    defaultQuantity: 1,
    serving: { quantity: 1, unit: 'serving' },
    nutrition: { calories: 0, protein: 0, carbs: 0, fat: 0, fiber: 0 },
    perishable: true,
  };
}

module.exports = {
  FOOD_PROFILES,
  LOCAL_RECIPES,
  ML_OPPORTUNITIES,
  normalizeFoodName,
  lookupFoodProfile,
};
