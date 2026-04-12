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
    wrong_font_files = []
    glow_files = []
    total = 0
    for f in sorted(os.listdir(path)):
        if not f.endswith('.dart') or f.endswith('.bak'):
            continue
        total += 1
        fp = os.path.join(path, f)
        with open(fp, 'r', encoding='utf-8') as fh:
            c = fh.read()
        fonts = set(re.findall(r'GoogleFonts\.(\w+)', c))
        wrong = fonts - {'plusJakartaSans', 'jetBrainsMono'}
        if wrong:
            wrong_font_files.append(f + ': ' + str(sorted(wrong)))
        if '_glow(' in c:
            glow_files.append(f)
    
    print()
    print('=== ' + panel.upper() + ' (' + str(total) + ' files) ===')
    if wrong_font_files:
        print('  WRONG FONTS (' + str(len(wrong_font_files)) + '):')
        for x in wrong_font_files:
            print('    ' + x)
    else:
        print('  Fonts: ALL OK')
    if glow_files:
        print('  GLOW EFFECTS (' + str(len(glow_files)) + '):')
        for x in glow_files:
            print('    ' + x)
    else:
        print('  Glow: NONE')
