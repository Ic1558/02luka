#!/usr/bin/env zsh
search_dirs=("/Applications" "$HOME/Applications")
apps=("Raycast" "BetterTouchTool" "Rectangle" "CleanShot" "Obsidian" "Notion"
      "Affinity" "Blender" "FreeCAD" "PDF Expert" "DEVONthink" 
      "Visual Studio Code" "Docker" "RedisInsight" "Postman" 
      "Tyme" "MoneyWiz")

echo "🔍 Checking installed apps (v2)..."
for app in $apps; do
  found=0
  for dir in $search_dirs; do
    if ls "$dir" 2>/dev/null | grep -i -q "$app"; then
      echo "✅ $app (found in $dir)"
      found=1
      break
    fi
  done
  if [ $found -eq 0 ]; then
    echo "❌ $app"
  fi
done
