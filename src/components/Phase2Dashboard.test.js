import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import Phase2Dashboard from './Phase2Dashboard';

const summary = {
  privacy: {
    mode: 'local-only POC',
    note: 'No personal food, receipt, or meal data is sent to third-party services by Phase 2 routes.',
  },
  inventory: { active: 2, total: 3 },
  healthBalance: {
    score: 78,
    label: 'Estimated grocery balance, not medical nutrition advice.',
    produceShare: 0.5,
    proteinShare: 0.25,
    insights: ['Good produce coverage is available at home.'],
  },
  waste: {
    estimatedValueAtRisk: 4,
    message: 'About $4.00 of food may be at risk if not used soon.',
  },
  spending: {
    activeEstimatedValue: 12.5,
    purchasedValue: 18.6,
  },
  expiryRisks: [
    {
      id: '101',
      icon: '🥬',
      name: 'Spinach',
      reason: 'Expiring soon — good candidate for the next meal.',
      daysUntilExpiration: 2,
      expiryRisk: 76,
      estimatedValueAtRisk: 4,
    },
  ],
  shoppingSuggestions: [
    {
      name: 'Eggs',
      reason: 'Current inventory is low.',
      source: 'remaining-quantity',
      priority: 'high',
    },
  ],
  mealIdeas: [
    {
      id: 'spinach-egg-scramble',
      name: 'Spinach Egg Scramble',
      matchScore: 67,
      minutes: 12,
      healthGoal: 'protein + greens',
      matched: ['eggs', 'spinach'],
      missing: ['cheese'],
    },
  ],
  mlReadiness: {
    privacyMode: 'local-first; no cloud training in this POC',
    opportunities: [
      {
        area: 'Meal photo recognition',
        model: 'Small Core ML image classifier with inventory-aware top-k filtering.',
        latencyTarget: '<100 ms for candidate ranking after image embedding on modern iPhone.',
      },
    ],
  },
};

beforeEach(() => {
  global.fetch = jest.fn();
});

afterEach(() => {
  jest.restoreAllMocks();
});

test('renders local-only Phase 2 summary panels', async () => {
  global.fetch.mockResolvedValueOnce({ ok: true, json: async () => summary });

  render(<Phase2Dashboard />);

  expect(screen.getByText(/Loading local Phase 2 intelligence/i)).toBeInTheDocument();
  expect(await screen.findByText('Local Food Intelligence')).toBeInTheDocument();
  expect(screen.getByText('local-only POC')).toBeInTheDocument();
  expect(screen.getByText('2')).toBeInTheDocument();
  expect(screen.getByText('78/100')).toBeInTheDocument();
  expect(screen.getByText('$4.00')).toBeInTheDocument();
  expect(screen.getByText(/Spinach Egg Scramble/i)).toBeInTheDocument();
  expect(screen.getByText(/Meal photo recognition/i)).toBeInTheDocument();
});

test('renders offline state when bridge summary cannot be loaded', async () => {
  global.fetch.mockRejectedValueOnce(new Error('offline'));

  render(<Phase2Dashboard />);

  expect(await screen.findByText(/Phase 2 local intelligence is offline/i)).toBeInTheDocument();
  expect(screen.getByText(/Start the bridge server on port 4000/i)).toBeInTheDocument();
});

test('posts local consume event and refreshes summary after Ate click', async () => {
  const refreshed = {
    ...summary,
    expiryRisks: [],
    inventory: { active: 1, total: 3 },
  };
  const dispatchSpy = jest.spyOn(window, 'dispatchEvent');

  global.fetch
    .mockResolvedValueOnce({ ok: true, json: async () => summary })
    .mockResolvedValueOnce({ ok: true, json: async () => ({ event: { type: 'consume' }, food: {} }) })
    .mockResolvedValueOnce({ ok: true, json: async () => refreshed });

  render(<Phase2Dashboard />);

  expect(await screen.findByText('Local Food Intelligence')).toBeInTheDocument();
  fireEvent.click(screen.getByText('Ate'));

  await waitFor(() => {
    expect(global.fetch).toHaveBeenCalledWith(
      'http://localhost:4000/api/phase2/events',
      expect.objectContaining({
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ foodId: '101', type: 'consume' }),
      }),
    );
  });

  expect(await screen.findByText(/Marked as consumed locally/i)).toBeInTheDocument();
  expect(dispatchSpy).toHaveBeenCalledWith(expect.objectContaining({ type: 'pantree-storage' }));
  await waitFor(() => expect(global.fetch).toHaveBeenCalledTimes(3));
});

test('shows event failure without hiding existing insights', async () => {
  global.fetch
    .mockResolvedValueOnce({ ok: true, json: async () => summary })
    .mockResolvedValueOnce({ ok: false, json: async () => ({ error: 'missing food' }) });

  render(<Phase2Dashboard />);

  expect(await screen.findByText('Local Food Intelligence')).toBeInTheDocument();
  fireEvent.click(screen.getByText('Discard'));

  expect(await screen.findByText(/Could not save event: missing food/i)).toBeInTheDocument();
  expect(screen.getByText(/Spinach Egg Scramble/i)).toBeInTheDocument();
});
