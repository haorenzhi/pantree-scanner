import React, { useEffect, useState } from 'react';
import './Phase2Dashboard.css';

const BRIDGE_URL = `${window.location.protocol}//${window.location.hostname}:4000`;

const money = (value) => {
  if (value === null || value === undefined || Number.isNaN(Number(value))) return '—';
  return `$${Number(value).toFixed(2)}`;
};

const percent = (value) => `${Math.round((Number(value) || 0) * 100)}%`;

const Phase2Dashboard = () => {
  const [summary, setSummary] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [actionMessage, setActionMessage] = useState('');
  const [refreshKey, setRefreshKey] = useState(0);

  useEffect(() => {
    let active = true;

    const loadSummary = async () => {
      try {
        const response = await fetch(`${BRIDGE_URL}/api/phase2/summary`);
        if (!response.ok) throw new Error(`Bridge returned ${response.status}`);
        const nextSummary = await response.json();
        if (active) {
          setSummary(nextSummary);
          setError(null);
        }
      } catch (err) {
        if (active) setError(err.message);
      } finally {
        if (active) setLoading(false);
      }
    };

    loadSummary();
    return () => {
      active = false;
    };
  }, [refreshKey]);

  const postEvent = async (foodId, type, reason) => {
    setActionMessage('Saving local event...');
    try {
      const response = await fetch(`${BRIDGE_URL}/api/phase2/events`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ foodId, type, reason }),
      });
      const payload = await response.json();
      if (!response.ok) throw new Error(payload.error || 'Event failed');
      setActionMessage(type === 'consume' ? 'Marked as consumed locally.' : 'Marked as discarded locally.');
      window.dispatchEvent(new Event('pantree-storage'));
      setRefreshKey((key) => key + 1);
    } catch (err) {
      setActionMessage(`Could not save event: ${err.message}`);
    }
  };

  if (loading) {
    return <section className="phase2-dashboard phase2-muted">Loading local Phase 2 intelligence...</section>;
  }

  if (error) {
    return (
      <section className="phase2-dashboard phase2-muted">
        <strong>Phase 2 local intelligence is offline.</strong>
        <p>Start the bridge server on port 4000 to enable local-only analytics.</p>
      </section>
    );
  }

  if (!summary) return null;

  const inventory = summary.inventory || {};
  const health = summary.healthBalance || {};
  const waste = summary.waste || {};
  const spending = summary.spending || {};
  const risks = summary.expiryRisks || [];
  const shopping = summary.shoppingSuggestions || [];
  const meals = summary.mealIdeas || [];
  const ml = summary.mlReadiness || {};

  return (
    <section className="phase2-dashboard">
      <div className="phase2-header">
        <div>
          <p className="phase2-eyebrow">Phase 2 POC</p>
          <h2>Local Food Intelligence</h2>
          <p>{summary.privacy?.note}</p>
        </div>
        <div className="phase2-privacy-badge">
          <span>🔒</span>
          <strong>{summary.privacy?.mode}</strong>
          <small>No external APIs</small>
        </div>
      </div>

      <div className="phase2-grid phase2-metrics">
        <MetricCard label="Active foods" value={inventory.active || 0} detail={`${inventory.total || 0} total items`} />
        <MetricCard label="Health balance" value={`${health.score || 0}/100`} detail={health.label} />
        <MetricCard label="Value at risk" value={money(waste.estimatedValueAtRisk)} detail={waste.message} />
        <MetricCard label="Inventory value" value={money(spending.activeEstimatedValue)} detail={`${money(spending.purchasedValue)} purchased`} />
      </div>

      <div className="phase2-grid">
        <Panel title="Healthier inventory signals" subtitle={`Produce ${percent(health.produceShare)} · Protein ${percent(health.proteinShare)}`}>
          <ul className="phase2-list">
            {(health.insights || []).map((insight) => <li key={insight}>{insight}</li>)}
          </ul>
        </Panel>

        <Panel title="Eat first / waste risk" subtitle="Transparent rule-based ranking">
          {risks.length === 0 ? (
            <p className="phase2-empty">No urgent food risk detected.</p>
          ) : (
            <div className="phase2-risk-list">
              {risks.slice(0, 4).map((item) => (
                <div className="phase2-risk-item" key={item.id}>
                  <div>
                    <strong>{item.icon} {item.name}</strong>
                    <p>{item.reason}</p>
                    <small>{item.daysUntilExpiration} day(s) left · risk {item.expiryRisk}/100 · {money(item.estimatedValueAtRisk)} at risk</small>
                  </div>
                  <div className="phase2-actions">
                    <button onClick={() => postEvent(item.id, 'consume')}>Ate</button>
                    <button className="danger" onClick={() => postEvent(item.id, 'discard', 'expired-or-spoiled')}>Discard</button>
                  </div>
                </div>
              ))}
            </div>
          )}
          {actionMessage ? <p className="phase2-action-message">{actionMessage}</p> : null}
        </Panel>

        <Panel title="Smart shopping suggestions" subtitle="Generated from local inventory and event history">
          {shopping.length === 0 ? (
            <p className="phase2-empty">No shopping suggestion yet. Consume or scan more items to build local history.</p>
          ) : (
            <ul className="phase2-list">
              {shopping.map((item) => (
                <li key={`${item.name}-${item.source}`}>
                  <strong>{item.name}</strong> — {item.reason} <span className="phase2-pill">{item.priority}</span>
                </li>
              ))}
            </ul>
          )}
        </Panel>

        <Panel title="Meal ideas from what you have" subtitle="Static local recipes for proof of concept">
          {meals.length === 0 ? (
            <p className="phase2-empty">Add a few foods to unlock local meal matching.</p>
          ) : (
            <div className="phase2-meals">
              {meals.map((meal) => (
                <div className="phase2-meal" key={meal.id}>
                  <strong>{meal.name}</strong>
                  <small>{meal.matchScore}% match · {meal.minutes} min · {meal.healthGoal}</small>
                  <p>Have: {meal.matched.join(', ') || 'none'}</p>
                  {meal.missing.length ? <p>Missing: {meal.missing.join(', ')}</p> : <p>Ready to cook.</p>}
                </div>
              ))}
            </div>
          )}
        </Panel>
      </div>

      <Panel title="Where machine learning would help later" subtitle={ml.privacyMode} wide>
        <div className="phase2-ml-grid">
          {(ml.opportunities || []).map((item) => (
            <div className="phase2-ml-card" key={item.area}>
              <strong>{item.area}</strong>
              <p>{item.model}</p>
              <small>{item.latencyTarget}</small>
            </div>
          ))}
        </div>
      </Panel>
    </section>
  );
};

const MetricCard = ({ label, value, detail }) => (
  <div className="phase2-metric-card">
    <span>{label}</span>
    <strong>{value}</strong>
    <small>{detail}</small>
  </div>
);

const Panel = ({ title, subtitle, children, wide }) => (
  <article className={wide ? 'phase2-panel phase2-panel-wide' : 'phase2-panel'}>
    <div className="phase2-panel-title">
      <h3>{title}</h3>
      <p>{subtitle}</p>
    </div>
    {children}
  </article>
);

export default Phase2Dashboard;
