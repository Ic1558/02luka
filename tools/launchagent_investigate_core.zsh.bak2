#!/usr/bin/env zsh
# Core Services Investigation Script
# Checks the 7 high-priority LaunchAgents for common issues
set -euo pipefail

BASE="$HOME/02luka"
CORE_SERVICES=(
  com.02luka.health_monitor
  com.02luka.health_server
  com.02luka.hub-autoindex
  com.02luka.mls.ledger.monitor
  com.02luka.memory.bridge
  com.02luka.memory.hub
  com.02luka.rag.autosync
)

echo "🔍 Investigating Core LaunchAgents (7 services)"
echo "================================================"
echo ""

for service in "${CORE_SERVICES[@]}"; do
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "📋 Service: $service"
  echo ""
  
  # Check launchctl status
  exit_code=$(launchctl list | grep "^[[:space:]]*[0-9]*[[:space:]]*[0-9]*[[:space:]]*$service" | awk '{print $2}' || echo "N/A")
  echo "  Status: Exit code $exit_code"
  
  # Check plist exists
  plist="$HOME/Library/LaunchAgents/${service}.plist"
  if [[ -f "$plist" ]]; then
    echo "  ✅ Plist exists: $plist"
    
    # Extract script path
    script_path=$(plutil -extract ProgramArguments.1 raw "$plist" 2>/dev/null || echo "")
    if [[ -n "$script_path" ]]; then
      echo "  Script: $script_path"
      
      # Check for old path
      if grep -q "/Users/icmini/LocalProjects/02luka_local_g/" "$plist"; then
        echo "  ⚠️  OLD PATH DETECTED (needs update)"
      fi
      
      # Check if script exists
      if [[ -f "$script_path" ]]; then
        echo "  ✅ Script file exists"
        if [[ -x "$script_path" ]]; then
          echo "  ✅ Script is executable"
        else
          echo "  ⚠️  Script NOT executable (chmod +x needed)"
        fi
      else
        echo "  ❌ Script file MISSING: $script_path"
      fi
    else
      echo "  ⚠️  Could not extract script path from plist"
    fi
    
    # Check log paths
    stdout_log=$(plutil -extract StandardOutPath raw "$plist" 2>/dev/null || echo "")
    if [[ -n "$stdout_log" ]]; then
      log_dir=$(dirname "$stdout_log")
      if [[ -d "$(dirname "$stdout_log")" ]]; then
        echo "  ✅ Log directory exists: $(dirname "$stdout_log")"
      else
        echo "  ⚠️  Log directory missing: $(dirname "$stdout_log")"
      fi
    fi
  else
    echo "  ❌ Plist NOT FOUND: $plist"
  fi
  
  # Check recent logs (if available)
  log_file="$BASE/logs/${service}.log"
  if [[ -f "$log_file" ]]; then
    last_error=$(tail -20 "$log_file" | grep -i "error\|fail" | tail -1 || echo "")
    if [[ -n "$last_error" ]]; then
      echo "  ⚠️  Recent error in log: ${last_error:0:60}..."
    else
      echo "  ℹ️  Log exists, no recent errors"
    fi
  fi
  
  echo ""
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📊 Summary Questions for Each Service:"
echo "  1. Still needed in current architecture? (Y/N/DEFER)"
echo "  2. If yes: Path/script exists and config correct? (Y/N)"
echo "  3. If no: Remove or archive? (REMOVE/ARCHIVE)"
echo ""
echo "👉 Next: Review output above and update Phase 2 STATUS"
