import os
import sys
from pathlib import Path

# Try to load dotenv for .env.local support
try:
    from dotenv import load_dotenv
    # Load .env.local if it exists
    env_local_path = Path(__file__).parent.parent / '.env.local'
    if env_local_path.exists():
        load_dotenv(dotenv_path=env_local_path)
except ImportError:
    pass  # python-dotenv not installed, skipping .env.local loading

def get_secret(key: str, vault_path: str = None, default: str = None) -> str:
    """
    Resolve a secret with the following priority:
    1. OS Environment Variable (os.getenv)
    2. Vault (if configured and vault_path provided)
    3. Fallback default (or None)
    
    Args:
        key (str): The environment variable name (e.g. 'REDIS_PASSWORD')
        vault_path (str): The Vault path/key (e.g. 'secret/data/02luka/redis/password')
                          Note: Assumes 'data' nesting for KV v2 if using raw paths, 
                          but standard client usually abstracts this. 
                          For this simple loader, we assume 'secret/data/...' for HTTP API 
                          or 'secret/...' for HVAC client.
                          Accepted format here: 'mount/path/to/secret:key'
        default (str): Fallback value.
    """
    
    # 1. Environment Variable (includes .env.local if loaded)
    val = os.getenv(key)
    if val is not None:
        return val

    # 2. Vault (Optional implementation)
    # Checks if VAULT_ADDR and VAULT_TOKEN are present
    if vault_path and os.getenv('VAULT_ADDR') and os.getenv('VAULT_TOKEN'):
        try:
            val = _fetch_from_vault(vault_path)
            if val is not None:
                return val
        except Exception as e:
            # Log warning but don't crash
            print(f"⚠️  [SecretsLoader] Vault fetch failed for {vault_path}: {e}", file=sys.stderr)

    return default

def _fetch_from_vault(combined_path: str) -> str:
    """
    Rudimentary Vault fetcher using hvac or requests.
    Format: 'path/to/secret:key'
    """
    try:
        import hvac
    except ImportError:
        return None

    client = hvac.Client(
        url=os.getenv('VAULT_ADDR'),
        token=os.getenv('VAULT_TOKEN')
    )
    
    if not client.is_authenticated():
        return None

    path_part, key_part = combined_path.split(':')
    
    # Assuming KV v2 mount at 'secret/'
    # hvac requires mount_point and path separately usually, or use secrets.kv.v2.read_secret_version
    try:
        # Simple heuristic: assume mount is first component
        mount = path_part.split('/')[0]
        subpath = '/'.join(path_part.split('/')[1:])
        
        response = client.secrets.kv.v2.read_secret_version(
            mount_point=mount,
            path=subpath
        )
        return response['data']['data'].get(key_part)
    except Exception:
        return None
