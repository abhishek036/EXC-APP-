import os, re, json

d = 'd:/COACHING APP/excellence'
patterns = [
    (r'AIza[0-9A-Za-z_-]{35}', 'Google/Firebase API Key'),
    (r'AAAA[A-Za-z0-9_-]{7}:[A-Za-z0-9_-]{140}', 'FCM Server Key'),
    (r'sk-[a-zA-Z0-9]{20,}', 'OpenAI/Stripe Secret Key'),
    (r'(?i)(api[_]?key|secret|token|password|private[_]?key)\s*[:=]\s*["\'][A-Za-z0-9_\-/.+]{12,}["\']', 'Generic secret assignment'),
]

skip_dirs = ['.dart_tool', 'build', '.git', 'android/.gradle', 'ios/Pods']
skip_files = {'firebase_options.dart'}

findings = []

for root, dirs, files in os.walk(d):
    dirs[:] = [dd for dd in dirs if not any(s in os.path.join(root, dd) for s in skip_dirs)]
    for f in files:
        if f in skip_files:
            continue
        ext = os.path.splitext(f)[1]
        if ext not in {'.dart', '.js', '.ts', '.json', '.env', '.yaml', '.yml', '.gradle', '.xml', '.plist', '.kt', '.swift'}:
            continue
        path = os.path.join(root, f)
        try:
            with open(path, 'r', encoding='utf-8', errors='ignore') as fh:
                for lineno, line in enumerate(fh, 1):
                    for pattern, label in patterns:
                        m = re.search(pattern, line)
                        if m:
                            rel = os.path.relpath(path, d)
                            findings.append({
                                'file': rel,
                                'line': lineno,
                                'label': label,
                                'match': m.group(0)[:80],
                                'content': line.strip()[:120]
                            })
        except Exception:
            pass

print(json.dumps(findings, indent=2))
