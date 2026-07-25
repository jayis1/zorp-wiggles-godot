import os, re
root = '/root/zorp-wiggles-godot'
gd_files = []
for dp, dn, fn in os.walk(root):
    if '.git' in dp: continue
    for f in fn:
        if f.endswith('.gd'):
            gd_files.append(os.path.join(dp, f))

# Find GameConstants.SOMETHING references and check they exist in game_constants.gd
issues = []
gc_constants = set()
gc_enums = {}

for path in gd_files:
    if path.endswith('game_constants.gd'):
        with open(path) as f: content = f.read()
        # Find const declarations
        for m in re.finditer(r'^\s*const\s+(\w+)', content, re.M):
            gc_constants.add(m.group(1))
        # Find enum values: enum Name { A, B, C }
        for m in re.finditer(r'enum\s+(\w+)\s*\{([^}]+)\}', content):
            enum_name = m.group(1)
            values = [v.strip().split('=')[0].strip() for v in m.group(2).split(',') if v.strip()]
            for v in values:
                gc_constants.add(f"{enum_name}.{v}")

print(f"Found {len(gc_constants)} constants in game_constants.gd")

# Now check all GameConstants.X references
all_refs = set()
for path in gd_files:
    if path.endswith('game_constants.gd'):
        continue
    try:
        with open(path) as f: content = f.read()
    except: continue
    for m in re.finditer(r'GameConstants\.(\w+(?:\.\w+)?)', content):
        all_refs.add(m.group(1))

missing = all_refs - gc_constants
print(f"Missing constants ({len(missing)}):")
for m in sorted(missing)[:30]:
    print(f"  GameConstants.{m}")