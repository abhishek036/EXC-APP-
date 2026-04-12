import os, re
from pathlib import Path

workspace_root = Path(__file__).resolve().parent
app_root = workspace_root / 'excellence'
if not app_root.exists():
    app_root = next(
        (p for p in workspace_root.iterdir() if p.is_dir() and (p / 'pubspec.yaml').exists()),
        app_root,
    )

panels = {
    'student': str(app_root / 'lib/features/student/presentation/pages'),
    'teacher': str(app_root / 'lib/features/teacher/presentation/pages'),
    'admin': str(app_root / 'lib/features/admin/presentation/pages'),
}

for panel, path in panels.items():
    print()
    print('=== ' + panel.upper() + ' ===')
    for f in sorted(os.listdir(path)):
        if not f.endswith('.dart') or f.endswith('.bak'):
            continue
        fp = os.path.join(path, f)
        with open(fp, 'r', encoding='utf-8') as fh:
            lines = fh.readlines()
        
        dead_buttons = []
        todo_count = 0
        hardcoded_data = []
        no_repo = True
        
        for i, line in enumerate(lines, 1):
            stripped = line.strip()
            # Dead buttons: onTap: () {} or onPressed: () {}
            if re.search(r'on(?:Tap|Pressed):\s*\(\)\s*\{?\s*\}?,?\s*$', stripped) and '{}' in stripped:
                dead_buttons.append(i)
            # TODOs
            if 'TODO' in stripped or 'FIXME' in stripped:
                todo_count += 1
            # Check for repository usage
            if 'Repository' in stripped or '_repo' in stripped or '_adminRepo' in stripped or '_studentRepo' in stripped:
                no_repo = False
        
        full_content = ''.join(lines)
        # Check for hardcoded demo text
        demo_patterns = re.findall(r"'(Demo |Sample |Test |Dummy |Placeholder|Lorem|Hardcoded)", full_content, re.IGNORECASE)
        
        issues = []
        if dead_buttons:
            issues.append('DEAD BUTTONS at lines: ' + str(dead_buttons))
        if todo_count:
            issues.append('TODOs: ' + str(todo_count))
        if demo_patterns:
            issues.append('DEMO DATA: ' + str(demo_patterns[:5]))
        if no_repo:
            issues.append('NO BACKEND REPO (may be static)')
        
        if issues:
            print('  ' + f + ':')
            for iss in issues:
                print('    - ' + iss)
        else:
            print('  ' + f + ': OK')
