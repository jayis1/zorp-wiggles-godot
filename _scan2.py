import os, re
root = '.'
gd_files = []
for dp, dn, fn in os.walk(root):
    if '.git' in dp: continue
    for f in fn:
        if f.endswith('.gd'):
            gd_files.append(os.path.join(dp, f))

# Check for potential issues
issues = []

for path in gd_files:
    try:
        with open(path) as f: lines = f.readlines()
    except: continue
    fname = path.split('/')[-1]
    for i, line in enumerate(lines, 1):
        stripped = line.strip()
        # Check for get_first_node_in_group("player") without null guard on same/next line
        if 'get_first_node_in_group("player")' in stripped and 'is_instance_valid' not in stripped and 'if ' not in stripped and 'var ' not in stripped.split('=')[0]:
            # Check if next 2 lines have is_instance_valid guard
            ctx = ''.join(lines[i:i+3])
            if 'is_instance_valid' not in ctx and 'if not' not in ctx and '== null' not in ctx and 'if player' not in ctx:
                issues.append((fname, i, 'unguarded player ref', stripped[:80]))
        # Check for .connect without lambdas on signals that need args
        # Check for division by zero in HP ratio calcs
        if '/ max_hp' in stripped or '/max_hp' in stripped:
            if 'max_hp > 0' not in stripped and 'max_hp != 0' not in stripped and 'if max_hp' not in stripped and 'max_hp ==' not in stripped:
                # Look back for guard
                ctx_before = ''.join(lines[max(0,i-3):i])
                if 'max_hp > 0' not in ctx_before and 'max_hp != 0' not in ctx_before:
                    issues.append((fname, i, 'potential div by zero max_hp', stripped[:80]))
        # Check for Engine.time_scale without restore
        if 'Engine.time_scale' in stripped and '=' in stripped:
            issues.append((fname, i, 'time_scale set', stripped[:80]))

print(f'Potential issues: {len(issues)}')
for fn, ln, kind, txt in issues[:40]:
    print(f'  {fn}:{ln} [{kind}] {txt}')