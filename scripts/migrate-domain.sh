#!/bin/bash
# migrate-domain.sh v5 — always nuke and re-add for clean state
set -uo pipefail

AUTH="Authorization: Bearer ${CF_API_TOKEN}"
ACCT="${CF_ACCOUNT_ID}"
BASE="https://api.cloudflare.com/client/v4/accounts/${ACCT}/pages/projects"
DOMAIN="rrxs.xyz"
TARGET="rrxs-xyz"

echo ""
echo "=== Step 1: List all Pages projects ==="
PROJS=$(curl -s -H "$AUTH" "${BASE}?per_page=20")
echo "$PROJS" | jq -r '.result[] | "  \(.name)  subdomain: \(.subdomain)"'

echo ""
echo "=== Step 2: Find ALL projects hosting ${DOMAIN} ==="
ALL_FOUND=""
while IFS= read -r proj; do
  [ -z "$proj" ] && continue
  DOMS=$(curl -s -H "$AUTH" "${BASE}/${proj}/domains")
  FOUND=$(echo "$DOMS" | jq -r --arg d "$DOMAIN" '.result[] | select(.name==$d) | "ID:\(.id)|STATUS:\(.status)"')
  if [ -n "$FOUND" ]; then
    echo "  -> ${proj}: ${FOUND}"
    ALL_FOUND="${ALL_FOUND} ${proj}:${FOUND}"
  else
    echo "  -> ${proj}: none"
  fi
done <<< "$(echo "$PROJS" | jq -r '.result[].name // empty')"

echo ""
echo "=== Step 3: Remove from ALL projects (including target) ==="
while IFS=' ' read -r entry; do
  [ -z "$entry" ] && continue
  proj_name=$(echo "$entry" | cut -d: -f1)
  # Extract ID from format: rrxs-xyz:ID:abc123|STATUS:active
  dom_id_s=$(echo "$entry" | sed 's/.*ID:\([^|]*\).*/\1/')
  echo "  Nuking domain ${dom_id_s} from ${proj_name}..."
  DEL=$(curl -s -X DELETE -H "$AUTH" "${BASE}/${proj_name}/domains/${dom_id_s}")
  echo "  Deleted from ${proj_name}: $(echo "$DEL" | jq -r '.success')"
done <<< "$ALL_FOUND"

echo ""
echo "=== Step 4: Add domain to ${TARGET} ==="
ADD=$(curl -s -X POST -H "$AUTH" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"${DOMAIN}\"}" \
  "${BASE}/${TARGET}/domains")
ADD_OK=$(echo "$ADD" | jq -r '.success')
ADD_MSG=$(echo "$ADD" | jq -r '.errors[0].message // "ok"')
echo "  Add result: success=${ADD_OK}  message=${ADD_MSG}"
if [ "$ADD_OK" != "true" ]; then
  echo "  [WARN] Adding domain failed — check token permissions"
fi

echo ""
echo "=== Step 5: Fix DNS records (add CNAME to pages.dev) ==="
echo "  Finding Zone ID for ${DOMAIN}..."

# Find zone ID
ZONES=$(curl -s -H "$AUTH" "https://api.cloudflare.com/client/v4/zones?name=${DOMAIN}")
ZONE_ID=$(echo "$ZONES" | jq -r '.result[0].id // "NONE"')
echo "  Zone ID: ${ZONE_ID}"

if [ "$ZONE_ID" != "NONE" ]; then
  # Delete existing A records for DOMAIN
  echo "  Checking existing DNS records..."
  EXISTING=$(curl -s -H "$AUTH" "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records?name=${DOMAIN}&type=A")
  EXISTING_COUNT=$(echo "$EXISTING" | jq -r '.result | length')
  if [ "$EXISTING_COUNT" -gt 0 ]; then
    echo "  Found ${EXISTING_COUNT} A record(s). Deleting..."
    echo "$EXISTING" | jq -r '.result[].id' | while IFS= read -r rec_id; do
      DEL_DNS=$(curl -s -X DELETE -H "$AUTH" "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records/${rec_id}")
      echo "  Deleted DNS record ${rec_id}: $(echo "$DEL_DNS" | jq -r '.success')"
    done
  fi

  # Check existing CNAME records
  EXISTING_CNAME=$(curl -s -H "$AUTH" "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records?name=${DOMAIN}&type=CNAME")
  CNAME_COUNT=$(echo "$EXISTING_CNAME" | jq -r '.result | length')
  if [ "$CNAME_COUNT" -gt 0 ]; then
    echo "  CNAME record(s) exist. Deleting old ones..."
    echo "$EXISTING_CNAME" | jq -r '.result[].id' | while IFS= read -r rec_id; do
      curl -s -X DELETE -H "$AUTH" "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records/${rec_id}" > /dev/null
    done
  fi

  # Add CNAME record
  echo "  Adding CNAME ${DOMAIN} -> ${TARGET}.pages.dev..."
  ADD_DNS=$(curl -s -X POST -H "$AUTH" \
    -H "Content-Type: application/json" \
    -d "{\"type\":\"CNAME\",\"name\":\"${DOMAIN}\",\"content\":\"${TARGET}.pages.dev\",\"ttl\":1,\"proxied\":true}" \
    "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records")
  DNS_OK=$(echo "$ADD_DNS" | jq -r '.success')
  DNS_MSG=$(echo "$ADD_DNS" | jq -r '.errors[0].message // "ok"')
  echo "  CNAME added: success=${DNS_OK}  message=${DNS_MSG}"
else
  echo "  [WARN] Could not find zone. Skipping DNS fix."
fi

echo ""
echo "=== Step 6: Verify domain on Pages project ===="
curl -s -H "$AUTH" "${BASE}/${TARGET}/domains" | jq -r '.result[] | "  \(.name) — status: \(.status)"'

echo ""
echo "=== Step 7: DNS check ===="
echo "  rrxs.xyz A: $(dig +short rrxs.xyz A 2>/dev/null | tr '\n' ' ')"
echo "  pages.dev A: $(dig +short ${TARGET}.pages.dev A 2>/dev/null | tr '\n' ' ')"

echo ""
echo "=== DONE ==="