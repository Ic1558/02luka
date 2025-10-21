# Phase 9.0 Deployment - Ready to Go! 🚀

## ✅ What I've Done For You

1. **Fixed .env file:**
   - ✅ Updated `REPO_HOST_PATH` to Mac path
   - ✅ Generated secure `BRIDGE_TOKEN`: `a13865018b9ac3c95d5771478e5a5affeb66cb38c8bcbd1cb2ee46bbed5f2a5c`
   - ✅ All other settings preserved

2. **Verified Scripts:**
   - ✅ `WO-OPS-BOOTSTRAP.sh` - executable (755)
   - ✅ `WO-OPS-PUBLISH-WORKER.sh` - executable (755)

3. **Created Master Deployment Script:**
   - ✅ `DEPLOY-PHASE9-MAC.sh` - complete deployment automation

---

## 🚀 What You Need to Do

### **Option A: One-Command Deployment**

Open Mac Terminal and run:

```bash
cd "$HOME/Library/CloudStorage/GoogleDrive-ittipong.c@gmail.com/My Drive/02luka/02luka-repo"
chmod +x DEPLOY-PHASE9-MAC.sh
./DEPLOY-PHASE9-MAC.sh
```

This will:
- ✅ Load environment
- ✅ Start Docker stack
- ✅ Verify bridge health
- ✅ Run bootstrap tests
- ✅ Optionally deploy Worker (if cloudflared/wrangler installed)
- ✅ Run local verification

---

### **Option B: Step-by-Step Manual**

If you prefer manual control:

```bash
cd "$HOME/Library/CloudStorage/GoogleDrive-ittipong.c@gmail.com/My Drive/02luka/02luka-repo"

# Load environment
set -a; source .env; set +a

# Start Docker
docker compose up -d
sleep 3

# Test bridge
curl -s -H "x-auth-token: $BRIDGE_TOKEN" http://127.0.0.1:8788/ping

# Bootstrap
./WO-OPS-BOOTSTRAP.sh

# Deploy worker (optional, requires cloudflared + wrangler)
./WO-OPS-PUBLISH-WORKER.sh --ephemeral

# Verify
make verify-ops
make show-verify
```

---

## 🎯 Expected Results

After deployment, you should see:

**Bridge Health:**
```json
{"ok": true}
```

**Docker Services:**
```
NAME                   STATUS
redis                  Up
http_redis_bridge      Up
ops_health             Up
ops_alerts             Up
```

**Worker URL (if deployed):**
```
https://ops-02luka-XXXXX.workers.dev
```

---

## 🔧 Prerequisites

**Required (you have):**
- ✅ Docker Desktop for Mac
- ✅ Repository with updated .env

**Optional (for Worker deployment):**
- ⚠️ `cloudflared` - Install: `brew install cloudflared`
- ⚠️ `wrangler` - Install: `npm install -g wrangler`

---

## 🆘 Troubleshooting

**If bridge doesn't respond:**
```bash
docker compose logs bridge --tail=100
docker compose restart bridge
```

**Check all services:**
```bash
docker compose ps -a
```

**Full restart:**
```bash
docker compose down
docker compose up -d
```

**View real-time logs:**
```bash
docker compose logs -f bridge
```

---

## 📊 Post-Deployment

Once deployed, access:

- **Local Bridge:** http://127.0.0.1:8788
- **Health Check:** http://127.0.0.1:8788/ops-health
- **Worker UI:** https://ops-02luka-XXXXX.workers.dev (after Step 4)

---

## 🤖 Enable Autonomy (Later)

After burn-in:
```bash
make auto-advice   # supervised mode first
make auto-auto     # full autonomy later
```

---

**Ready to deploy? Run the script in your Mac Terminal!** 🚀
