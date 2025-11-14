#!/usr/bin/env zsh
# CI Watcher Configuration Helper
# Usage: source tools/ci_watcher_config.zsh
# 
# This file is automatically sourced by LaunchAgent.
# Edit this file to change default settings for LaunchAgent runs.

# Set backoff cooldown (in minutes)
# Default: 15 minutes (prevents rerun spam)
# Change to 30 for less frequent reruns: export CI_WATCHER_BACKOFF_MINUTES=30
export CI_WATCHER_BACKOFF_MINUTES="${CI_WATCHER_BACKOFF_MINUTES:-15}"

# Enable/disable macOS notifications (1 = enabled, 0 = disabled)
# Default: enabled (shows notification when rerun completes)
# Disable: export CI_WATCHER_NOTIFICATIONS=0
export CI_WATCHER_NOTIFICATIONS="${CI_WATCHER_NOTIFICATIONS:-1}"

# Examples:
# export CI_WATCHER_BACKOFF_MINUTES=30  # 30 minutes cooldown
# export CI_WATCHER_NOTIFICATIONS=0      # Disable notifications
