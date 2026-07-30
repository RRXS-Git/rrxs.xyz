#!/usr/bin/env python3
"""Migrate custom domain rrxs.xyz to rrxs-xyz Cloudflare Pages project."""
import urllib.request, urllib.error, json, os, sys

bt = f'Bearer {os.environ["CF_API_TOKEN"]}'
acct = os.environ["CF_ACCOUNT_ID"]
base = f'https://api.cloudflare.com/client/v4/accounts/{acct}/pages/projects'

# Step 1: Scan all projects
print("=== Step 1: Scan all projects for rrxs.xyz domain ===")
try:
    pr = json.load(urllib.request.urlopen(urllib.request.Request(f'{base}?per_page=50', headers={'Authorization': bt})))
except Exception as e:
    print(f'FATAL: cannot list projects: {type(e).__name__}: {e}')
    sys.exit(1)
projects = pr.get('result', [])
print(f'Total projects: {len(projects)}')
old_project = None
for p in projects:
    name = p['name']
    cd = p.get('canonical_deployment')
    ld = p.get('latest_deployment')
    cd_branch = (cd.get('deployment_trigger',{}).get('branch','?') if cd else '-')
    ld_branch = (ld.get('deployment_trigger',{}).get('branch','?') if ld else '-')
    try:
        dr = json.load(urllib.request.urlopen(urllib.request.Request(f'{base}/{name}/domains', headers={'Authorization': bt})))
        for dd in dr.get('result', []):
            dn = dd.get('name','')
            if dn == 'rrxs.xyz':
                old_project = name
                print(f'  >>> rrxs.xyz FOUND on project: {name}')
    except urllib.error.HTTPError as e:
        print(f'  {name}: HTTP {e.code}')
    except Exception as e:
        print(f'  {name}: {type(e).__name__}')
    print(f'  {name}: canonical_branch={cd_branch} latest_branch={ld_branch}')

# Step 2: Delete from old project
if old_project and old_project != 'rrxs-xyz':
    print(f'\n### Step 2: DELETE rrxs.xyz from old project "{old_project}" ###')
    try:
        req = urllib.request.Request(f'{base}/{old_project}/domains/rrxs.xyz', method='DELETE', headers={'Authorization': bt})
        d = json.load(urllib.request.urlopen(req))
        print(f'DELETE result: success={d.get("success")}')
    except urllib.error.HTTPError as e:
        print(f'DELETE HTTP {e.code}: {e.read().decode()}')

elif old_project == 'rrxs-xyz':
    print(f'\n### Domain already on rrxs-xyz, skip delete ###')
else:
    print(f'\n### Domain not on any project, skip delete ###')

# Step 3: Add to rrxs-xyz
print(f'\n### Step 3: POST rrxs.xyz to rrxs-xyz ###')
try:
    data = json.dumps({'name':'rrxs.xyz'}).encode()
    req = urllib.request.Request(f'{base}/rrxs-xyz/domains', data=data, method='POST', headers={'Authorization': bt, 'Content-Type': 'application/json'})
    result = json.load(urllib.request.urlopen(req))
    print(f'POST result: success={result.get("success")}')
    if result.get('errors'):
        for err in result['errors']:
            print(f'  error: {err}')
except urllib.error.HTTPError as e:
    print(f'POST HTTP {e.code}: {e.read().decode()}')

# Step 4: Check deployments
print(f'\n### Step 4: Check deployments ###')
try:
    dr = json.load(urllib.request.urlopen(urllib.request.Request(f'{base}/rrxs-xyz/deployments?per_page=5', headers={'Authorization': bt})))
    for dep in dr.get('result', [])[:5]:
        did = dep.get('id','?')
        created = dep.get('created_on','?')
        stage = dep.get('stage','?')
        branch = dep.get('deployment_trigger',{}).get('branch','?')
        canonical = dep.get('is_canonical', False)
        print(f'  {str(did)[:12]}: created={created} stage={stage} branch={branch} canonical={canonical}')
except Exception as e:
    print(f'Deployment check error: {type(e).__name__}: {e}')

# Step 5: Verify domains
print(f'\n### Step 5: Verify domains on rrxs-xyz ###')
try:
    dr = json.load(urllib.request.urlopen(urllib.request.Request(f'{base}/rrxs-xyz/domains', headers={'Authorization': bt})))
    for dd in dr.get('result', []):
        print(f'  {dd.get("name")} status={dd.get("status")}')
except Exception as e:
    print(f'Domain check error: {type(e).__name__}: {e}')
