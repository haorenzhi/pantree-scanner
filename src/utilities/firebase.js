import { useState, useEffect, useCallback, useRef } from 'react';

const STORAGE_KEY = 'pantree-foods';
const STORAGE_EVENT = 'pantree-storage';
const BRIDGE_URL = process.env.REACT_APP_BRIDGE_URL || 'http://localhost:3001';
const POLL_INTERVAL = 2000; // ms

const localUser = { uid: 'local', email: 'local user' };

// --- Bridge API helpers ---

let bridgeAvailable = null; // null = unknown, true/false after first check

async function checkBridge() {
  try {
    const res = await fetch(`${BRIDGE_URL}/api/health`, { method: 'GET' });
    bridgeAvailable = res.ok;
  } catch {
    bridgeAvailable = false;
  }
  return bridgeAvailable;
}

async function fetchFoods() {
  try {
    const res = await fetch(`${BRIDGE_URL}/api/foods`);
    if (res.ok) return await res.json();
  } catch { /* bridge unavailable */ }
  return null;
}

async function postFood(food) {
  try {
    const res = await fetch(`${BRIDGE_URL}/api/foods`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ foods: [food] }),
    });
    return res.ok;
  } catch { return false; }
}

async function deleteFood(id) {
  try {
    const res = await fetch(`${BRIDGE_URL}/api/foods/${id}`, { method: 'DELETE' });
    return res.ok;
  } catch { return false; }
}

// --- localStorage fallback ---

const readFoods = () => {
  try {
    return JSON.parse(localStorage.getItem(STORAGE_KEY)) || {};
  } catch {
    return {};
  }
};

const writeFoods = (foods) => {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(foods));
  window.dispatchEvent(new Event(STORAGE_EVENT));
};

// --- Public API (same interface as before) ---

export const useData = (path, transform) => {
  const [data, setDataState] = useState();
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState();
  const lastSnapshotRef = useRef('');

  const load = useCallback(async () => {
    try {
      // On first call, detect bridge availability
      if (bridgeAvailable === null) await checkBridge();

      let foods;
      if (bridgeAvailable) {
        foods = await fetchFoods();
        if (foods !== null) {
          // Sync to localStorage as cache (without dispatching event
          // to avoid re-triggering this load in a loop)
          localStorage.setItem(STORAGE_KEY, JSON.stringify(foods));
        } else {
          foods = readFoods();
        }
      } else {
        foods = readFoods();
      }

      // Only update state if data actually changed
      const snapshot = JSON.stringify(foods);
      if (snapshot === lastSnapshotRef.current) return;
      lastSnapshotRef.current = snapshot;

      const val = { foods };
      setDataState(transform ? transform(val) : val);
      setLoading(false);
      setError(null);
    } catch (e) {
      setDataState(null);
      setLoading(false);
      setError(e);
    }
  }, [transform]);

  useEffect(() => {
    load();

    // Listen for local storage events (from setData calls)
    window.addEventListener(STORAGE_EVENT, load);

    // Poll the bridge server for changes (e.g., from the receipt scanner)
    let pollTimer = null;
    if (bridgeAvailable !== false) {
      pollTimer = setInterval(load, POLL_INTERVAL);
    }

    return () => {
      window.removeEventListener(STORAGE_EVENT, load);
      if (pollTimer) clearInterval(pollTimer);
    };
  }, [path, load]);

  return [data, loading, error];
};

export const setData = async (path, value) => {
  const parts = path.split('/').filter(Boolean);
  const foodId = parts[parts.length - 1];

  if (value === null) {
    // Delete
    if (bridgeAvailable) {
      await deleteFood(foodId);
    }
    const foods = readFoods();
    delete foods[foodId];
    writeFoods(foods);
  } else {
    // Add / update
    if (bridgeAvailable) {
      await postFood(value);
    }
    const foods = readFoods();
    foods[foodId] = value;
    writeFoods(foods);
  }
};

export const deleteFromFirebase = async (foodie, user) => {
  if (foodie) {
    try {
      await setData(`users/${user.uid}/foods/${foodie.id}/`, null);
    } catch (error) {
      alert(error);
    }
  }
};

export const pushToFirebase = async (foodie, user) => {
  if (foodie) {
    try {
      await setData(`users/${user.uid}/foods/${foodie.id}/`, foodie);
    } catch (error) {
      alert(error);
    }
  }
};

export const useUserState = () => {
  const [user] = useState(localUser);
  return user;
};

export const signInWithG = () => {};

export const signOutOfG = () => {};
