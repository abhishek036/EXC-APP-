import multer from 'multer';
import path from 'path';

const storage = multer.memoryStorage();

const blockedExtensions = new Set([
    '.apk', '.bat', '.cmd', '.com', '.cpl', '.dll', '.exe', '.hta', '.jar', '.js', '.jse', '.lnk', '.msi',
    '.php', '.pl', '.ps1', '.py', '.rb', '.scr', '.sh', '.vb', '.vbs', '.wsf',
]);

const allowedGeneralExtensions = new Set([
    '.csv', '.doc', '.docx', '.gif', '.jpeg', '.jpg', '.mp3', '.mp4', '.pdf', '.png', '.ppt', '.pptx',
    '.txt', '.webp', '.xls', '.xlsx', '.zip',
]);

const allowedGeneralMimePrefixes = ['application/', 'audio/', 'image/', 'text/', 'video/'];

const getExtension = (fileName: string): string => path.extname(String(fileName || '')).toLowerCase();

export const excelUpload = multer({
    storage,
    limits: { fileSize: 5 * 1024 * 1024 }, // 5MB limit
    fileFilter: (_req, file, cb) => {
        const filetypes = /xlsx|csv/;
        const mimetype = file.mimetype.includes('spreadsheet') || file.mimetype.includes('csv') || file.mimetype.includes('excel');
        const extname = filetypes.test(path.extname(file.originalname).toLowerCase());

        if (mimetype || extname) {
            return cb(null, true);
        }
        cb(new Error('Only Excel (.xlsx) or CSV files are allowed!'));
    }
});

export const generalUpload = multer({
    storage,
    limits: { fileSize: Number.parseInt(process.env.GENERAL_UPLOAD_MAX_MB || '10', 10) * 1024 * 1024 },
    fileFilter: (_req, file, cb) => {
        const ext = getExtension(file.originalname);
        if (blockedExtensions.has(ext)) {
            return cb(new Error('This file type is not allowed.'));
        }

        if (!allowedGeneralExtensions.has(ext)) {
            return cb(new Error('Unsupported file extension.'));
        }

        const mime = String(file.mimetype || '').toLowerCase();
        const hasAllowedMime =
            mime === 'application/octet-stream' ||
            allowedGeneralMimePrefixes.some((prefix) => mime.startsWith(prefix));

        if (!hasAllowedMime) {
            return cb(new Error('Unsupported file MIME type.'));
        }

        cb(null, true);
    }
});
