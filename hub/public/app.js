/**
 * Hub Dashboard Client App - Phase 20.5
 * Fetch API data + listen to SSE events for live updates
 */

class HubDashboard {
  constructor() {
    this.eventSource = null;
    this.refreshInterval = null;
    this.config = {
      refreshIntervalMs: 30000,
      sseEndpoint: '/events',
      apiEndpoints: {
        mcpHealth: '/api/mcp_health',
        telemetry: '/api/telemetry',
      },
    };
  }

  /**
   * Initialize dashboard
   */
  init() {
    console.log('[Dashboard] Initializing...');

    // Initial data fetch
    this.fetchAllData();

    // Setup SSE connection
    this.connectSSE();

    // Setup periodic refresh
    this.refreshInterval = setInterval(() => {
      this.fetchAllData();
    }, this.config.refreshIntervalMs);

    console.log('[Dashboard] Ready');
  }

  /**
   * Fetch all API data
   */
  async fetchAllData() {
    try {
      await Promise.all([
        this.fetchMCPHealth(),
        this.fetchTelemetry(),
      ]);

      this.updateLastUpdate();
    } catch (err) {
      console.error('[Dashboard] Failed to fetch data:', err);
    }
  }

  /**
   * Fetch MCP Health data
   */
  async fetchMCPHealth() {
    try {
      const res = await fetch(this.config.apiEndpoints.mcpHealth);
      const data = await res.json();

      if (data.error) {
        this.updateMCPHealth({ status: 'unavailable' });
        return;
      }

      this.updateMCPHealth(data);
    } catch (err) {
      console.error('[Dashboard] Failed to fetch MCP health:', err);
      this.updateMCPHealth({ status: 'error' });
    }
  }

  /**
   * Fetch Telemetry data
   */
  async fetchTelemetry() {
    try {
      const res = await fetch(this.config.apiEndpoints.telemetry);
      const data = await res.json();

      if (data.error) {
        this.updateTelemetry({ errors: 0, warnings: 0, events: 0 });
        return;
      }

      this.updateTelemetry(data);
    } catch (err) {
      console.error('[Dashboard] Failed to fetch telemetry:', err);
      this.updateTelemetry({ errors: 0, warnings: 0, events: 0 });
    }
  }

  /**
   * Update MCP Health tile
   */
  updateMCPHealth(data) {
    const status = data.status || 'unknown';
    const latency = data.latency_ms ? `${data.latency_ms}ms` : '-';
    const services = data.services_up || '-';
    const lastCheck = data.last_check ? this.formatTime(data.last_check) : '-';

    document.getElementById('mcp-overall-status').textContent = status;
    document.getElementById('mcp-latency').textContent = latency;
    document.getElementById('mcp-services').textContent = services;
    document.getElementById('mcp-last-check').textContent = lastCheck;

    const statusEl = document.getElementById('mcp-status');
    statusEl.textContent = status === 'up' ? 'Healthy' : 'Down';
    statusEl.className = 'tile-status ' + (status === 'up' ? 'success' : 'error');
  }

  /**
   * Update Telemetry tile
   */
  updateTelemetry(data) {
    const errors = data.errors || 0;
    const warnings = data.warnings || 0;
    const events = data.total_events || 0;

    document.getElementById('telemetry-errors').textContent = errors;
    document.getElementById('telemetry-warnings').textContent = warnings;
    document.getElementById('telemetry-events').textContent = events;

    const statusEl = document.getElementById('telemetry-status');
    if (errors > 0) {
      statusEl.textContent = 'Errors Detected';
      statusEl.className = 'tile-status error';
    } else if (warnings > 0) {
      statusEl.textContent = 'Warnings';
      statusEl.className = 'tile-status warning';
    } else {
      statusEl.textContent = 'Healthy';
      statusEl.className = 'tile-status success';
    }
  }

  /**
   * Add PR event to monitor
   */
  addPREvent(event) {
    const eventList = document.getElementById('pr-events');

    // Create event item
    const item = document.createElement('div');
    item.className = 'event-item';

    const time = document.createElement('span');
    time.className = 'event-time';
    time.textContent = this.formatTime(event.timestamp);

    const message = document.createElement('span');
    message.className = 'event-message';
    message.textContent = this.formatEventMessage(event);

    item.appendChild(time);
    item.appendChild(message);

    // Add to top
    if (eventList.firstChild) {
      eventList.insertBefore(item, eventList.firstChild);
    } else {
      eventList.appendChild(item);
    }

    // Keep max 10 events
    while (eventList.children.length > 10) {
      eventList.removeChild(eventList.lastChild);
    }
  }

  /**
   * Format event message
   */
  formatEventMessage(event) {
    const data = event.data;
    const type = data.type || 'unknown';

    if (type.startsWith('pr.')) {
      return `PR #${data.pr || '?'}: ${type.replace('pr.', '')}`;
    }

    if (type.startsWith('ci.')) {
      return `CI: ${type.replace('ci.', '')}`;
    }

    return `${event.channel}: ${type}`;
  }

  /**
   * Connect to SSE endpoint
   */
  connectSSE() {
    console.log('[Dashboard] Connecting to SSE...');

    this.eventSource = new EventSource(this.config.sseEndpoint);

    this.eventSource.onopen = () => {
      console.log('[Dashboard] SSE connected');
      this.updateConnectionStatus(true);
    };

    this.eventSource.onerror = (err) => {
      console.error('[Dashboard] SSE error:', err);
      this.updateConnectionStatus(false);
    };

    // Listen for all channel events
    ['hub:alerts', 'ci:events', 'mcp:health', 'system'].forEach((channel) => {
      this.eventSource.addEventListener(channel, (e) => {
        try {
          const event = JSON.parse(e.data);
          this.handleSSEEvent(event);
        } catch (err) {
          console.error('[Dashboard] Failed to parse SSE event:', err);
        }
      });
    });
  }

  /**
   * Handle SSE event
   */
  handleSSEEvent(event) {
    console.log('[Dashboard] SSE event:', event);

    const { channel, data } = event;

    // Update tiles based on channel
    if (channel === 'mcp:health') {
      this.updateMCPHealth(data);
    } else if (channel === 'ci:events' || channel === 'hub:alerts') {
      this.addPREvent(event);
    }

    this.updateLastUpdate();
  }

  /**
   * Update connection status indicator
   */
  updateConnectionStatus(connected) {
    const statusEl = document.getElementById('connection-status');
    statusEl.textContent = connected ? 'Connected' : 'Disconnected';
    statusEl.className = 'status-indicator ' + (connected ? 'online' : 'offline');
  }

  /**
   * Update last update timestamp
   */
  updateLastUpdate() {
    const now = new Date().toLocaleTimeString();
    document.getElementById('last-update').textContent = `Last update: ${now}`;
  }

  /**
   * Format timestamp
   */
  formatTime(timestamp) {
    try {
      const date = new Date(timestamp);
      return date.toLocaleTimeString();
    } catch {
      return timestamp;
    }
  }

  /**
   * Cleanup
   */
  destroy() {
    if (this.eventSource) {
      this.eventSource.close();
    }
    if (this.refreshInterval) {
      clearInterval(this.refreshInterval);
    }
  }
}

// Initialize dashboard on load
let dashboard = null;

window.addEventListener('DOMContentLoaded', () => {
  dashboard = new HubDashboard();
  dashboard.init();
});

window.addEventListener('beforeunload', () => {
  if (dashboard) {
    dashboard.destroy();
  }
});
