# Trading Data Sources Integration Guide

**Status:** ⚠️ NOT CONFIGURED - Manual Integration Required
**Date:** 2025-11-01

## Current Situation

❗ **The Paula signal tools do NOT automatically fetch trading data.**

They are "push" scripts that send data to Prometheus/Telegram, but **YOU must provide**:
- Current price
- Trading signal (buy/sell/flat)
- Confidence level
- Account metrics (PnL, margin, position)

---

## Integration Options

### Option 1: Manual Entry (Current Method)

**Simplest approach** - You watch your trading platform and manually trigger signals:

```bash
# You see price at 870, decide to buy
paula buy 870 0.85 "Breakout pattern" M30

# You see price at 792, decide to sell
paula sell 792 0.90 "Resistance rejected" H1
```

**Pros:**
- ✅ No coding required
- ✅ Full control over signals
- ✅ Works immediately

**Cons:**
- ❌ Not automated
- ❌ Requires constant monitoring
- ❌ Can't trade 24/7

---

### Option 2: Alpha Vantage (Free API)

**Good for:** Stock prices, forex, crypto (limited free tier)

#### Setup

1. **Get API Key:**
   ```bash
   # Sign up at: https://www.alphavantage.co/support/#api-key
   # Free tier: 25 requests/day
   ```

2. **Save API Key:**
   ```bash
   echo "ALPHA_VANTAGE_KEY=YOUR_KEY_HERE" >> ~/.config/02luka/secrets/trading.env
   ```

3. **Create Fetcher Script:**
   ```bash
   cat > ~/bin/trading/fetch_alpha_vantage.zsh <<'EOF'
   #!/usr/bin/env zsh
   set -euo pipefail

   source ~/.config/02luka/secrets/trading.env
   SYMBOL="${1:-SET50}"

   # Fetch latest price
   RESPONSE=$(curl -s "https://www.alphavantage.co/query?function=GLOBAL_QUOTE&symbol=${SYMBOL}&apikey=${ALPHA_VANTAGE_KEY}")

   PRICE=$(echo "$RESPONSE" | jq -r '.["Global Quote"]["05. price"]')

   if [[ "$PRICE" != "null" && -n "$PRICE" ]]; then
     echo "Latest ${SYMBOL} price: $PRICE"
     # Push to Prometheus
     ~/bin/trading/push_price.zsh "$SYMBOL" "$PRICE"
   else
     echo "❌ Failed to fetch price"
     exit 1
   fi
   EOF

   chmod +x ~/bin/trading/fetch_alpha_vantage.zsh
   ```

4. **Test:**
   ```bash
   ~/bin/trading/fetch_alpha_vantage.zsh AAPL
   ```

---

### Option 3: Interactive Brokers API

**Good for:** Professional trading, real-time data, automated execution

#### Setup

1. **Install IB Gateway or TWS**
2. **Install Python API:**
   ```bash
   pip3 install ib_insync
   ```

3. **Create Fetcher:**
   ```python
   # ~/bin/trading/fetch_ib.py
   from ib_insync import IB, Stock
   import subprocess

   ib = IB()
   ib.connect('127.0.0.1', 7497, clientId=1)  # TWS port

   contract = Stock('AAPL', 'SMART', 'USD')
   ticker = ib.reqMktData(contract)
   ib.sleep(2)

   price = ticker.last
   print(f"Latest price: {price}")

   # Push to Prometheus
   subprocess.run(['~/bin/trading/push_price.zsh', 'AAPL', str(price)])

   ib.disconnect()
   ```

---

### Option 4: TradingView Webhooks

**Good for:** Chart-based strategies, no coding required

#### Setup

1. **Create TradingView Alert:**
   - Open your chart
   - Create alert with condition
   - Set Webhook URL to your server

2. **Create Webhook Receiver:**
   ```bash
   # Install simple webhook server
   pip3 install flask

   cat > ~/bin/trading/tradingview_webhook.py <<'EOF'
   from flask import Flask, request
   import subprocess

   app = Flask(__name__)

   @app.route('/webhook', methods=['POST'])
   def webhook():
       data = request.json
       action = data.get('action')  # buy/sell/flat
       price = data.get('price')
       symbol = data.get('symbol', 'SET50')

       # Trigger Paula signal
       subprocess.run([
           '~/bin/trading/paula_signal.zsh',
           action,
           str(price),
           '0.80',  # confidence
           f"TradingView alert: {data.get('reason', 'signal')}",
           'H1'
       ])

       return {'status': 'ok'}

   if __name__ == '__main__':
       app.run(port=5000)
   EOF
   ```

3. **Start Webhook Server:**
   ```bash
   python3 ~/bin/trading/tradingview_webhook.py &
   ```

4. **Configure TradingView Alert:**
   - Webhook URL: `http://your-server-ip:5000/webhook`
   - Message (JSON):
   ```json
   {
     "action": "{{strategy.order.action}}",
     "price": "{{close}}",
     "symbol": "{{ticker}}",
     "reason": "{{strategy.order.comment}}"
   }
   ```

---

### Option 5: Yahoo Finance (Free)

**Good for:** Simple price tracking, delayed data

#### Setup

```bash
cat > ~/bin/trading/fetch_yahoo.zsh <<'EOF'
#!/usr/bin/env zsh
set -euo pipefail

SYMBOL="${1:-^SET.BK}"  # SET50 index

# Fetch latest price using Yahoo Finance
RESPONSE=$(curl -s "https://query1.finance.yahoo.com/v8/finance/chart/${SYMBOL}?interval=1m&range=1d")

PRICE=$(echo "$RESPONSE" | jq -r '.chart.result[0].meta.regularMarketPrice')

if [[ "$PRICE" != "null" && -n "$PRICE" ]]; then
  echo "Latest ${SYMBOL} price: $PRICE"
  ~/bin/trading/push_price.zsh "${SYMBOL}" "$PRICE"
else
  echo "❌ Failed to fetch price"
  exit 1
fi
EOF

chmod +x ~/bin/trading/fetch_yahoo.zsh
```

---

### Option 6: MetaTrader 4/5 Integration

**Good for:** Forex/CFD trading, automated EA (Expert Advisor)

#### Setup

1. **Create EA in MetaTrader:**
   ```mql4
   // Paula_Signal_Sender.mq4

   void OnTick() {
       double price = Close[0];
       string action = "flat";
       double confidence = 0.0;

       // Your strategy logic here
       if (iMA(NULL, 0, 20, 0, MODE_SMA, PRICE_CLOSE, 0) > iMA(NULL, 0, 50, 0, MODE_SMA, PRICE_CLOSE, 0)) {
           action = "buy";
           confidence = 0.80;
       } else {
           action = "sell";
           confidence = 0.75;
       }

       // Send to webhook/file
       string cmd = StringFormat("curl -X POST http://localhost:5000/mt4signal -d 'action=%s&price=%.2f&confidence=%.2f'",
                                 action, price, confidence);
       ShellExecute(cmd);
   }
   ```

2. **Create Receiver:**
   ```bash
   # Receive MT4 signals and forward to Paula
   python3 ~/bin/trading/mt4_receiver.py &
   ```

---

## Automated Fetching with Cron

Once you have a fetcher script, automate it:

```bash
# Fetch price every 5 minutes during market hours (9:00-16:00)
*/5 9-16 * * 1-5 ~/bin/trading/fetch_yahoo.zsh SET50 >> ~/02luka/logs/price_fetch.log 2>&1
```

Add to crontab:
```bash
crontab -e
```

---

## Recommended Integration for SET50 Trading

Based on your setup (SET50 trading), here's what I recommend:

### Step 1: Choose Data Source

**For Thailand SET50:**
- **Alpha Vantage** - Limited support for Thai stocks
- **Yahoo Finance** - Use `^SET.BK` symbol ✅ RECOMMENDED
- **Local Broker API** - If your broker provides API

### Step 2: Implement Fetcher

```bash
# Create Yahoo Finance fetcher for SET50
cat > ~/bin/trading/fetch_set50.zsh <<'EOF'
#!/usr/bin/env zsh
set -euo pipefail

# Fetch SET50 index price
RESPONSE=$(curl -s "https://query1.finance.yahoo.com/v8/finance/chart/^SET.BK?interval=5m&range=1d")
PRICE=$(echo "$RESPONSE" | jq -r '.chart.result[0].meta.regularMarketPrice')

if [[ "$PRICE" != "null" ]]; then
  echo "SET50: $PRICE"
  ~/bin/trading/push_price.zsh "SET50" "$PRICE"

  # Optional: Check if we should send signal based on your strategy
  # YOUR_STRATEGY_LOGIC_HERE
  # If buy signal: paula buy $PRICE 0.80 "Your reason" M30
fi
EOF

chmod +x ~/bin/trading/fetch_set50.zsh
```

### Step 3: Test

```bash
~/bin/trading/fetch_set50.zsh
```

### Step 4: Automate

```bash
# Add to crontab - fetch every 5 minutes during market hours
*/5 9-16 * * 1-5 ~/bin/trading/fetch_set50.zsh
```

---

## Creating Your Trading Strategy

Once you have price data, you need to decide WHEN to send signals. Example:

```bash
#!/usr/bin/env zsh
# strategy_simple_ma.zsh - Simple Moving Average crossover

PRICE=$(curl -s "https://query1.finance.yahoo.com/v8/finance/chart/^SET.BK" | jq -r '.chart.result[0].meta.regularMarketPrice')

# Fetch historical prices for MA calculation
# ... calculate MA20 and MA50 ...

if [[ $MA20 > $MA50 ]]; then
  # Bullish crossover - send BUY signal
  paula buy $PRICE 0.80 "MA20 crossed above MA50" H1
elif [[ $MA20 < $MA50 ]]; then
  # Bearish crossover - send SELL signal
  paula sell $PRICE 0.75 "MA20 crossed below MA50" H1
fi
```

---

## Summary

```
Current State:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
❌ No automatic data source configured
❌ No price fetching mechanism
❌ No trading strategy automation

What You Need to Do:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. Choose a data source (Yahoo Finance recommended for SET50)
2. Create a fetcher script
3. (Optional) Implement trading strategy logic
4. (Optional) Automate with cron

Current Workflow:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Manual → You watch price → You run: paula buy 870 0.85 "reason"

Future Automated Workflow:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Data Source → Fetcher Script → Strategy Logic → paula command
→ Pushgateway → Prometheus → Alertmanager → Telegram
```

---

## Next Steps

Would you like me to:
1. ✅ Set up Yahoo Finance fetcher for SET50?
2. ✅ Create a simple trading strategy (MA crossover)?
3. ✅ Automate with cron/LaunchAgent?
4. ✅ Integrate with your existing trading platform?

Let me know which data source you want to use!
