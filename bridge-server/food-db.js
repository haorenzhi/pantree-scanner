/**
 * Food database — expiry days, storage sections, and emoji mappings.
 */

// { days, section } for each item
// section: "fridge" (perishable), "freezer" (meats/seafood), "shelf" (pantry staples)
const FOOD_DB = {
  // Fruits — fridge
  apples:      { days: 21, section: 'fridge' },
  bananas:     { days: 7,  section: 'fridge' },
  blueberries: { days: 7,  section: 'fridge' },
  strawberries:{ days: 5,  section: 'fridge' },
  raspberries: { days: 3,  section: 'fridge' },
  grapes:      { days: 7,  section: 'fridge' },
  cherries:    { days: 7,  section: 'fridge' },
  lemon:       { days: 21, section: 'fridge' },
  lime:        { days: 21, section: 'fridge' },
  oranges:     { days: 14, section: 'fridge' },
  orange:      { days: 14, section: 'fridge' },
  grapefruit:  { days: 21, section: 'fridge' },
  pears:       { days: 5,  section: 'fridge' },
  peaches:     { days: 5,  section: 'fridge' },
  nectarines:  { days: 5,  section: 'fridge' },
  plums:       { days: 5,  section: 'fridge' },
  kiwi:        { days: 7,  section: 'fridge' },
  melons:      { days: 5,  section: 'fridge' },
  watermelon:  { days: 7,  section: 'fridge' },
  pineapple:   { days: 5,  section: 'fridge' },
  mangos:      { days: 7,  section: 'fridge' },
  papaya:      { days: 7,  section: 'fridge' },
  avocados:    { days: 5,  section: 'fridge' },
  coconut:     { days: 7,  section: 'fridge' },

  // Vegetables — fridge
  broccoli:    { days: 7,  section: 'fridge' },
  cauliflower: { days: 7,  section: 'fridge' },
  carrots:     { days: 21, section: 'fridge' },
  celery:      { days: 14, section: 'fridge' },
  corn:        { days: 5,  section: 'fridge' },
  cucumbers:   { days: 7,  section: 'fridge' },
  eggplant:    { days: 5,  section: 'fridge' },
  lettuce:     { days: 5,  section: 'fridge' },
  romaine:     { days: 5,  section: 'fridge' },
  spinach:     { days: 5,  section: 'fridge' },
  kale:        { days: 5,  section: 'fridge' },
  arugula:     { days: 3,  section: 'fridge' },
  cabbage:     { days: 14, section: 'fridge' },
  tomatoes:    { days: 7,  section: 'fridge' },
  peppers:     { days: 7,  section: 'fridge' },
  mushrooms:   { days: 7,  section: 'fridge' },
  onions:      { days: 30, section: 'fridge' },
  garlic:      { days: 14, section: 'fridge' },
  ginger:      { days: 14, section: 'fridge' },
  potatoes:    { days: 21, section: 'fridge' },
  'sweet potato': { days: 14, section: 'fridge' },
  squash:      { days: 14, section: 'fridge' },
  zucchini:    { days: 5,  section: 'fridge' },
  asparagus:   { days: 4,  section: 'fridge' },
  'bok choy':  { days: 4,  section: 'fridge' },
  'brussel sprouts': { days: 5, section: 'fridge' },
  'green beans': { days: 5, section: 'fridge' },
  artichokes:  { days: 7,  section: 'fridge' },
  beets:       { days: 14, section: 'fridge' },
  okra:        { days: 3,  section: 'fridge' },
  radishes:    { days: 12, section: 'fridge' },
  cilantro:    { days: 5,  section: 'fridge' },
  chives:      { days: 5,  section: 'fridge' },

  // Meat — freezer
  chicken:       { days: 270, section: 'freezer' },
  turkey:        { days: 270, section: 'freezer' },
  'ground turkey': { days: 120, section: 'freezer' },
  'fried chicken': { days: 4,  section: 'fridge' },
  steak:         { days: 180, section: 'freezer' },
  'ground beef': { days: 120, section: 'freezer' },
  pork:          { days: 180, section: 'freezer' },
  'ground pork': { days: 120, section: 'freezer' },
  'lamb chop':   { days: 180, section: 'freezer' },
  bacon:         { days: 14,  section: 'fridge' },
  sausage:       { days: 14,  section: 'fridge' },
  ham:           { days: 7,   section: 'fridge' },
  deli:          { days: 5,   section: 'fridge' },

  // Seafood — freezer
  salmon:    { days: 180, section: 'freezer' },
  tilapia:   { days: 180, section: 'freezer' },
  bass:      { days: 90,  section: 'freezer' },
  shrimp:    { days: 150, section: 'freezer' },
  shellfish: { days: 90,  section: 'freezer' },
  scallops:  { days: 150, section: 'freezer' },
  squid:     { days: 180, section: 'freezer' },
  lobster:   { days: 180, section: 'freezer' },
  crab:      { days: 180, section: 'freezer' },
  mussels:   { days: 90,  section: 'freezer' },
  oysters:   { days: 90,  section: 'freezer' },

  // Dairy — fridge
  milk:           { days: 7,  section: 'fridge' },
  'almond milk':  { days: 7,  section: 'fridge' },
  'oat milk':     { days: 7,  section: 'fridge' },
  eggs:           { days: 35, section: 'fridge' },
  butter:         { days: 60, section: 'fridge' },
  cheese:         { days: 21, section: 'fridge' },
  'cream cheese': { days: 30, section: 'fridge' },
  'cottage cheese': { days: 7, section: 'fridge' },
  'ricotta cheese': { days: 7, section: 'fridge' },
  yogurt:         { days: 14, section: 'fridge' },
  'sour cream':   { days: 21, section: 'fridge' },
  'heavy cream':  { days: 14, section: 'fridge' },
  cream:          { days: 14, section: 'fridge' },
  'half-and-half': { days: 7, section: 'fridge' },

  // Drinks — fridge
  juice:          { days: 7,  section: 'fridge' },
  'orange juice': { days: 7,  section: 'fridge' },
  'apple juice':  { days: 7,  section: 'fridge' },
  'mango juice':  { days: 7,  section: 'fridge' },

  // Prepared / deli — fridge
  tofu:       { days: 14, section: 'fridge' },
  tempeh:     { days: 14, section: 'fridge' },
  miso:       { days: 90, section: 'fridge' },
  guacamole:  { days: 4,  section: 'fridge' },
  hummus:     { days: 7,  section: 'fridge' },
  sandwich:   { days: 3,  section: 'fridge' },
  burrito:    { days: 3,  section: 'fridge' },
  cheesecake: { days: 5,  section: 'fridge' },
  salsa:      { days: 14, section: 'fridge' },

  // Bread / bakery — shelf
  bread:     { days: 5,  section: 'shelf' },
  bagels:    { days: 5,  section: 'shelf' },
  tortillas: { days: 14, section: 'shelf' },
  pancakes:  { days: 4,  section: 'fridge' },
  waffles:   { days: 4,  section: 'fridge' },

  // Pantry staples — shelf
  rice:       { days: 365, section: 'shelf' },
  pasta:      { days: 365, section: 'shelf' },
  beans:      { days: 365, section: 'shelf' },
  cereal:     { days: 180, section: 'shelf' },
  flour:      { days: 365, section: 'shelf' },
  sugar:      { days: 730, section: 'shelf' },
  coffee:     { days: 30,  section: 'shelf' },

  // Condiments / sauces — shelf (until opened)
  ketchup:           { days: 180, section: 'shelf' },
  mustard:           { days: 365, section: 'shelf' },
  mayonnaise:        { days: 60,  section: 'fridge' },
  'soy sauce':       { days: 365, section: 'shelf' },
  vinegar:           { days: 730, section: 'shelf' },
  'olive oil':       { days: 180, section: 'shelf' },
  'maple syrup':     { days: 365, section: 'shelf' },
  'chocolate syrup': { days: 365, section: 'shelf' },
  honey:             { days: 730, section: 'shelf' },
  'peanut butter':   { days: 90,  section: 'shelf' },
  jam:               { days: 180, section: 'shelf' },
};

const FOOD_EMOJIS = {
  apples: '🍎', apple: '🍎', bananas: '🍌', banana: '🍌',
  blueberries: '🫐', strawberries: '🍓', grapes: '🍇',
  raspberries: '🍓', peaches: '🍑', pears: '🍐',
  lemon: '🍋', lime: '🍋', melons: '🍈', kiwi: '🥝',
  avocados: '🥑', avocado: '🥑', mangos: '🥭', mango: '🥭',
  papaya: '🥭', nectarines: '🍑', cherries: '🍒',
  broccoli: '🥦', carrots: '🥕', corn: '🌽',
  lettuce: '🥬', spinach: '🥬', tomatoes: '🍅', tomato: '🍅',
  potatoes: '🥔', potato: '🥔', onions: '🧅', onion: '🧅',
  garlic: '🧄', peppers: '🌶️', mushrooms: '🍄',
  cucumbers: '🥒', eggplant: '🍆', cauliflower: '🥦',
  celery: '🥬', asparagus: '🥬', squash: '🥒',
  'bok choy': '🥬', 'brussel sprouts': '🥬', okra: '🥬',
  radishes: '🥬', beets: '🥬', artichokes: '🥬',
  chicken: '🍗', 'fried chicken': '🍗', turkey: '🦃',
  beef: '🥩', steak: '🥩', 'ground beef': '🥩', bacon: '🥓',
  pork: '🥩', 'ground pork': '🥩', 'ground turkey': '🥩',
  lamb: '🥩', ham: '🍖', sausage: '🌭', 'lamb chop': '🥩',
  salmon: '🐟', tilapia: '🐟', bass: '🐟', tuna: '🐟', cod: '🐟', trout: '🐟',
  shrimp: '🦐', lobster: '🦞', crab: '🦀',
  scallops: '🐚', squid: '🦑', mussels: '🐚',
  oysters: '🦪', shellfish: '🐚', clams: '🐚',
  milk: '🥛', eggs: '🥚', egg: '🥚', butter: '🧈',
  cheese: '🧀', 'cream cheese': '🧀', 'cottage cheese': '🧀',
  'ricotta cheese': '🧀', yogurt: '🥛', 'sour cream': '🥛',
  'heavy cream': '🥛', 'half-and-half': '🥛',
  bread: '🍞', bagels: '🥯', pancakes: '🥞', waffles: '🧇',
  rice: '🍚', beans: '🫘', cereal: '🥣', coffee: '☕',
  juice: '🧃', 'orange juice': '🍊', 'apple juice': '🧃',
  'mango juice': '🧃',
  ketchup: '🍅', mustard: '🟡', mayonnaise: '🥫',
  salsa: '🫙', 'soy sauce': '🫙', vinegar: '🫙',
  'olive oil': '🫒', 'maple syrup': '🍁', 'chocolate syrup': '🍫',
  tofu: '🥡', tempeh: '🥡', miso: '🥣',
  guacamole: '🥑', sandwich: '🥪', burrito: '🌯',
  cheesecake: '🍰',
  cilantro: '🌿', chives: '🌿', ginger: '🫚',
  grapefruit: '🍊', oranges: '🍊', orange: '🍊', watermelon: '🍉',
  pineapple: '🍍', coconut: '🥥', plums: '🍑',
  romaine: '🥬', kale: '🥬', arugula: '🥬', cabbage: '🥬',
  'sweet potato': '🍠', zucchini: '🥒', 'green beans': '🫘',
  hummus: '🫙', tortillas: '🫓', pasta: '🍝', flour: '🌾',
  sugar: '🍬', honey: '🍯', 'peanut butter': '🥜', jam: '🫙',
  'almond milk': '🥛', 'oat milk': '🥛', cream: '🥛', deli: '🥩',
  // Additional common items
  mushroom: '🍄', pepper: '🌶️', cucumber: '🥒',
  strawberry: '🍓', blueberry: '🫐', raspberry: '🍓',
  grape: '🍇', cherry: '🍒', peach: '🍑', pear: '🍐',
  carrot: '🥕', celery: '🥬', broccoli: '🥦',
  melon: '🍈', nectarine: '🍑', plum: '🍑',
  'ice cream': '🍦', chocolate: '🍫', cookie: '🍪', cookies: '🍪',
  cake: '🍰', pie: '🥧', donut: '🍩', muffin: '🧁',
  pizza: '🍕', soup: '🥣', noodles: '🍜', sushi: '🍣',
  taco: '🌮', 'hot dog': '🌭', popcorn: '🍿',
  water: '💧', tea: '🍵', beer: '🍺', wine: '🍷',
  lemonade: '🍋', smoothie: '🥤', soda: '🥤',
};

function resolveEmoji(name) {
  const lower = name.toLowerCase();
  if (FOOD_EMOJIS[lower]) return FOOD_EMOJIS[lower];
  for (const [key, emoji] of Object.entries(FOOD_EMOJIS)) {
    if (lower.includes(key) || key.includes(lower)) return emoji;
  }
  return '🍽️';
}

function lookupExpiry(name) {
  const lower = name.toLowerCase();
  if (FOOD_DB[lower]) return FOOD_DB[lower].days;
  for (const [key, entry] of Object.entries(FOOD_DB)) {
    if (lower.includes(key) || key.includes(lower)) return entry.days;
  }
  return 7;
}

function lookupSection(name) {
  const lower = name.toLowerCase();
  if (FOOD_DB[lower]) return FOOD_DB[lower].section;
  for (const [key, entry] of Object.entries(FOOD_DB)) {
    if (lower.includes(key) || key.includes(lower)) return entry.section;
  }
  return 'fridge';
}

module.exports = { FOOD_DB, FOOD_EMOJIS, resolveEmoji, lookupExpiry, lookupSection };
