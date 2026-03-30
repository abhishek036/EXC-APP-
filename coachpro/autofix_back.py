import os
import re

lib_dir = "d:\\COACHING APP\\coachpro\\lib"

for root, dirs, files in os.walk(lib_dir):
    for f in files:
        if f.endswith(".dart"):
            filepath = os.path.join(root, f)
            with open(filepath, "r", encoding="utf-8") as file:
                content = file.read()
            
            if "context.pop()" not in content:
                continue
                
            # determine dashboard route
            fallback = "/"
            if "admin" in filepath:
                fallback = "/admin"
            elif "student" in filepath:
                fallback = "/student"
            elif "teacher" in filepath:
                fallback = "/teacher"
            elif "parent" in filepath:
                fallback = "/parent"
                
            # replace `onTap: () => context.pop(),`
            new_content = re.sub(
                r"onTap:\s*\(\)\s*=>\s*context\.pop\(\)", 
                f"onTap: () {{ if (context.canPop()) {{ context.pop(); }} else {{ context.go('{fallback}'); }} }}", 
                content
            )
            # replace `onPressed: () => context.pop(),`
            new_content = re.sub(
                r"onPressed:\s*\(\)\s*=>\s*context\.pop\(\)", 
                f"onPressed: () {{ if (context.canPop()) {{ context.pop(); }} else {{ context.go('{fallback}'); }} }}", 
                new_content
            )
            
            # replace `onTap: () { context.pop(); },`
            new_content = re.sub(
                r"onTap:\s*\(\)\s*\{\s*context\.pop\(\);\s*\}", 
                f"onTap: () {{ if (context.canPop()) {{ context.pop(); }} else {{ context.go('{fallback}'); }} }}", 
                new_content
            )
            
            # replace `onPressed: () { context.pop(); },`
            new_content = re.sub(
                r"onPressed:\s*\(\)\s*\{\s*context\.pop\(\);\s*\}", 
                f"onPressed: () {{ if (context.canPop()) {{ context.pop(); }} else {{ context.go('{fallback}'); }} }}", 
                new_content
            )
            
            if new_content != content:
                with open(filepath, "w", encoding="utf-8") as file:
                    file.write(new_content)
                print(f"Fixed {filepath}")

