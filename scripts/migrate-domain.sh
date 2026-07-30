#!/bin/bash
set -euo pipefail

AUTH="Authorization: Bearer ${CF_API_TOKEN:?CF_API_TOKEN not set}"
ACCT="${CF_ACCOUNT_ID:?CF_ACCOUNT_ID not set}"
BASE="https://api.cloudflare.com/client/v4/accounts/${ACCT}/pages/projects"

DOMAIN="rrxs.xyz"
TARGET="rrxs-xyz"

cd "$(dirname "$0")"

echo "============================================"
echo "  Domain Migration Script v3"
echo "  Target project: ${TARGET}"
echo "  Domain: ${DOMAIN}"
echo "============================================"

# Step 1: List all projects
echo ""
echo "=== Step 1: List all Pages projects ==="
curl -s -H "$AUTH" "${BASE}?per_page=20" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for p in data.get('result', []):
    print(f'  {p[\"name\"]}  subdomain: {p.get(\"subdomain\",\"?\")}')
"

# Step 2: For each project, check if domain exists
echo ""
echo "=== Step 2: Check which project has ${DOMAIN} ==="
OLD_PROJ=""
ALL_PROJS=$(curl -s -H "$AUTH" "${BASE}?per_page=20")
echo "$ALL_PROJS" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for p in data.get('result', []):
    name = p['name']
    print(f'--- {name} ---')
    import subprocess, urllib.request
"

while IFS= read -r line; do
    proj_name=$(echo "$line" | xargs)
    [ -z "$proj_name" ] && continue
    echo " "
    echo "--- Checking project: ${proj_name} ---"
    doms=$(curl -s -H "$AUTH" "${BASE}/${proj_name}/domains")
    has_domain=$(echo "$doms" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for d in data.get('result', []):
        if d['name'] == '${DOMAIN}':
            print(d['status'])
            sys.exit(0)
except: pass
print('NONE')
" 2>/dev/null || echo "NONE")
    echo "  Domain status: ${has_domain}"

    if [ "$has_domain" != "NONE" ]; then
        echo "  -> Found on project: ${proj_name} (status: ${has_domain})"
        OLD_PROJ="${proj_name}"
    fi
done < <(echo "$ALL_PROJS" | python3 -c "
import sys, json
for p in json.load(sys.stdin).get('result', []):
    print(p['name'])
" 2>/dev/null)

echo ""
echo "=== Step 3: Domain ownership ==="
echo "  Found on: ${OLD_PROJ:-NONE}"

if [ -z "$OLD_PROJ" ]; then
    echo "  -> Domain not on any project. Adding to ${TARGET}..."
    curl -s -X POST -H "$AUTH" "${BASE}/${TARGET}/domains" \
      -H "Content-Type: application/json" \
      -d "{\"name\":\"${DOMAIN}\"}" | python3 -c "
import sys, json
d = json.load(sys.stdin)
if d.get('success'):
    print(f\"  RESULT: success! domain_id={d['result'].get('id','?')} status={d['result'].get('status','?')}\")
else:
    print(f\"  RESULT: FAILED — {d.get('errors',[{}])[0].get('message','unknown error')}\")
"
elif [ "$OLD_PROJ" != "$TARGET" ]; then
    echo "  -> Domain on WRONG project: ${OLD_PROJ}. Deleting..."
    # Find domain ID
    dom_id=$(curl -s -H "$AUTH" "${BASE}/${OLD_PROJ}/domains" | python3 -c "
import sys, json
for d in json.load(sys.stdin).get('result', []):
    if d['name'] == '${DOMAIN}':
        print(d['id'])
" 2>/dev/null)
    if [ -n "$dom_id" ]; then
        echo "  Domain ID: ${dom_id}"
        del_res=$(curl -s -X DELETE -H "$AUTH" "${BASE}/${OLD_PROJ}/domains/${dom_id}")
        del_ok=$(echo "$del_res" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('success',False))" 2>/dev/null)
        echo "  Deleted from ${OLD_PROJ}: ${del_ok}"
    fi
    echo "  Adding to ${TARGET}..."
    curl -s -X POST -H "$AUTH" "${BASE}/${TARGET}/domains" \
      -H "Content-Type: application/json" \
      -d "{\"name\":\"${DOMAIN}\"}" | python3 -c "
import sys, json
d = json.load(sys.stdin)
if d.get('success'):
    print(f\"  RESULT: success! domain_id={d['result'].get('id','?')} status={d['result'].get('status','?')}\")
else:
    print(f\"  RESULT: FAILED — {d.get('errors',[{}])[0].get('message','unknown error')}\")
"
else
    echo "  -> Domain already on ${TARGET}"
    # Check if active
    status=$(curl -s -H "$AUTH" "${BASE}/${TARGET}/domains" | python3 -c "
import sys, json
for d in json.load(sys.stdin).get('result', []):
    if d['name'] == '${DOMAIN}':
        print(d['status'])
" 2>/dev/null)
    echo "  Domain status: ${status:-unknown}"
    if [ "${status}" = "active" ]; then
        echo "  Active — nothing to do."
    else
        echo "  NOT active — removing and re-adding..."
        dom_id=$(curl -s -H "$AUTH" "${BASE}/${TARGET}/domains" | python3 -c "
import sys, json
for d in json.load(sys.stdin).get('result', []):
    if d['name'] == '${DOMAIN}':
        print(d['id'])
" 2>/dev/null)
        if [ -n "$dom_id" ]; then
            curl -s -X DELETE -H "$AUTH" "${BASE}/${TARGET}/domains/${dom_id}" > /dev/null
            echo "  Removed. Re-adding..."
        fi
        curl -s -X POST -H "$AUTH" "${BASE}/${TARGET}/domains" \
          -H "Content-Type: application/json" \
          -d "{\"name\":\"${DOMAIN}\"}" | python3 -c "
import sys, json
d = json.load(sys.stdin)
if d.get('success'):
    print(f\"  RE-ADDED. id={d['result'].get('id','?')} status={d['result'].get('status','?')}\")
else:
    print(f\"  RE-ADD FAILED — {d.get('errors',[{}])[0].get('message','unknown error')}\")
"
    fi
fi

# Step 4: Verify
echo ""
echo "=== Step 4: Final verification ==="
domains_now=$(curl -s -H "$AUTH" "${BASE}/${TARGET}/domains" | python3 -c "
import sys, json
for d in json.load(sys.stdin).get('result', []):
    print(f'  {d[\"name\"]} — status: {d[\"status\"]}')
" 2>/dev/null || echo "  No domains found on ${TARGET}")
echo "${domains_now}"

echo ""
echo "=== Step 5: DNS check ==="
dns_ip=$(dig +short ${DOMAIN} A 2>/dev/null | tr '\n' ' ')
pages_ip=$(dig +short ${TARGET}.pages.dev A 2>/dev/null | tr '\n' ' ')
echo "  ${DOMAIN} => ${dns_ip:-no A record}"
echo "  ${TARGET}.pages.dev => ${pages_ip}"

echo ""
echo "=== DONE ==="
echo "  Check https://${DOMAIN} in a few minutes."
echo "  New content on: https://${TARGET}.pages.dev/"