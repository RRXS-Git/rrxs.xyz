#!/bin/bash
# migrate-domain.sh — add rrxs.xyz as custom domain on rrxs-xyz Pages project
set -euo pipefail

AUTH="Authorization: Bearer ${CF_API_TOKEN:?CF_API_TOKEN not set}"
ACCT="${CF_ACCOUNT_ID:?CF_ACCOUNT_ID not set}"
BASE="https://api.cloudflare.com/client/v4/accounts/${ACCT}/pages/projects"
TARGET="rrxs-xyz"
DOMAIN="rrxs.xyz"

api() {
  local method="$1" url="$2" data="${3:-}"
  if [ -n "$data" ]; then
    curl -s -X "$method" -H "$AUTH" -H "Content-Type: application/json" -d "$data" "$url"
  else
    curl -s -X "$method" -H "$AUTH" "$url"
  fi
}

# Safely extract from JSON — returns empty if jq fails or result missing
safe_jq() {
  local filter="$1" json="$2"
  local result; result=$(echo "$json" | jq -r "$filter // \"\"" 2>/dev/null) || true
  echo "$result"
}

echo "=== Step 1: List Pages projects ==="
PROJECTS=$(api GET "${BASE}?per_page=20")
SUCCESS=$(safe_jq '.success // false' "$PROJECTS")
echo "  API success: $SUCCESS"
safe_jq '.result[] | "  - \(.name)"' "$PROJECTS" | while read -r line; do echo "$line"; done
echo ""

DOMAINS=$(safe_jq '.result' "$PROJECTS")
echo "=== Step 2: Check domains on all projects ==="
OLD_PROJ=""
for PROJ in $(safe_jq '.result[].name // ""' "$PROJECTS"); do
  [ -z "$PROJ" ] && continue
  DOMS=$(api GET "${BASE}/${PROJ}/domains")
  FOUND=$(safe_jq --arg d "$DOMAIN" '.result[] | select(.name==$d) | .name // ""' "$DOMS")
  if [ -n "$FOUND" ]; then
    STATUS=$(safe_jq --arg d "$DOMAIN" '.result[] | select(.name==$d) | .status // "unknown"' "$DOMS")
    OLD_PROJ="$PROJ"
    echo "  >>> $DOMAIN FOUND on $PROJ (status=$STATUS)"
  else
    COUNT=$(safe_jq '.result | length // 0' "$DOMS")
    echo "  $PROJ: $COUNT domains"
  fi
done
if [ -z "$OLD_PROJ" ]; then
  echo "  Domain not found on any Pages project"
fi
echo ""

echo "=== Step 3: Delete from old if needed ==="
if [ -n "$OLD_PROJ" ] && [ "$OLD_PROJ" != "$TARGET" ]; then
  echo "  Deleting $DOMAIN from $OLD_PROJ..."
  api DELETE "${BASE}/${OLD_PROJ}/domains/${DOMAIN}" > /dev/null 2>&1 || true
  echo "  Deleted"
elif [ "$OLD_PROJ" = "$TARGET" ]; then
  echo "  Already on $TARGET — checking status..."
  FINAL_STATUS=$(safe_jq --arg d "$DOMAIN" '.result[] | select(.name==$d) | .status // "unknown"' "$DOMS")
  echo "  Domain status: $FINAL_STATUS"
  if [ "$FINAL_STATUS" = "active" ]; then
    echo "  ✅ Domain already active — nothing to do!"
    echo "DONE"
    exit 0
  fi
  echo "  Status is $FINAL_STATUS — proceeding"
else
  echo "  Fresh add"
fi
echo ""

echo "=== Step 4: Add custom domain ==="
ADD=$(api POST "${BASE}/${TARGET}/domains" "{\"name\":\"${DOMAIN}\"}")
ADD_OK=$(safe_jq '.success // false' "$ADD")
echo "  POST /domains success: $ADD_OK"
safe_jq '{success, errors, result}' "$ADD" | head -c 500
echo ""
sleep 3
echo ""

echo "=== Step 5: Verify ==="
FINAL=$(api GET "${BASE}/${TARGET}/domains")
FOUND_STATUS=$(safe_jq --arg d "$DOMAIN" '.result[] | select(.name==$d) | .status // "missing"' "$FINAL")
echo "  Domain status: $FOUND_STATUS"
safe_jq '.result[] | {name, status}' "$FINAL"

if [ "$FOUND_STATUS" = "missing" ]; then
  echo ""
  echo "=== Step 5b: Fallback — DNS API ==="
  ZONES=$(api GET "https://api.cloudflare.com/client/v4/zones?name=${DOMAIN}")
  ZONE_ID=$(safe_jq '.result[0].id // ""' "$ZONES")
  if [ -n "$ZONE_ID" ]; then
    echo "  Zone ID: $ZONE_ID"
    DNS_ADD=$(api POST "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records" \
      "{\"type\":\"CNAME\",\"name\":\"${DOMAIN}\",\"content\":\"${TARGET}.pages.dev\",\"ttl\":1,\"proxied\":true}")
    DNS_OK=$(safe_jq '.success // false' "$DNS_ADD")
    echo "  DNS CNAME success: $DNS_OK"
    safe_jq '{success, errors}' "$DNS_ADD"

    echo "  Retrying Pages domain add..."
    RETRY=$(api POST "${BASE}/${TARGET}/domains" "{\"name\":\"${DOMAIN}\"}")
    echo "  Retry: $(safe_jq '{success, errors}' "$RETRY")"
    sleep 3
    api GET "${BASE}/${TARGET}/domains" | jq -c '.result[] | {name, status}' 2>/dev/null || echo "  (no domains)"
  else
    echo "  ERROR: Cannot find zone"
  fi
fi
echo ""
echo "=== Step 6: Final ==="
safe_jq '.result[] | {name, status}' "$(api GET "${BASE}/${TARGET}/domains")"
echo "DONE"
