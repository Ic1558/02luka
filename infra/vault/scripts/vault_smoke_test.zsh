#!/bin/zsh
# infra/vault/scripts/vault_smoke_test.zsh

export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='root'

echo "💨 Running Vault Smoke Test..."

TEST_PATH="secret/02luka/smoke_test_$(date +%s)"
TEST_VAL="smoke_value_$(date +%s)"

# 1. Write
echo "    Writing to $TEST_PATH..."
vault kv put $TEST_PATH status="ok" magic="$TEST_VAL"

# 2. Read
echo "    Reading back..."
READ_VAL=$(vault kv get -field=magic $TEST_PATH)

# 3. Verify
if [[ "$READ_VAL" == "$TEST_VAL" ]]; then
    echo "✅ SUCCESS: Read value matches written value."
    # Cleanup
    vault kv metadata delete $TEST_PATH > /dev/null
    exit 0
else
    echo "❌ FAILURE: Expected '$TEST_VAL', got '$READ_VAL'"
    exit 1
fi
