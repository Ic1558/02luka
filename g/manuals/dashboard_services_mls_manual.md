# Dashboard Services & MLS Panels

The dashboard now exposes two read-only observability views that consume the existing backend APIs:

## Services Panel

* **Source:** `GET /api/services`
* **Data shown:** label, status, PID, exit code, LaunchAgent type.
* **Summary metrics:** total, running, stopped, failed counts (color-coded chips).
* **Filters:**
  * Status (`All`, `running`, `stopped`, `failed`) mapped directly to the backend `status` query parameter.
  * Type filter (bridge, worker, automation, monitoring, other) is applied client-side for quick pivots without additional API calls.
* **Refresh cadence:** auto-refreshes every 30 seconds, with a manual **Refresh** button.
* **Error handling:** failures render an inline banner with a retry action so the rest of the dashboard stays usable.

Use this view to confirm LaunchAgents are healthy during deploys or when triaging WO escalations. Service rows are read-only and mirror the LaunchAgent state reported by the backend.

## MLS Lessons Panel

* **Source:** `GET /api/mls` with optional `?type=solution|failure|pattern|improvement`.
* **Summary metrics:** total entries and per-type counts from the response `summary` object.
* **Filters:** pill bar drives the `type` query parameter for server-side filtering. The **Refresh** button re-issues the most recent query, and the panel auto-refreshes every 30 seconds.
* **Presentation:** each entry renders as a card with:
  * Type badge, title, and relative timestamp.
  * Score, tags, and truncated context/details with an optional “Show more” toggle.
  * Related Work Order / session chips and verification state.
* **Error handling:** same inline retry banner pattern as Services.

Use MLS cards during incident/postmortem reviews to surface patterns, known fixes, or failure write-ups without leaving the dashboard. Entries remain immutable here—any edits still flow through the MLS ingestion pipeline.
