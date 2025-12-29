#!/bin/zsh
# infra/vault/scripts/vault_bootstrap_dev.zsh

export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='root'

echo "🔒 Bootstrapping Local Vault..."

# 1. Check health
if ! vault status > /dev/null 2>&1; then
    echo "❌ Vault is not running or unreachable at $VAULT_ADDR"
    echo "   Run 'make vault-up' first."
    exit 1
fi

# 2. Enable KV v2 at secret/ (often enabled by default in dev, but ensuring)
echo "   Enabling KV v2 engine at secret/..."
vault secrets enable -path=secret kv-v2 2>/dev/null || echo "   (Engine already exists, skipping)"

# 3. Create example secret
echo "   Writing example secret to secret/data/02luka/example..."
vault kv put secret/02luka/example \
    username="admin" \
    password="super_secure_dev_password_123" \
    api_key="example_key_xyz"

echo "✅ Vault Bootstrap Complete."
echo "   Try: vault kv get secret/02luka/example"
