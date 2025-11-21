# Dashboard — Services & MLS Panels

## Overview

The Ops Dashboard now exposes two additional observability panels:

- **Services (LaunchAgents)** — current status of 02luka services discovered via `/api/services`.

- **MLS Lessons** — consolidated machine learning system lessons from `/api/mls`.

These panels are read-only and do not change system state.

---

## Services Panel

**Endpoint:** `GET /api/services`

The backend returns:

- `services`: array of service objects:

  - `label`: LaunchAgent label (e.g. `com.02luka.mary`)

  - `pid`: current PID (or `null` if not running)

  - `status`: `running`, `stopped`, or `failed`

  - `exit_code`: numeric exit code when failed

  - `type`: inferred type: `bridge`, `worker`, `automation`, `monitoring`, or `other`

- `summary`: aggregate counts:

  - `total`, `running`, `stopped`, `failed`

The UI shows:

- A summary bar with total / running / stopped / failed.

- A table listing each service with:

  - Label

  - Type

  - Status (color badge)

  - PID

  - Exit code

Controls:

- Status filter: All / Running / Stopped / Failed.

Refresh interval:

- ~30 seconds. The panel automatically refreshes in the background.

---

## MLS Lessons Panel

**Endpoint:** `GET /api/mls`

The backend returns:

- `entries`: array of MLS entries:

  - `id`, `type`, `title`, `details`, `context`

  - `time`, `related_wo`, `related_session`

  - `tags[]`, `verified`, `score`

- `summary`: aggregate counts:

  - `total`, `solutions`, `failures`, `patterns`, `improvements`

The UI shows:

- A summary bar with total + breakdown by type.

- A table of MLS entries with:

  - Type (badge)

  - Title

  - Time

  - Verified flag

  - Score

Interaction:

- Click any row to see details, context, tags, and related WO/session.

- Filter by type (All / solution / failure / pattern / improvement).

- Free-text search across title, details, context, and tags.

Refresh interval:

- ~60 seconds. The panel periodically refetches MLS data while the dashboard is open.
