#!/usr/bin/env python3
# usage: split.py <framework.jar apktool dir> <exclude-list file> [target_saved]
import os, re, sys, shutil, collections
root, exfile = sys.argv[1], sys.argv[2]
target = int(sys.argv[3]) if len(sys.argv) > 3 else 6000
src = os.path.join(root, "smali")
if not os.path.isdir(src):
    print("NO_SMALI"); sys.exit(0)
excl = set(l.strip() for l in open(exfile) if l.strip())
# Everything except classes needed very early in the boot/zygote path may be moved.
DENY = ("android/os/", "android/app/ActivityThread", "android/app/LoadedApk", "android/app/ContextImpl", "android/app/Application",
        "android/content/pm/", "android/content/res/", "android/util/", "android/system/", "android/text/",
        "com/android/internal/os/", "com/android/internal/util/", "com/android/internal/policy/", "android/view/View", "android/view/Surface",
        "android/view/Choreographer", "android/graphics/", "android/animation/", "android/widget/", "android/provider/", "android/database/")
def okmove(rel): return not rel.startswith(DENY)
inv = re.compile(r'^\s*invoke-(?!polymorphic|custom)\S+\s+\{[^}]*\},\s*(L[^;]+;)->(\S+?)\((.*?)\)(\S+)\s*$')
mth = re.compile(r'^\.method\s+.*?(\S+?)\((.*?)\)(\S+)\s*$')
files = {}
users = collections.Counter()
for dp, _, fns in os.walk(src):
    for fn in fns:
        if not fn.endswith(".smali"): continue
        p = os.path.join(dp, fn); rel = os.path.relpath(p, src)[:-6]
        ids = set(); cls = None
        with open(p, encoding="utf-8", errors="replace") as f:
            for line in f:
                if line.startswith(".class"):
                    m = re.search(r'(L[^;]+;)\s*$', line.rstrip()); cls = m.group(1) if m else None
                elif line.startswith(".method") and cls:
                    m = mth.match(line.rstrip())
                    if m: ids.add("%s->%s(%s)%s" % (cls, m.group(1), m.group(2), m.group(3)))
                elif "invoke-" in line:
                    m = inv.match(line.rstrip("\n"))
                    if m: ids.add("%s->%s(%s)%s" % m.groups())
        files[rel] = ids
        for i in ids: users[i] += 1
print("classes in smali:", len(files), " estimated method ids:", len(users))
def outer(rel): return rel.split("$")[0]
excl_outer = set(excl)
cands = []
for rel, ids in files.items():
    o = outer(rel)
    if o in excl_outer or not okmove(rel): continue
    # never move classes that contain static init-critical android core; prefixes above are conservative
    ex = sum(1 for i in ids if users[i] == 1)
    cands.append((ex, rel))
cands.sort(reverse=True)
# move outer + all its inner classes together
groups = collections.defaultdict(list)
for rel in files: groups[outer(rel)].append(rel)
chosen, saved, seen = [], 0, set()
for ex, rel in cands:
    o = outer(rel)
    if o in seen: continue
    seen.add(o)
    if o in excl_outer or not okmove(o): continue
    g = groups[o]
    chosen += g
    saved += sum(sum(1 for i in files[r] if users[i] == 1) for r in g)
    if saved >= target: break
print("moving", len(chosen), "classes, saving at least", saved, "method ids")
if saved < target: print("WARN_NOT_ENOUGH")
n = 2
while os.path.isdir(os.path.join(root, "smali_classes%d" % n)): n += 1
dst = os.path.join(root, "smali_classes%d" % n)
for rel in chosen:
    a = os.path.join(src, rel + ".smali"); b = os.path.join(dst, rel + ".smali")
    os.makedirs(os.path.dirname(b), exist_ok=True); shutil.move(a, b)
print("DST", dst)
