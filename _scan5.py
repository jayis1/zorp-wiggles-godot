import os, re
root = '/root/zorp-wiggles-godot'
gd_files = []
for dp, dn, fn in os.walk(root):
    if '.git' in dp: continue
    for f in fn:
        if f.endswith('.gd'):
            gd_files.append(os.path.join(dp, f))

issues = []

# Look for signal emit with wrong arg count vs definition
for path in gd_files:
    try:
        with open(path) as f: content = f.read()
    except: continue
    fname = path.split('/')[-1]
    lines = content.split('\n')
    
    # Find signal definitions
    signals = {}
    for i, line in enumerate(lines, 1):
        m = re.match(r'\s*signal\s+(\w+)\s*(\(.*\))?', line)
        if m:
            sname = m.group(1)
            args_str = (m.group(2) or '()')[1:-1].strip()
            arg_count = len([a for a in args_str.split(',') if a.strip()]) if args_str else 0
            signals[sname] = arg_count
    
    # Find signal emits and check arg count
    for i, line in enumerate(lines, 1):
        m = re.search(r'(\w+)\.emit\(([^)]*)\)', line)
        if m:
            sname = m.group(1)
            args_str = m.group(2).strip()
            # Count args (naive - doesn't handle nested parens perfectly)
            if args_str:
                arg_count = len([a for a in args_str.split(',') if a.strip()])
            else:
                arg_count = 0
            if sname in signals:
                expected = signals[sname]
                if arg_count != expected:
                    issues.append((fname, i, f'signal {sname} expects {expected} args, got {arg_count}', line.strip()[:80]))

print(f'Signal arg mismatches: {len(issues)}')
for fn, ln, kind, txt in issues[:30]:
    print(f'  {fn}:{ln} [{kind}] {txt}')