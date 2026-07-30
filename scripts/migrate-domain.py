#!/usr/bin/env python3
"""Migrate custom domain rrxs.xyz to rrxs-xyz Cloudflare Pages project."""
import urllib.request, urllib.error, json, os, sys

bt = f'Bearer {os.environ["CF_API_TOKEN"]}'
acct = os.environ["CF_ACCOUNT_ID"]
base = f'https://api.cloudflare.com/client/v4/accounts/{acct}/pages/projects'

def api(method, url, data=None):
    req = urllib.request.Request(url, data=data, method=method, headers={'Authorization': bt})
    if data:
        req.add_header('Content-Type', 'application/json')
    try:
        resp = urllib.request.urlopen(req)
        body = resp.read()
        if body:
            return json.loads(body)
        return {'success': True, 'status_code': resp.status}
    except urllib.error.HTTPError as e:
        body = e.read()
        try:
            return {'success': False, 'status_code': e.code, 'errors': json.loads(body).get('errors', str(body))}
        except Exception:
            return {'success': False, 'status_code': e.code, 'errors': str(body)}

# Step 1: List all projects
print("=== Step 1: Scan all projects for rrxs.xyz domain ===")
r = api('GET', f'{base}?per_page=50')
if not r.get('success'):
    print(f'FATAL: {r}')
    sys.exit(1)
projects = r.get('result', [])
print(f'Total projects: {len(projects)}')
old_project = None
for p in projects:
    name = p['name']
    cd = p.get('canonical_deployment')
    ld = p.get('latest_deployment')
    cd_branch = (cd.get('deployment_trigger',{}).get('branch','?') if cd else '-')
    ld_branch = (ld.get('deployment_trigger',{}).get('branch','?') if ld else '-')
    dr = api('GET', f'{base}/{name}/domains')
    for dd in dr.get('result', []):
        if dd.get('name') == 'rrxs.xyz':
            old_project = name
            print(f'  >>> rrxs.xyz FOUND on project: {name}')
    print(f'  {name}: canonical_branch={cd_branch} latest_branch={ld_branch}')

# Step 2: Delete from old project
if old_project and old_project != 'rrxs-xyz':
    print(f'\n### Step 2: DELETE rrxs.xyz from old project "{old_project}" ###')
    r = api('DELETE', f'{base}/{old_project}/domains/rrxs.xyz')
    print(f'DELETE result: success={r.get("success")} status={r.get("status_code")}')
elif old_project == 'rrxs-xyz':
    print(f'\n### Domain already on rrxs-xyz, skip delete ###')
else:
    print(f'\n### Domain not found on any project, skip delete ###')

# Step 3: POST to rrxs-xyz (only if not already there)
print(f'\n### Step 3: POST rrxs.xyz to rrxs-xyz ###')
if old_project != 'rrxs-xyz':
    data = json.dumps({'name':'rrxs.xyz'}).encode()
    r = api('POST', f'{base}/rrxs-xyz/domains', data=data)
    print(f'POST result: success={r.get("success")} status={r.get("status_code")}')
    if r.get('errors'):
        for err in r.get('errors', []):
            print(f'  error: {err}')
else:
    print(f'  (already attached, skip)')

# Step 4: Check deployments
print(f'\n### Step 4: Check deployments ###')
r = api('GET', f'{base}/rrxs-xyz/deployments?per_page=5')
for dep in r.get('result', [])[:5]:
    did = dep.get('id','?')
    print(f'  {str(did)[:12]}: stage={dep.get("stage","?")} branch={dep.get("deployment_trigger",{}).get("branch","?")} canonical={dep.get("is_canonical",False)}')

# Step 5: Verify domains on rrxs-xyz
print(f'\n### Step 5: Domains on rrxs-xyz ###')
r = api('GET', f'{base}/rrxs-xyz/domains')
for dd in r.get('result', []):
    print(f'  {dd.get("name")} status={dd.get("status")}')

print('\n=== DONE ===')
