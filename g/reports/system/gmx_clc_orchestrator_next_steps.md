AGENTS=("shell-executor" "mary-bridge" "clc-worker")
typeset -A AGENT_STATUS_MAP

for agent in "${AGENTS[@]}"; do
    result=$(launchctl list 2>/dev/null | grep "$agent" || echo "")
    if [[ -n "$result" ]]; then
        pid=$(echo "$result" | awk '{print $1}')
        exit_code=$(echo "$result" | awk '{print $2}')
        
        if [[ "$pid" != "-" && "$exit_code" == "0" ]]; then
            echo "   ✅ $agent (PID: $pid)"
            add_check "agent_$agent" "healthy" "0" "Running"
            AGENT_STATUS_MAP["$agent"]="running"
        elif [[ "$pid" != "-" ]]; then
            echo "   ⚠️  $agent (PID: $pid, last exit: $exit_code)"
            add_check "agent_$agent" "warning" "0" "Exit code $exit_code"
            AGENT_STATUS_MAP["$agent"]="warning"
        else
            echo "   ❌ $agent (not running, last exit: $exit_code)"
            add_check "agent_$agent" "critical" "0" "Not running"
            AGENT_STATUS_MAP["$agent"]="stopped"
            
            # Auto-restart hook (disabled by default)
            if $AUTO_RESTART_ENABLED; then
                echo "   🔄 Auto-restarting $agent..."
                launchctl start "com.02luka.$agent" 2>/dev/null
            fi
        fi
    else
        echo "   ⚪ $agent (not loaded)"
        add_check "agent_$agent" "critical" "0" "Not loaded"
        AGENT_STATUS_MAP["$agent"]="not_loaded"
    fi
done

  "agents": {
    "shell_executor": "${AGENT_STATUS_MAP["shell-executor"]:-unknown}",
    "mary_bridge": "${AGENT_STATUS_MAP["mary-bridge"]:-unknown}",
    "clc_worker": "${AGENT_STATUS_MAP["clc-worker"]:-unknown}"
  }
