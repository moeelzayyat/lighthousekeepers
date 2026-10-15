import json, os, sys, hashlib
a, b = sys.argv[1], sys.argv[2]
def walk(root):
    out = {}
    for d, _, fs in os.walk(root):
        for f in fs:
            if f == "default.project.json":
                continue
            p = os.path.join(d, f)
            out[os.path.relpath(p, root)] = p
    return out
A, B = walk(a), walk(b)
only_a = sorted(set(A) - set(B)); only_b = sorted(set(B) - set(A))
byte_diff = []; json_equal = []; json_real_diff = []; other_diff = []
for k in sorted(set(A) & set(B)):
    da = open(A[k], 'rb').read(); db = open(B[k], 'rb').read()
    if da == db:
        continue
    byte_diff.append(k)
    if k.endswith('.json'):
        try:
            ja = json.loads(da.decode('utf-8-sig')); jb = json.loads(db.decode('utf-8-sig'))
        except Exception as e:
            other_diff.append((k, 'parse error ' + str(e))); continue
        if json.dumps(ja, sort_keys=True) == json.dumps(jb, sort_keys=True):
            json_equal.append(k)
        else:
            json_real_diff.append(k)
    else:
        other_diff.append((k, 'non-json byte difference'))
print('files v148:', len(A), 'v149:', len(B))
print('only in v148:', only_a)
print('only in v149:', only_b)
print('byte-different files:', len(byte_diff))
print('  JSON-equal after key sorting (ordering only):', len(json_equal))
print('  JSON with real differences:', json_real_diff)
print('  other differences:', other_diff)
