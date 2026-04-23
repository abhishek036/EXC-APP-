import os, re, json

d = 'd:/COACHING APP/excellence/lib'
findings = []

for root, dirs, files in os.walk(d):
    dirs[:] = [dd for dd in dirs if dd not in {'.dart_tool', 'build'}]
    for f in files:
        if not f.endswith('.dart'):
            continue
        path = os.path.join(root, f)
        try:
            content = open(path, 'r', encoding='utf-8', errors='ignore').read()
            lines = content.splitlines()
            for lineno, line in enumerate(lines, 1):
                stripped = line.strip()
                # Detect hardcoded Firebase config fields
                if re.search(r'(projectId|storageBucket|appId|measurementId|messagingSenderId)\s*[:=]\s*["\'`][^"\'`]+["\'`]', stripped):
                    findings.append({'file': os.path.relpath(path, d), 'line': lineno, 'content': stripped[:130]})
                # Detect raw string literals that look like keys (long alphanum strings 32+ chars)
                m = re.search(r'["\'`]([A-Za-z0-9+/_-]{32,})["\'`]', stripped)
                if m:
                    val = m.group(1)
                    # exclude common false positives
                    ignore_keywords = ['http', 'assets/', 'font', 'google_fonts', 'Jakarta', 'Brains', 'package:', 'lib/', 'svg', 'png', '.dart', 'Fira', 'Excellence', 'Academy', 'firebase', 'google', 'flutterfire']
                    if not any(x.lower() in stripped.lower() for x in ignore_keywords):
                        findings.append({'file': os.path.relpath(path, d), 'line': lineno, 'label': 'potential-key', 'content': stripped[:130]})
        except Exception:
            pass

print(json.dumps(findings[:60], indent=2))
