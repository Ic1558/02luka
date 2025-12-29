# Vault Phase 2 (Native Infra)

This directory contains the infrastructure for running a local HashiCorp Vault instance natively.

## Prerequisites
- **Vault Binary**: You must have `vault` installed.
  ```bash
  brew install vault
  ```

## Quick Start

### 1. Start Vault
```bash
make vault-up
```
This runs `vault server -dev` in the background and saves the PID to `infra/vault/PID`.
- **Root Token**: `root`
- **Address**: `http://127.0.0.1:8200`
- **UI**: [http://127.0.0.1:8200/ui](http://127.0.0.1:8200/ui)

### 2. Stop Vault
```bash
make vault-down
```
This kills the process ID found in `infra/vault/PID`.

### 3. Bootstrap
Populate the vault with initial configs and enable the `secret/` KV v2 engine.
```bash
make vault-bootstrap
```

### 4. Verification
Run the smoke test to verify read/write access.
```bash
make vault-smoke
```

## Secrets Contract
We use the path `secret/data/02luka/<service>/<key>` for all application secrets.

**Example:**
- `secret/data/02luka/redis/password`
- `secret/data/02luka/openai/api_key`

## Integration
Applications should use `core.secrets_loader.py` to resolve secrets.
**Priority Order:**
1. OS Environment Variable
2. Vault (if `VAULT_ADDR` & `VAULT_TOKEN` are set)
3. `.env.local` (Dev fallback)
