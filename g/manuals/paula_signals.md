# Paula Signal Service Integration Guide

This guide explains how to consume Paula's trade signal feed from external systems, with a focus on MetaTrader 4 (MT4) and MetaTrader 5 (MT5) clients. It covers the HTTPS endpoints exposed by the service, authentication, payload formats, and sample workflows for acknowledging or rejecting signals.

> **Base URL**
>
> The service is deployed per environment. Replace `<cluster>` with the appropriate hostname supplied by the Paula operations team, for example `https://paula-agent.trade.soluna.dev`.
>
> ```text
> https://<cluster>
> ```

## Authentication

Requests must include an API key assigned to your account. Send the key in the `X-API-Key` header on every request. Keys are scoped per trading account—if you operate multiple accounts, request a key for each account and rotate them independently.

Example header block:

```
X-API-Key: 3c5cbb20-2d0e-4d1f-91e6-ff631b50d84c
User-Agent: SolunaSignalClient/1.0
Accept: application/json
```

If the key is missing or invalid the API returns `401 Unauthorized`.

## Overview of the polling loop

1. Poll `GET /signal` with your `account_id`. This returns the most recent pending signal or `204 No Content` when no work is queued.
2. If a signal is returned, act on it (open/close orders, adjust risk, etc.).
3. Acknowledge the signal with `POST /signal/{id}/ack` once you accept execution, or send `POST /signal/{id}/reject` with an error code if it cannot be fulfilled.
4. Optionally post execution details to `POST /signal/{id}/fill` after the order is filled.
5. Send a heartbeat at least once per minute with `POST /accounts/{account_id}/heartbeat` to prove liveness.

All endpoints are idempotent—repeating the same acknowledgement or rejection with identical payloads is safe.

## Endpoints

| Endpoint | Method | Auth | Description |
|----------|--------|------|-------------|
| `/health` | `GET` | No | Basic readiness probe. Returns `200 OK` with `{ "status": "ok" }` when the service is healthy. |
| `/signal` | `GET` | Yes | Fetch the next actionable signal for the account. Supports filters for `symbol`, `status`, and `since`. |
| `/signal/{id}/ack` | `POST` | Yes | Confirms that the client accepted the signal for execution. |
| `/signal/{id}/reject` | `POST` | Yes | Rejects a signal and records a reason code. |
| `/signal/{id}/fill` | `POST` | Yes | Records execution details (fill price, volume, timestamp). |
| `/accounts/{account_id}/heartbeat` | `POST` | Yes | Signals that the client is online and ready to consume signals. |

### `GET /signal`

Query parameters:

| Parameter | Required | Description |
|-----------|----------|-------------|
| `account_id` | ✅ | Identifier of the trading account as registered with Paula. |
| `symbol` | ⛔ | Optional symbol filter (e.g. `EURUSD`). |
| `status` | ⛔ | Filter by status (`pending`, `stale`). Defaults to `pending`. |
| `since` | ⛔ | ISO-8601 timestamp. Only return signals created after this time. |

Example request:

```http
GET /signal?account_id=DEMO-ACC-1&symbol=EURUSD HTTP/1.1
Host: paula-agent.trade.soluna.dev
X-API-Key: <api-key>
Accept: application/json
```

Example response:

```json
{
  "id": "sig-91825",
  "account_id": "DEMO-ACC-1",
  "symbol": "EURUSD",
  "action": "BUY",
  "entry_price": 1.06723,
  "stop_loss": 1.06400,
  "take_profit": 1.07350,
  "expires_at": "2024-10-15T18:00:00Z"
}
```

`204 No Content` indicates there are no pending signals at the moment.

### `POST /signal/{id}/ack`

Payload fields:

| Field | Type | Description |
|-------|------|-------------|
| `account_id` | `string` | Account acknowledging the signal. |
| `strategy` | `string` | Optional strategy or EA identifier executing the signal. |
| `notes` | `string` | Optional free-form notes. |

Example payload:

```json
{
  "account_id": "DEMO-ACC-1",
  "strategy": "SolunaGrid-v2",
  "notes": "Order placed with 1.0 lot"
}
```

Returns `202 Accepted` when the acknowledgement is accepted.

### `POST /signal/{id}/reject`

Payload fields:

| Field | Type | Description |
|-------|------|-------------|
| `account_id` | `string` | Account rejecting the signal. |
| `reason_code` | `string` | Required machine-readable reason (e.g. `RISK_LIMIT`, `MARKET_CLOSED`). |
| `notes` | `string` | Optional human readable detail. |

Returns `202 Accepted` and records the rejection. Duplicate submissions are ignored.

### `POST /signal/{id}/fill`

Payload fields:

| Field | Type | Description |
|-------|------|-------------|
| `account_id` | `string` | Executing account. |
| `fill_price` | `number` | Executed price. |
| `fill_volume` | `number` | Lot volume executed. |
| `executed_at` | `string` | ISO-8601 timestamp (UTC) when the fill occurred. |

A successful response returns `201 Created`.

### `POST /accounts/{account_id}/heartbeat`

Payload fields:

| Field | Type | Description |
|-------|------|-------------|
| `status` | `string` | Optional status text (e.g. `online`, `degraded`). |
| `latency_ms` | `number` | Optional moving average latency your platform experiences. |

Returns `204 No Content`.

## Error handling

The API uses conventional HTTP status codes:

- `400 Bad Request` – invalid parameter value. The response body includes details.
- `401 Unauthorized` – missing or invalid API key.
- `404 Not Found` – signal ID does not exist or is no longer actionable.
- `409 Conflict` – signal already acknowledged or rejected by another client.
- `429 Too Many Requests` – slow down; you are hitting the rate limit (default 30 requests/minute per account).
- `500 Internal Server Error` – unexpected server error; retry with exponential backoff.

Responses include a structured error document:

```json
{
  "error": "RATE_LIMIT",
  "message": "Too many calls in the last minute",
  "retry_after": 10
}
```

Clients should inspect `retry_after` (seconds) to determine when to reattempt the request.

## Testing with `curl`

```bash
curl -s \
  -H "X-API-Key: $PAULA_API_KEY" \
  "https://paula-agent.trade.soluna.dev/signal?account_id=DEMO-ACC-1"
```

To acknowledge a signal:

```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -H "X-API-Key: $PAULA_API_KEY" \
  -d '{"account_id":"DEMO-ACC-1","strategy":"Backtester"}' \
  "https://paula-agent.trade.soluna.dev/signal/sig-91825/ack"
```

## MetaTrader integration notes

1. Add Paula's domain to **Tools → Options → Expert Advisors → Allow WebRequest for listed URL**.
2. Copy the relevant `SolunaSignalClient.mqh` file to your platform's `MQL4/Include` or `MQL5/Include` directory.
3. Include the client in your Expert Advisor and configure the base URL and API key.
4. Poll `GetNextSignal` on a timer (30–60 seconds). The helper automatically handles URL encoding and header construction.
5. Use `AcknowledgeSignal`, `RejectSignal`, and `ReportFill` to synchronize execution state back to Paula.

See `sample_ea/SolunaSignalSample.mq4` for a minimal polling Expert Advisor implementation.

## Troubleshooting checklist

- **Error 401** – Confirm that the `X-API-Key` header matches the account's key.
- **Error 403** – Your key is valid but lacks permissions for the requested account.
- **Error 426** – The service requires TLS 1.2. Ensure your platform build is 1350 or higher.
- **No response** – Check that the domain is added to MetaTrader's WebRequest allow-list and that your firewall allows outbound HTTPS.
- **Stale signals** – If `expires_at` has passed, reject with reason `EXPIRED` and provide the timestamp you observed.

For production onboarding or additional support, reach out to the Paula integrations channel at `#paula-integrations` on Slack.
