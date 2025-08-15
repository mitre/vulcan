#!/usr/bin/env python3
import os
import glob

def fix_trailing_whitespace(filepath):
    """Remove trailing whitespace from file"""
    with open(filepath, 'r') as f:
        lines = f.readlines()

    modified = False
    new_lines = []
    for line in lines:
        new_line = line.rstrip() + '\n' if line.endswith('\n') else line.rstrip()
        if new_line != line:
            modified = True
        new_lines.append(new_line)

    if modified:
        with open(filepath, 'w') as f:
            f.writelines(new_lines)
        return True
    return False

# Fix Vue files
vue_files = glob.glob('app/javascript/components/**/*.vue', recursive=True)
fixed_count = 0
for file in vue_files:
    if fix_trailing_whitespace(file):
        fixed_count += 1
        print(f"Fixed: {file}")

# Fix other files
other_files = [
    'app/views/layouts/application.html.haml',
    'config/environments/test.rb.database_config',
    'esbuild.config.js'
]

for file in other_files:
    if os.path.exists(file):
        if fix_trailing_whitespace(file):
            fixed_count += 1
            print(f"Fixed: {file}")

print(f"\nTotal files fixed: {fixed_count}")
