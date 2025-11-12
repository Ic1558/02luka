# Phase 4 Daily Operations Runbook

**Time to read:** < 60 seconds  
**System:** Shared Memory Phase 4 (Redis Hub + Mary/R&D Integration)

---

## Quick Status Check (10 seconds)

```bash
# Check hub status
launchctl list | grep com.02luka.memory.hub

# Check Redis
redis-cli -a changeme-02luka PING

# Check recent activity
redis-cli -a changeme-02luka HGETALL memory:agents:mary
redis-cli -a changeme-02luka HGETALL memory:agents:rnd
```

---

## Recording Mary Results (10 seconds)

After Mary completes a work order:

```bash
~/02luka/tools/mary.zsh "<work_order_id>" "completed" '{"result":"success","note":"deployed foo"}'
```

**Example:**
```bash
~/02luka/tools/mary.zsh "WO-20251112-001" "completed" '{"result":"success","latency_ms":321}'
```

---

## Recording R&D Outcomes (10 seconds)

After R&D processes a proposal:

```bash
~/02luka/tools/rnd.zsh "<proposal_id>" "processed" '{"score":88,"delta":+3}'
```

**Example:**
```bash
~/02luka/tools/rnd.zsh "RND-PR-123" "applied" '{"improvements":["tests","docs"],"score_delta":+7}'
```

---

## Monitoring Hub Logs (10 seconds)

```bash
# View recent logs
tail -n 50 ~/02luka/logs/memory_hub.out.log

# Follow logs in real-time
tail -f ~/02luka/logs/memory_hub.out.log
```

---

## Troubleshooting (20 seconds)

### No updates in Redis but file updates
```bash
# Check Redis connection
redis-cli -a changeme-02luka PING

# Check hub logs
tail -n 20 ~/02luka/logs/memory_hub.err.log
```

### No events in memory:updates
```bash
# Check hub is running
launchctl list | grep com.02luka.memory.hub

# Check pub/sub
redis-cli -a changeme-02luka PUBSUB CHANNELS memory:updates
```

### context.json not updating
```bash
# Check file permissions
ls -la ~/02luka/shared_memory/context.json

# Check hub process
ps aux | grep memory_hub
```

---

## Daily Digest

Generated automatically at 07:05:
- Location: `g/reports/memory_digest_YYYYMMDD.md`
- Contains: Mary + R&D activity summary

View manually:
```bash
~/02luka/tools/memory_daily_digest.zsh
```

---

## Quick Reference

| Task | Command |
|------|---------|
| Record Mary result | `~/02luka/tools/mary.zsh "<id>" "completed" '{...}'` |
| Record R&D outcome | `~/02luka/tools/rnd.zsh "<id>" "processed" '{...}'` |
| Check health | `~/02luka/tools/memory_hub_health.zsh` |
| Run acceptance | `~/02luka/tools/phase4_acceptance.zsh` |
| View digest | `cat ~/02luka/g/reports/memory_digest_$(date +%Y%m%d).md` |

---

**Last Updated:** 2025-11-12
