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
    
    # Check for duplicate signal connections in _ready
    connects = []
    for i, line in enumerate(lines, 1):
        if '.connect(' in line and 'GameManager' in line:
            sig = re.search(r'GameManager\.(\w+)\.connect\(', line)
            if sig:
                connects.append((i, sig.group(1)))
    
    # Check for signal connects without lambdas that might have wrong arg counts
    for i, line in enumerate(lines, 1):
        m = re.search(r'(\w+\.(\w+))\.connect\(\s*"[^"]+"\s*,\s*Callable\(self,\s*"(\w+)"\)', line)
        if m:
            issues.append((fname, i, 'callable connect', line.strip()[:80]))
    
    # Check for .connect with string method name (old style, should use Callable)
    for i, line in enumerate(lines, 1):
        if '.connect("' in line and 'Callable' not in line:
            # Old style: signal.connect("method") - valid in Godot 4 but check
            pass
    
    # Check for queue_free() on self followed by code that accesses self
    for i, line in enumerate(lines, 1):
        if 'queue_free()' in line.strip() and i < len(lines):
            for j in range(i, min(i+5, len(lines))):
                nxt = lines[j-1].strip() if j-1 < len(lines) else ''
                if nxt and 'return' in nxt:
                    break
                if j > i and ('self.' in lines[j-1] or 'add_child' in lines[j-1]) and 'queue_free' not in lines[j-1]:
                    issues.append((fname, i, 'code after queue_free', f'{line.strip()[:40]} -> {lines[j-1].strip()[:40]}'))
                    break

print(f'Issues: {len(issues)}')
for fn, ln, kind, txt in issues[:30]:
    print(f'  {fn}:{ln} [{kind}] {txt}')