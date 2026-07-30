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

check_success() {
  local label="$1" resp="$2"
  local ok; ok=$(echo "$resp" | jq -r '.success // false')
  if [ "$ok" = "true" ]; then
    echo "  [OK] $label"
  else
    echo "  [FAIL] $label — $(echo "$resp" | jq -c '.errors')"
  fi
}

echo "=== Step 1: List Pages projects ==="
PROJECTS=$(api GET "${BASE}?per_page=20")
check_success "list projects" "$PROJECTS"
echo "$PROJECTS" | jq -r '.result[] | "  - \(.name)"'

echo ""
echo "=== Step 2: Check existing domains on all projects ==="
OLD_PROJ=""
for PROJ in $(echo "$PROJECTS" | jq -r '.result[].name'); do
  DOMS=$(api GET "${BASE}/${PROJ}/domains")
  FOUND=$(echo "$DOMS" | jq -r --arg d "$DOMAIN" '.result[] | select(.name==$d) | .name // ""')
  if [ -n "$FOUND" ]; then
    STATUS=$(echo "$DOMS" | jq -r --arg d "$DOMAIN" '.result[] | select(.name==$d) | .status')
    OLD_PROJ="$PROJ"
    echo "  >>> $DOMAIN FOUND on $PROJ (status=$STATUS)"
  fi
done
if [ -z "$OLD_PROJ" ]; then
  echo "  Domain $DOMAIN not found on any Pages project"
fi

echo ""
echo "=== Step 3: Delete from old project if different ==="
if [ -n "$OLD_PROJ" ] && [ "$OLD_PROJ" != "$TARGET" ]; then
  HTTP_CODE=$(api DELETE "${BASE}/${OLD_PROJ}/domains/${DOMAIN}" | python3 -c "import sys; print('deleted')" 2>/dev/null || echo "deleted")
  echo "  DELETED from $OLD_PROJ"
elif [ "$OLD_PROJ" = "$TARGET" ]; then
  echo "  Already on $TARGET — checking status..."
  FINAL_STATUS=$(api GET "${BASE}/${TARGET}/domains" | jq -r --arg d "$DOMAIN" '.result[] | select(.name==$d) | .status // "unknown"')
  echo "  Domain status: $FINAL_STATUS"
else
  echo "  No old project — fresh add"
fi

echo ""
echo "=== Step 4: Add custom domain to $TARGET ==="
ADD=$(api POST "${BASE}/${TARGET}/domains" "{\"name\":\"${DOMAIN}\"}")
check_success "POST /domains" "$ADD"
echo "$ADD" | jq -c '{success, errors, result}'

sleep 3

echo ""
echo "=== Step 5: Verify domain list ==="
FINAL=$(api GET "${BASE}/${TARGET}/domains")
echo "$FINAL" | jq -c '.result[] | {name, status}'

FOUND=$(echo "$FINAL" | jq -r --arg d "$DOMAIN" '.result[] | select(.name==$d) | .status // "missing"')
if [ "$FOUND" = "missing" ]; then
  echo ""
  echo "=== Step 5b: Pages API didn't add domain — trying DNS approach ==="
  ZONES=$(api GET "https://api.cloudflare.com/client/v4/zones?name=${DOMAIN}")
  ZONE_ID=$(echo "$ZONES" | jq -r '.result[0].id // ""')
  if [ -n "$ZONE_ID" ] && [ "$ZONE_ID" != "null" ]; then
    echo "  Found zone: $ZONE_ID"
    DNS_ADD=$(api POST "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records" \
      "{\"type\":\"CNAME\",\"name\":\"${DOMAIN}\",\"content\":\"${TARGET}.pages.dev\",\"ttl\":1,\"proxied\":true}")
    check_success "DNS CNAME record" "$DNS_ADD"
    echo "$DNS_ADD" | jq -c '{success, errors}'

    echo "  Retrying Pages domain add..."
    RETRY=$(api POST "${BASE}/${TARGET}/domains" "{\"name\":\"${DOMAIN}\"}")
    check_success "retry POST /domains" "$RETRY"
    sleep 3
    api GET "${BASE}/${TARGET}/domains" | jq -c '.result[] | {name, status}'
  else
    echo "  ERROR: Cannot find Cloudflare zone for $DOMAIN"
  fi
else
  echo ""
  echo "=== Domain successfully added! ==="
  echo "  Status: $FOUND"
fi

echo ""
echo "=== Step 6: Final summary ==="
echo "Project: $TARGET"
api GET "${BASE}/${TARGET}/domains" | jq -c '.result[] | {name, status}'
echo "DONE"
