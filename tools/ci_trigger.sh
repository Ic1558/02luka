#!/usr/bin/env bash
set -euo pipefail

ROOT="${HOME}/02luka"
REPO="${REPO:-${ROOT}}"
BRANCH="${BRANCH:-main}"
WATCH_FILE="tools/test_browseros_phase77.sh"   # tweak if needed
FLAG="${REPO}/g/governance/ci_trigger.ok"
RATE_LOCK="${REPO}/g/governance/.ci_trigger.lock"
RATE_SECONDS="${RATE_SECONDS:-120}"            # min interval

echo "[ci-trigger] repo=${REPO} branch=${BRANCH}"

test -f "${FLAG}" || { echo "[ci-trigger] flag missing: ${FLAG}"; exit 0; }

now=$(date +%s)
if [ -f "${RATE_LOCK}" ]; then
  then_ts=$(cat "${RATE_LOCK}" || echo 0)
  diff=$(( now - then_ts ))
  if [ "${diff}" -lt "${RATE_SECONDS}" ]; then
    echo "[ci-trigger] rate-limited (${diff}s < ${RATE_SECONDS}s)"; exit 0;
  fi
fi
echo "${now}" > "${RATE_LOCK}"

cd "${REPO}"
git fetch origin "${BRANCH}" --quiet || true
git checkout "${BRANCH}" --quiet
git reset --hard "origin/${BRANCH}" --quiet

# Safety: Only run for owner repo
OWNER="$(git config --get remote.origin.url | sed -E 's#.*[:/](.+)/.+\.git#\1#')"
[ "${OWNER}" = "Ic1558" ] || { echo "[ci-trigger] skip: owner=${OWNER}"; exit 0; }

mkdir -p "$(dirname "${WATCH_FILE}")"
touch "${WATCH_FILE}"
echo "# ci: trigger $(date -Iseconds)" >> "${WATCH_FILE}"

git add "${WATCH_FILE}"
git -c user.name="ci-trigger" -c user.email="ci@02luka.local" \
  commit -m "ci: auto-trigger workflow (${WATCH_FILE})" || { echo "[ci-trigger] no changes"; exit 0; }

git push origin "${BRANCH}"

echo "[ci-trigger] pushed. done."
