import os, re
root = '/root/zorp-wiggles-godot'
gd_files = []
for dp, dn, fn in os.walk(root):
    if '.git' in dp: continue
    for f in fn:
        if f.endswith('.gd'):
            gd_files.append(os.path.join(dp, f))

# Look for tween.kill() without checking validity
issues = []
for path in gd_files:
    try:
        with open(path) as f: content = f.read()
    except: continue
    fname = path.split('/')[-1]
    lines = content.split('\n')
    for i, line in enumerate(lines, 1):
        # Check for create_tween() result captured but never bound properly
        if 'create_tween()' in line and 'var ' in line and '=' in line:
            varname = line.split('=')[0].strip().split()[-1] if '=' in line else None
            if varname and not varname.endswith('_') and not varname.startswith('_'):
                pass  # many valid
        
        # Check for tween.tween_property on "self" that might fail when queue_free'd
        if 'tween_property(self' in line:
            issues.append((fname, i, 'tween on self (risk if queue_free)', line.strip()[:80]))
        
        # Check for .tween_property on a node fetched dynamically without guard
        if 'tween_property(' in line and 'get_' in line:
            issues.append((fname, i, 'tween on dynamic node', line.strip()[:80]))

print(f'Tween issues: {len(issues)}')
for fn, ln, kind, txt in issues[:30]:
    print(f'  {fn}:{ln} [{kind}] {txt}')

# Check for Engine.time_scale that isn't reset on game restart
print()
issues2 = []
restart_files = ['game_manager.gd']
for path in gd_files:
    try:
        with open(path) as f: content = f.read()
    except: continue
    fname = path.split('/')[-1]
    if fname == 'game_manager.gd':
        if 'Engine.time_scale' in content:
            lines = content.split('\n')
            for i, line in enumerate(lines, 1):
                if 'Engine.time_scale' in line:
                    issues2.append((fname, i, line.strip()[:80]))

print('Engine.time_scale in game_manager.gd:')
for fn, ln, txt in issues2:
    print(f'  {fn}:{ln} {txt}')