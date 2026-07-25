import os, re
root = '/root/zorp-wiggles-godot'
gd_files = []
for dp, dn, fn in os.walk(root):
    if '.git' in dp: continue
    for f in fn:
        if f.endswith('.gd'):
            gd_files.append(os.path.join(dp, f))

# Read game_constants.gd and extract all top-level identifiers
gc_constants = set()
enum_names = set()

for path in gd_files:
    if path.endswith('game_constants.gd'):
        with open(path) as f: content = f.read()
        for m in re.finditer(r'^\s*const\s+(\w+)', content, re.M):
            gc_constants.add(m.group(1))
        for m in re.finditer(r'enum\s+(\w*)\s*\{([^}]+)\}', content):
            enum_name = m.group(1)
            if enum_name:
                enum_names.add(enum_name)
            values = [v.strip().split('=')[0].strip() for v in m.group(2).split(',') if v.strip()]
            for v in values:
                gc_constants.add(v)

print(f"Found {len(gc_constants)} constants/enum-values, {len(enum_names)} enum names")

# Now check references: GameConstants.SOMETHING (just the first level)
# Use word boundary
all_refs = set()
for path in gd_files:
    if path.endswith('game_constants.gd'):
        continue
    try:
        with open(path) as f: content = f.read()
    except: continue
    # Match GameConstants.WordBoundary — capture the identifier after the dot
    # that is followed by . or non-word char
    for m in re.finditer(r'GameConstants\.([A-Z_][A-Z0-9_]*)(?![A-Za-z0-9_])', content):
        ref = m.group(1)
        all_refs.add((path.split('/')[-1], ref))
    # Also match GameConstants.EnumName (CamelCase)
    for m in re.finditer(r'GameConstants\.([A-Z][a-z]\w*)(?![A-Za-z0-9_])', content):
        ref = m.group(1)
        all_refs.add((path.split('/')[-1], ref))

missing = set()
for fn, ref in all_refs:
    if ref not in gc_constants and ref not in enum_names:
        missing.add((fn, ref))

print(f"Missing constants ({len(missing)}):")
for fn, ref in sorted(missing)[:30]:
    print(f"  {fn}: GameConstants.{ref}")