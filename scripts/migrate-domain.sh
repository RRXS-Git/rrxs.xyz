#!/bin/bash
# migrate-domain.sh v4 — pure bash+curl+jq, no python embedding
set -uo pipefail

AUTH="Authorization: Bearer ***"
ACCT="${CF_ACCOUNT_ID}"
BASE="https://api.cloudflare.com/client/v4/accounts/${ACCT}/pages/projects"
DOMAIN="rrxs.xyz"
TARGET="rrxs-xyz"

echo ""
echo "=== Step 1: List all Pages projects ==="
PROJS=$(curl -s -H "$AUTH" "${BASE}?per_page=20")
echo "$PROJS" | jq -r '.result[] | "  \(.name)  subdomain: \(.subdomain)"'

echo ""
echo "=== Step 2: Find domain owner ==="
OLD_PROJ=""
OLD_ID=""
while IFS= read -r proj; do
  [ -z "$proj" ] && continue
  DOMS=$(curl -s -H "$AUTH" "${BASE}/${proj}/domains")
  FOUND=$(echo "$DOMS" | jq -r --arg d "$DOMAIN" '.result[] | select(.name==$d) | "\(.id)|\(.status)"')
  if [ -n "$FOUND" ]; then
    echo "  -> ${proj}: FOUND (${FOUND})"
    OLD_PROJ="$proj"
    OLD_ID=$(echo "$FOUND" | cut -d'|' -f1)
  else
    echo "  -> ${proj}: none"
  fi
done <<< "$(echo "$PROJS" | jq -r '.result[].name // empty')"

echo ""
echo "=== Step 3: Remove from old location ==="
if [ -z "$OLD_PROJ" ]; then
  echo "  Domain not on any project. Adding fresh..."
elif [ "$OLD_PROJ" != "$TARGET" ]; then
  echo "  Removing from ${OLD_PROJ} (id=${OLD_ID})..."
  DEL=$(curl -s -X DELETE -H "$AUTH" "${BASE}/${OLD_PROJ}/domains/${OLD_ID}")
  echo "  Deleted: $(echo "$DEL" | jq -r '.success')"
else
  echo "  Already on ${TARGET}."
fi

echo ""
echo "=== Step 4: Add to ${TARGET} ==="
if [ "$OLD_PROJ" != "$TARGET" ]; then
  ADD=$(curl -s -X POST -H "$AUTH" \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"${DOMAIN}\"}" \
    "${BASE}/${TARGET}/domains")
  echo "  Add result: $(echo "$ADD" | jq -r '.success')"
  echo "  Msg: $(echo "$ADD" | jq -r '.errors[0].message // "ok"')"
fi

echo ""
echo "=== Step 5: Final verification ==="
curl -s -H "$AUTH" "${BASE}/${TARGET}/domains" | jq -r '.result[] | "  \(.name) — status: \(.status)"'

echo ""
echo "=== Step 6: DNS ==="
echo "  rrxs.xyz: $(dig +short rrxs.xyz A | tr ' ' ',')"
echo "  pages.dev: $(dig +short ${TARGET}.pages.dev A | tr ' ' ',')"

echo ""
echo "=== DONE ==="