import multer from 'multer';
import path from 'path';

const storage = multer.memoryStorage();

export const upload = multer({
    storage,
    limits: { fileSize: 5 * 1024 * 1024 }, // 5MB limit
    fileFilter: (_req, file, cb) => {
        const filetypes = /xlsx|xls|csv/;
        const mimetype = file.mimetype.includes('spreadsheet') || file.mimetype.includes('csv') || file.mimetype.includes('excel');
        const extname = filetypes.test(path.extname(file.originalname).toLowerCase());

        if (mimetype || extname) {
            return cb(null, true);
        }
        cb(new Error('Only Excel (.xlsx, .xls) or CSV files are allowed!'));
    }
});
