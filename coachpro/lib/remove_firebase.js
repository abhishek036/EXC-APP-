const fs = require('fs');
const path = require('path');

function replaceInDir(dir) {
  const files = fs.readdirSync(dir);
  for (const file of files) {
    const fullPath = path.join(dir, file);
    if (fs.statSync(fullPath).isDirectory()) {
      replaceInDir(fullPath);
    } else if (fullPath.endsWith('.dart')) {
      let content = fs.readFileSync(fullPath, 'utf8');
      
      let modified = false;

      // Ensure we remove that exact import
      if (content.includes("package:cloud_firestore/cloud_firestore.dart")) {
          content = content.replace(/import\s+['"]package:cloud_firestore\/cloud_firestore\.dart['"];?\n?/g, '');
          modified = true;
      }
      
      // Timestamp?.toDate()
      // e.g. (data['date'] as Timestamp?)?.toDate()
      if (content.includes("as Timestamp")) {
          content = content.replace(/\(([^)]+) as Timestamp\?\)\?\.toDate\(\)/g, "(DateTime.tryParse(($1)?.toString() ?? ''))");
          content = content.replace(/\(([^)]+) as Timestamp\)\.toDate\(\)/g, "DateTime.parse(($1).toString())");
          modified = true;
      }
      if (content.match(/\[([^\]]+)\] is Timestamp/g)) {
          content = content.replace(/\[([^\]]+)\] is Timestamp \? \([^)]+\)\.toDate\(\) : [^,]+/g, "DateTime.tryParse($1?.toString() ?? '')");
          modified = true;
      }

      // Timestamp.fromDate(...)
      if (content.includes("Timestamp.fromDate")) {
          content = content.replace(/Timestamp\.fromDate\(([^)]+)\)/g, "$1.toIso8601String()");
          modified = true;
      }

      // Timestamp.now()
      if (content.includes("Timestamp.now()")) {
          content = content.replace(/Timestamp\.now\(\)/g, "DateTime.now().toIso8601String()");
          modified = true;
      }

      // Sometimes just `data['updatedAt'] as Timestamp?`
      if (content.includes("as Timestamp")) {
          content = content.replace(/as Timestamp\?/g, "as String?");
          content = content.replace(/as Timestamp/g, "as String");
          modified = true;
      }

      if (modified) {
          fs.writeFileSync(fullPath, content, 'utf8');
          console.log('Modified', fullPath);
      }
    }
  }
}

replaceInDir('c:/Users/Admin/Pictures/COACHING APP/coachpro/lib/core/models');
console.log('Done');
