const fs = require('fs');
const path = require('path');

function fixFiles(dir) {
  const files = fs.readdirSync(dir);
  for (const file of files) {
    const fullPath = path.join(dir, file);
    if (fs.statSync(fullPath).isDirectory()) {
      fixFiles(fullPath);
    } else if (fullPath.endsWith('.dart')) {
      let content = fs.readFileSync(fullPath, 'utf8');
      
      let modified = false;

      // The broken pattern is roughly:
      // DateTime.tryParse(([ANY_NEWLINES_VARS](data['date'])?.toString() ?? ''))
      // we need to extract the ANY_NEWLINES_VARS and `date: DateTime.tryParse( ... )`
      
      const regex1 = /DateTime\.tryParse\(\(([\s\S]+?)(data\['[^']+']|data\.data\(\)\['[^']+'\]|json\['[^']+'])\)\?\.toString\(\)/g;
      if (regex1.test(content)) {
          content = content.replace(regex1, (match, prefix, varName) => {
              // The prefix includes the `\n      id: docId,\n      batchId:... \n      date: `
              // So we just want to put `prefix` exactly where it was, and then `DateTime.tryParse(${varName}?.toString()`
              // Wait! prefix started with `\n      id: docId`
              return prefix + "DateTime.tryParse((" + varName + ")?.toString()";
          });
          modified = true;
      }
      
      // also fix createdAt: (DateTime.tryParse((data['createdAt'])?.toString() ?? ''))
      const regex2 = /\(DateTime\.tryParse\(\((data\['[^']+']|json\['[^']+'])\)\?\.toString\(\) \?\? ''\)\)/g;
      if (regex2.test(content)) {
          content = content.replace(regex2, "DateTime.tryParse(($1)?.toString() ?? '')");
          modified = true;
      }

      if (modified) {
          fs.writeFileSync(fullPath, content, 'utf8');
          console.log('Fixed', fullPath);
      }
    }
  }
}

fixFiles('c:/Users/Admin/Pictures/COACHING APP/excellence/lib/core/models');

