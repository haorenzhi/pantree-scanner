import { render, screen } from '@testing-library/react';
import App from './App';

beforeEach(() => {
  global.fetch = jest.fn(() => Promise.reject(new Error('bridge offline in unit test')));
});

afterEach(() => {
  jest.restoreAllMocks();
});

test('renders the Pantree shell with local data fallback', async () => {
  render(<App />);
  expect(screen.getByText(/Loading the data/i)).toBeInTheDocument();
  expect(await screen.findByText(/My Kitchen/i)).toBeInTheDocument();
  expect(await screen.findByText(/Phase 2 local intelligence is offline/i)).toBeInTheDocument();
});
