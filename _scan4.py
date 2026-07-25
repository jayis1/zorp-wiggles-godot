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
    fname = path.split('/')[-1]
    lines = content.split('\n')
    
    # Look for signal emits that don't match defined signals
    # Look for var declarations that are never used (within same file)
    for i, line in enumerate(lines, 1):
        m = re.match(r'\s*var\s+(\w+)', line)
        if m and 'func ' not in line:
            varname = m.group(1)
            if varname.startswith('_') and not re.search(r'\b' + re.escape(varname) + r'\b', content[content.find(line)+len(line):]):
                # Only flag unused private vars
                pass  # Too many false positives
    
    # Check for tween.tween_property on queue_free'd nodes
    # Check for create_tween() bound to self that outlives self
    
    # Look for duplicate function definitions
    func_defs = {}
    for i, line in enumerate(lines, 1):
        m = re.match(r'\s*(?:static\s+)?func\s+(\w+)', line)
        if m:
            fname2 = m.group(1)
            if fname2 in func_defs:
                issues.append((fname, i, 'duplicate func', f'{fname2} first at {func_defs[fname2]}'))
            else:
                func_defs[fname2] = i

print(f'Issues: {len(issues)}')
for fn, ln, kind, txt in issues[:20]:
    print(f'  {fn}:{ln} [{kind}] {txt}')