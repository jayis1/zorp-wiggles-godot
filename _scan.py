import os, re
root = '.'
gd_files = []
for dp, dn, fn in os.walk(root):
    if '.git' in dp: continue
    for f in fn:
        if f.endswith('.gd'):
            gd_files.append(os.path.join(dp, f))

issues = []
for path in gd_files:
    try:
        with open(path) as f: content = f.read()
    except: continue
    for m in re.finditer(r'"""', content):
        issues.append((path.split('/')[-1], 'triple-quote', content[max(0,m.start()-30):m.start()+50]))
    for m in re.finditer(r'time\.dt', content):
        issues.append((path.split('/')[-1], 'time.dt', ''))
    for m in re.finditer(r'held_keys', content):
        issues.append((path.split('/')[-1], 'held_keys', ''))
    for m in re.finditer(r'\.destroy\(\)', content):
        issues.append((path.split('/')[-1], '.destroy()', ''))

print(f'Python pattern issues: {len(issues)}')
for p, kind, ctx in issues[:30]:
    print(f'  {p}: {kind} {repr(ctx[:60])}')