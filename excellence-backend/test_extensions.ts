import { generalUpload } from './src/middleware/upload';

function checkExtensionSupport(filename: string, mimetype: string): void {
  // We can directly call the fileFilter to see what it does
  // @ts-ignore
  const fileFilter = generalUpload.fileFilter;
  
  if (!fileFilter) {
    console.log(`[PASS] ${filename} - No fileFilter found, all files allowed by default.`);
    return;
  }

  const mockFile = { originalname: filename, mimetype: mimetype };
  fileFilter({} as any, mockFile as any, (error: any, result: boolean) => {
    if (error) {
      console.log(`[FAIL] ${filename} -> Rejected: ${error.message}`);
    } else if (result) {
      console.log(`[PASS] ${filename} -> Accepted!`);
    } else {
      console.log(`[FAIL] ${filename} -> Rejected (boolean false)`);
    }
  });
}

console.log('--- Testing generalUpload Material Extensions ---');
checkExtensionSupport('document.pdf', 'application/pdf');
checkExtensionSupport('image.png', 'image/png');
checkExtensionSupport('image.jpeg', 'image/jpeg');
checkExtensionSupport('notes.doc', 'application/msword');
checkExtensionSupport('assignment.docx', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document');
checkExtensionSupport('movie.mp4', 'video/mp4');
checkExtensionSupport('data.csv', 'text/csv');
console.log('-------------------------------------------------');
