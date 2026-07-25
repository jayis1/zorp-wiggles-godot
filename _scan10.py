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
gc_enums = {}

for path in gd_files:
    if path.endswith('game_constants.gd'):
        with open(path) as f: content = f.read()
        # Find const declarations
        for m in re.finditer(r'^\s*const\s+(\w+)', content, re.M):
            gc_constants.add(m.group(1))
        # Find enum values: enum Name { A, B, C } or enum { A, B, C }
        for m in re.finditer(r'enum\s+(\w*)\s*\{([^}]+)\}', content):
            enum_name = m.group(1)
            values = [v.strip().split('=')[0].strip() for v in m.group(2).split(',') if v.strip()]
            for v in values:
                gc_constants.add(v)  # enum values are accessed without enum prefix

print(f"Found {len(gc_constants)} constants/enum-values in game_constants.gd")

# Check GameConstants.X references where X is a single identifier (not method call)
all_refs = set()
for path in gd_files:
    if path.endswith('game_constants.gd'):
        continue
    try:
        with open(path) as f: content = f.read()
    except: continue
    # GameConstants.NAME where NAME is not followed by ( or .method
    for m in re.finditer(r'GameConstants\.(\w+)(?![.\(])', content):
        ref = m.group(1)
        # Skip common method-like refs
        if ref in ('get', 'has', 'size', 'keys', 'values', 'set', 'new', 'self'):
            continue
        all_refs.add((path.split('/')[-1], ref))

# Find missing
missing = set()
for fn, ref in all_refs:
    if ref not in gc_constants:
        # Check if it's an enum name reference (like Biome.GRASS accessed as GameConstants.Biome)
        # Need to check separately
        missing.add((fn, ref))

# Filter out enum-name references that ARE valid
enum_names = set()
for path in gd_files:
    if path.endswith('game_constants.gd'):
        with open(path) as f: content = f.read()
        for m in re.finditer(r'enum\s+(\w+)\s*\{', content):
            enum_names.add(m.group(1))

# Remove refs that are enum names (e.g., GameConstants.Biome.SOMETHING - the "Biome" part)
real_missing = set()
for fn, ref in missing:
    if ref not in enum_names:
        real_missing.add((fn, ref))

print(f"Potentially missing constants ({len(real_missing)}):")
for fn, ref in sorted(real_missing)[:20]:
    print(f"  {fn}: GameConstants.{ref}")