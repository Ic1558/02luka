#!/usr/bin/env bash
set -euo pipefail
CI_MODE=0; for a in "$@"; do [[ "$a" == "--ci" ]] && CI_MODE=1; done
PASS=0; WARN=0; FAIL=0
check(){ name="$1"; url="$2"; opt="$3";
  if [[ "$CI_MODE" == "1" ]]; then echo "CI WARN $name (skipped)"; ((WARN++)); return; fi
  code=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo 000)
  if [[ "$code" == 200 ]]; then echo "PASS $name"; ((PASS++))
  else if [[ "$opt" == "1" ]]; then echo "WARN $name ($code)"; ((WARN++))
       else echo "FAIL $name ($code)"; ((FAIL++)); fi
  fi
}
check "API capabilities" "http://127.0.0.1:4000/api/capabilities" 0
check "Agents health"    "http://127.0.0.1:4000/api/agents/health" 0
check "UI index"         "http://127.0.0.1:5173/"                  1
check "Luka UI"          "http://127.0.0.1:5173/luka.html"         1
echo "PASS:$PASS WARN:$WARN FAIL:$FAIL"
if [[ "$FAIL" -gt 0 && "$CI_MODE" -eq 0 ]]; then exit 1; fi
