import os, re
root = '/root/zorp-wiggles-godot'
gd_files = []
for dp, dn, fn in os.walk(root):
    if '.git' in dp: continue
    for f in fn:
        if f.endswith('.gd'):
            gd_files.append(os.path.join(dp, f))

# Look for get_tree().change_scene_to_file vs SceneTransition
issues = []
for path in gd_files:
    try:
        with open(path) as f: content = f.read()
    except: continue
    fname = path.split('/')[-1]
    lines = content.split('\n')
    for i, line in enumerate(lines, 1):
        if 'change_scene_to_file' in line and 'SceneTransition' not in line:
            issues.append((fname, i, 'direct scene change (should use SceneTransition)', line.strip()[:80]))
        if 'change_scene_to_packed' in line and 'SceneTransition' not in line:
            issues.append((fname, i, 'direct scene change (should use SceneTransition)', line.strip()[:80]))

print(f'Direct scene change (not via SceneTransition): {len(issues)}')
for fn, ln, kind, txt in issues[:20]:
    print(f'  {fn}:{ln} [{kind}] {txt}')

# Look for naked get_tree().reload_current_scene()
print()
issues2 = []
for path in gd_files:
    try:
        with open(path) as f: content = f.read()
    except: continue
    fname = path.split('/')[-1]
    lines = content.split('\n')
    for i, line in enumerate(lines, 1):
        if 'reload_current_scene' in line and 'SceneTransition' not in line:
            issues2.append((fname, i, line.strip()[:80]))

print(f'Naked reload_current_scene: {len(issues2)}')
for fn, ln, txt in issues2[:10]:
    print(f'  {fn}:{ln} {txt}')