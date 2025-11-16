# AP/IO v3.1 Routing Guide

**Version:** 3.1  
**Date:** 2025-11-16  
**Status:** Active

---

## Overview

This guide explains how to route AP/IO v3.1 events between agents.

---

## Routing Modes

### Single Agent

```bash
tools/ap_io_v31/router.zsh event.json --targets cls
```

### Multiple Agents

```bash
tools/ap_io_v31/router.zsh event.json --targets cls,andy
```

### Broadcast

```bash
tools/ap_io_v31/router.zsh event.json --broadcast
```

---

## Priority Levels

- `critical` - Immediate delivery
- `high` - Priority queue
- `normal` - Standard queue (default)
- `low` - Background processing

---

## Routing Flow

1. Create event → `writer.zsh`
2. Route event → `router.zsh`
3. Agent receives event via integration script
4. Agent writes response event back
5. Update `delivered_to` in routing object

---

## Correlation Flow

1. Liam creates event with `correlation_id`
2. Router sends to CLS + Andy
3. Both log results
4. Liam reads ledger with `reader.zsh --correlation <id>`

---

## Error Handling

- If integration script missing → warning, continue
- If agent offline → log to queue, retry later
- If validation fails → reject event, log error

---

**Document Owner:** Liam  
**Last Updated:** 2025-11-16
