import os
import re

directory = r"c:\Users\Admin\Pictures\COACHING APP\coachpro\lib"

# regex to find CPToast.show(..., type: CPToastType.XYZ)
pattern = re.compile(
    r"CPToast\.show\(\s*([^,]+),\s*message:\s*(.*?),\s*type:\s*CPToastType\.(success|warning|error|info)\s*\)"
)

for root, _, files in os.walk(directory):
    for filename in files:
        if filename.endswith(".dart"):
            filepath = os.path.join(root, filename)
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()

            if 'CPToastType' in content:
                # Replace
                new_content = pattern.sub(r"CPToast.\3(\1, \2)", content)
                
                # Still check if there are other matches?
                # we also might have CPToast.show(context, type: CPToastType.success, message: '...')
                pattern2 = re.compile(
                    r"CPToast\.show\(\s*([^,]+),\s*type:\s*CPToastType\.(success|warning|error|info),\s*message:\s*(.*?)\s*\)"
                )
                new_content = pattern2.sub(r"CPToast.\2(\1, \3)", new_content)

                if new_content != content:
                    with open(filepath, 'w', encoding='utf-8') as f:
                        f.write(new_content)
                    print(f"Updated {filepath}")
