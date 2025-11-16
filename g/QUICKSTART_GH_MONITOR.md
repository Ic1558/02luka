# GitHub Actions Monitor - Quick Start Guide

**Status**: ✅ DEPLOYED (LaunchAgent running)
**Date**: 2025-11-11
**Agent PID**: 99910

## 🚀 Current Setup - สถานะปัจจุบัน

### Production Monitoring (Running Now) ✅
**LaunchAgent Version** is active and monitoring all workflows every 30 seconds.

**Status**:
```bash
launchctl list com.02luka.gh-monitor
# PID: 99910
# LastExitStatus: 0
```

**What it does**:
- ✅ Monitors GitHub Actions failures automatically
- ✅ Shows macOS notifications when failures occur
- ✅ Extracts and saves failure logs
- ✅ Runs continuously in background
- ✅ Auto-starts on system boot

## 📋 Quick Commands - คำสั่งด่วน

### Check Status - ตรวจสอบสถานะ
```bash
# Method 1: Via control script
tools/gh_monitor_control.zsh status

# Method 2: Direct launchctl
launchctl list com.02luka.gh-monitor
```

### View Logs - ดูบันทึก
```bash
# Agent logs
tail -f ~/02luka/logs/gh_monitor_agent.stdout.log

# Failure logs
ls -lh ~/02luka/g/reports/gh_failures/

# Latest failure
ls -t ~/02luka/g/reports/gh_failures/*.log | head -1 | xargs cat
```

### Stop/Start Agent - หยุด/เริ่มตัวแทน
```bash
# Stop
tools/gh_monitor_control.zsh stop

# Start
tools/gh_monitor_control.zsh start

# Restart
tools/gh_monitor_control.zsh restart
```

## 🤖 AI Analysis (On-Demand) - วิเคราะห์ AI (เมื่อต้องการ)

### When to Use AI Analysis
Use the AI version when you need:
- 🔍 Root cause analysis of failures
- 💡 Automated fix suggestions
- 🎯 Priority assessment
- 📊 Pattern recognition across multiple failures

### Requirements
```bash
# Install Ollama (if not installed)
brew install ollama

# Pull recommended model
ollama pull llama3.2
```

### Run AI Analysis
```bash
# Enable AI analysis for specific workflow
AI_ENABLED=1 tools/gh_monitor_agent_ai.zsh "CI" 60

# Or with custom Ollama endpoint
AI_ENABLED=1 OLLAMA_ENDPOINT="http://localhost:11434" \
  tools/gh_monitor_agent_ai.zsh
```

### AI Analysis Output
When enabled, AI creates analysis files:
```bash
# View AI analysis of a specific failure
cat ~/02luka/g/reports/gh_failures/<run_id>_analysis.txt
```

## 🎯 Hybrid Approach (Recommended) - แนวทางแบบผสม (แนะนำ)

### Best Practice Setup
1. **LaunchAgent** (Already Running ✅): Simple continuous monitoring
2. **AI Analysis** (On-Demand): Run when you need intelligent insights

### Workflow Example:
```bash
# 1. LaunchAgent detects failure (automatic)
# 2. You receive macOS notification
# 3. Review basic error summary in logs
# 4. If complex, run AI analysis:
AI_ENABLED=1 tools/gh_monitor_agent_ai.zsh "CI" 60

# 5. Get AI insights:
cat ~/02luka/g/reports/gh_failures/<run_id>_analysis.txt
```

## 📊 What Gets Monitored - ตรวจสอบอะไรบ้าง

### Current Configuration:
- **Workflows**: All workflows (empty filter)
- **Interval**: 30 seconds
- **Actions on Failure**:
  1. Extracts full logs from GitHub
  2. Saves to `~/02luka/g/reports/gh_failures/`
  3. Shows macOS notification
  4. Logs to agent stdout

### Customize Monitoring:
Edit LaunchAgent plist to monitor specific workflow:
```bash
# Edit plist
nano ~/Library/LaunchAgents/com.02luka.gh-monitor.plist

# Change ProgramArguments:
<array>
    <string>/Users/icmini/02luka/tools/gh_monitor_agent.zsh</string>
    <string>CI</string>          <!-- Workflow name -->
    <string>60</string>           <!-- Interval in seconds -->
</array>

# Reload
launchctl unload ~/Library/LaunchAgents/com.02luka.gh-monitor.plist
launchctl load -w ~/Library/LaunchAgents/com.02luka.gh-monitor.plist
```

## 🔔 Notifications - การแจ้งเตือน

### What You'll See:
When a workflow fails, you get a macOS notification:

**Title**: ❌ GitHub Actions Failure
**Message**: [Workflow Name] failed
**Subtitle**: Run #[ID] - Logs saved

### Notification Settings:
```bash
# Test notification
osascript -e 'display notification "Test message" with title "GitHub Monitor" sound name "Glass"'
```

## 🔍 Troubleshooting - แก้ปัญหา

### Agent Not Running
```bash
# Check status
launchctl list | grep gh-monitor

# View error log
cat ~/02luka/logs/gh_monitor_agent.stderr.log

# Restart
tools/gh_monitor_control.zsh restart
```

### No Notifications
```bash
# Check macOS notification settings
# System Settings → Notifications → Script Editor → Allow notifications

# Test notification manually
osascript -e 'display notification "Test" with title "Test"'
```

### Logs Not Being Extracted
```bash
# Verify gh CLI is authenticated
gh auth status

# Test manually
gh run list --limit 5
```

### AI Analysis Not Working
```bash
# Check Ollama
ollama --version
ollama list

# Test AI
ollama run llama3.2 "Hello"

# Check AI_ENABLED
echo $AI_ENABLED  # Should be "1"
```

## 📁 File Locations - ตำแหน่งไฟล์

```
Agent Files:
~/02luka/tools/gh_monitor_agent.zsh        - LaunchAgent version
~/02luka/tools/gh_monitor_agent_ai.zsh     - AI version
~/02luka/tools/setup_gh_monitor.zsh        - Setup script
~/02luka/tools/gh_monitor_control.zsh      - Control script

Configuration:
~/Library/LaunchAgents/com.02luka.gh-monitor.plist

Logs:
~/02luka/logs/gh_monitor_agent.stdout.log  - Agent output
~/02luka/logs/gh_monitor_agent.stderr.log  - Agent errors
~/02luka/g/reports/gh_failures/            - Failure logs

Documentation:
~/02luka/docs/gh_monitor_comparison.md     - Feature comparison
~/02luka/g/reports/gh_monitor_verification.md  - Verification report
~/02luka/QUICKSTART_GH_MONITOR.md          - This guide
```

## 🎓 Advanced Usage - การใช้งานขั้นสูง

### Monitor Specific Workflow
```bash
# Stop current agent
tools/gh_monitor_control.zsh stop

# Edit plist to monitor "CI" workflow only
# (see "Customize Monitoring" section above)

# Restart
tools/gh_monitor_control.zsh start
```

### Multiple Monitoring Instances
```bash
# Run AI version in separate terminal for specific workflow
AI_ENABLED=1 tools/gh_monitor_agent_ai.zsh "Deploy" 120 &

# LaunchAgent continues monitoring all workflows
# Now you have both running simultaneously
```

### Integration with Other Tools
```bash
# Forward notifications to Slack/Discord
# Edit gh_monitor_agent.zsh show_notification function
# Add webhook calls:
curl -X POST "YOUR_WEBHOOK_URL" -d "{\"text\":\"$message\"}"
```

## 📈 Monitoring the Monitor - ตรวจสอบตัวตรวจสอบ

### Health Check
```bash
# Quick health check
ps aux | grep gh_monitor_agent
launchctl list com.02luka.gh-monitor

# View recent activity
tail -50 ~/02luka/logs/gh_monitor_agent.stdout.log

# Count failures detected today
ls ~/02luka/g/reports/gh_failures/*.log | \
  xargs ls -l | \
  awk '$6" "$7" "$8 == "'$(date +"%b %_d %Y")'"' | \
  wc -l
```

### Performance Metrics
```bash
# Agent memory usage
ps aux | grep gh_monitor_agent | awk '{print $6/1024 " MB"}'

# Log file sizes
du -sh ~/02luka/logs/gh_monitor_agent.* ~/02luka/g/reports/gh_failures/
```

## ✅ Verification Checklist - รายการตรวจสอบ

- [x] LaunchAgent installed and running (PID: 99910)
- [x] Monitoring all workflows with 30s interval
- [x] Logs directory exists and writable
- [x] macOS notifications enabled
- [x] Setup script fixed and working
- [x] AI version available for on-demand use
- [x] Control script available for management
- [x] Documentation complete

## 🎯 Next Steps - ขั้นตอนถัดไป

1. **Test notifications**: Wait for next CI failure (automatic)
2. **Try AI analysis**: When failure occurs, run AI version
3. **Review logs**: Check failure logs are being saved
4. **Monitor performance**: Ensure agent stays running
5. **Customize**: Adjust interval or workflow filter if needed

---

**Status**: ✅ PRODUCTION READY & RUNNING
**Last Updated**: 2025-11-11 13:02
**Agent Version**: LaunchAgent (continuous monitoring)
**AI Version**: Available on-demand

**🎉 Setup Complete! Your GitHub Actions are now being monitored 24/7.**
