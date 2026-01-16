#!/usr/bin/env zsh
apps=(
  "Raycast"
  "BetterTouchTool"
  "Rectangle"
  "CleanShot X"
  "Obsidian"
  "Notion"
  "Affinity Designer"
  "Affinity Photo"
  "Affinity Publisher"
  "Blender"
  "FreeCAD"
  "PDF Expert"
  "DEVONthink"
  "VS Code"
  "Docker"
  "RedisInsight"
  "Postman"
  "Tyme"
  "MoneyWiz"
)
echo "🔍 Checking installed apps..."
for app in $apps; do
  if [ -d "/Applications/$app.app" ]; then
    echo "✅ $app"
  else
    echo "❌ $app"
  fi
done
