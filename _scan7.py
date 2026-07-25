import os, re
root = '/root/zorp-wiggles-godot'
gd_files = []
for dp, dn, fn in os.walk(root):
    if '.git' in dp: continue
    for f in fn:
        if f.endswith('.gd'):
            gd_files.append(os.path.join(dp, f))

# Look for potential null dereference: .global_position on result of get_first_node_in_group
issues = []
for path in gd_files:
    try:
        with open(path) as f: content = f.read()
    except: continue
    fname = path.split('/')[-1]
    lines = content.split('\n')
    
    # Check for .connect to a method that doesn't exist in the same file
    for i, line in enumerate(lines, 1):
        m = re.search(r'\.connect\(\s*Callable\(self,\s*"(\w+)"\)', line)
        if m:
            method = m.group(1)
            if not re.search(r'func\s+' + re.escape(method) + r'\b', content):
                issues.append((fname, i, 'connect to missing method', f'{method}: {line.strip()[:60]}'))
    
    # Check for .connect("signal", Callable(self, "method")) old style
    for i, line in enumerate(lines, 1):
        m = re.search(r'\.connect\(\s*"(\w+)"\s*,\s*Callable\(self,\s*"(\w+)"\)', line)
        if m:
            method = m.group(2)
            if not re.search(r'func\s+' + re.escape(method) + r'\b', content):
                issues.append((fname, i, 'connect to missing method', f'{method}: {line.strip()[:60]}'))

print(f'Connect to missing methods: {len(issues)}')
for fn, ln, kind, txt in issues[:30]:
    print(f'  {fn}:{ln} [{kind}] {txt}')