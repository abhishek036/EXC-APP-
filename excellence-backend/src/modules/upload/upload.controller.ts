import { Request, Response } from 'express';
import { S3Client, GetObjectCommand } from '@aws-sdk/client-s3';
import { Upload } from '@aws-sdk/lib-storage';
import { createClient, SupabaseClient } from '@supabase/supabase-js';
import { v2 as cloudinary } from 'cloudinary';
import axios from 'axios';
import { v4 as uuidv4 } from 'uuid';
import { sendResponse } from '../../utils/response';
import { ApiError } from '../../middleware/error.middleware';
import { basename, dirname, extname, isAbsolute, resolve } from 'path';
import { createReadStream, existsSync, promises as fsp } from 'fs';

type StorageProvider = 'b2' | 'cloudinary' | 'supabase' | 'local';

type StorageRef = {
  provider: StorageProvider;
  key: string;
  bucket?: string;
  resourceType?: string;
  mimeType?: string;
  fileName?: string;
  sizeKb?: number;
};

const s3 = new S3Client({
  region: process.env.B2_REGION || 'us-east-005',
  endpoint: process.env.B2_ENDPOINT || 'https://s3.us-east-005.backblazeb2.com',
  credentials: {
    accessKeyId: process.env.B2_KEY_ID!,
    secretAccessKey: process.env.B2_APP_KEY!,
  },
});

const hasCloudinary = !!(
  process.env.CLOUDINARY_CLOUD_NAME &&
  process.env.CLOUDINARY_API_KEY &&
  process.env.CLOUDINARY_API_SECRET
);

if (hasCloudinary) {
  cloudinary.config({
    cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
    api_key: process.env.CLOUDINARY_API_KEY,
    api_secret: process.env.CLOUDINARY_API_SECRET,
    secure: true,
  });
}

const hasSupabase = !!(process.env.SUPABASE_URL && process.env.SUPABASE_SERVICE_ROLE_KEY);
const supabaseClient: SupabaseClient | null = hasSupabase
  ? createClient(process.env.SUPABASE_URL!, process.env.SUPABASE_SERVICE_ROLE_KEY!)
  : null;

export class UploadController {
  private useLocalStorage(): boolean {
    const raw = String(process.env.LOCAL_FILE_STORAGE || '').trim().toLowerCase();
    if (raw === '1' || raw === 'true' || raw === 'yes') return true;
    if (raw === '0' || raw === 'false' || raw === 'no') return false;
    return process.env.NODE_ENV !== 'production';
  }

  private localStorageRoot(): string {
    const configured = String(process.env.UPLOAD_DIR || '').trim();
    if (configured) {
      return isAbsolute(configured) ? configured : resolve(process.cwd(), configured);
    }
    return resolve(process.cwd(), 'tmp', 'uploads');
  }

  private localAbsolutePathFromKey(key: string): string {
    const cleaned = String(key || '').replace(/\\/g, '/').replace(/^\/+/, '');
    const safeParts = cleaned.split('/').filter((part) => part && part !== '.' && part !== '..');
    if (!safeParts.length) {
      throw new ApiError('Invalid local storage key', 400, 'INVALID_STORAGE_KEY');
    }
    return resolve(this.localStorageRoot(), ...safeParts);
  }

  private sanitizeFileName(fileNameRaw: string): string {
    const normalized = basename(String(fileNameRaw || '').trim()) || 'upload';
    return normalized
      .replace(/[^A-Za-z0-9._()\- ]/g, '_')
      .replace(/\s+/g, ' ')
      .slice(0, 180);
  }

  private getUploadedFilePath(file: Express.Multer.File): string {
    const filePath = String((file as any)?.path || '').trim();
    if (!filePath) {
      throw new ApiError('Uploaded file is not available on disk', 500, 'UPLOAD_PATH_MISSING');
    }
    return filePath;
  }

  private async readFileHead(filePath: string, maxBytes: number): Promise<Buffer> {
    const handle = await fsp.open(filePath, 'r');
    try {
      const buffer = Buffer.alloc(maxBytes);
      const { bytesRead } = await handle.read(buffer, 0, maxBytes, 0);
      return buffer.subarray(0, bytesRead);
    } finally {
      await handle.close();
    }
  }

  private async cleanupUploadedFile(file: Express.Multer.File): Promise<void> {
    const filePath = String((file as any)?.path || '').trim();
    if (!filePath) return;

    try {
      await fsp.unlink(filePath);
    } catch {
      // best-effort cleanup for temp multer files
    }
  }

  private async assertMagicBytes(file: Express.Multer.File): Promise<void> {
    const filePath = this.getUploadedFilePath(file);
    const header = await this.readFileHead(filePath, 16);
    const extension = extname(file.originalname).toLowerCase();

    const startsWith = (hexPrefix: string): boolean =>
      header.toString('hex', 0, Math.ceil(hexPrefix.length / 2)).startsWith(hexPrefix);

    const checks: Record<string, () => boolean> = {
      '.png': () => startsWith('89504e470d0a1a0a'),
      '.jpg': () => startsWith('ffd8ff'),
      '.jpeg': () => startsWith('ffd8ff'),
      '.gif': () => startsWith('47494638'),
      '.pdf': () => startsWith('25504446'),
      '.zip': () => startsWith('504b0304') || startsWith('504b0506') || startsWith('504b0708'),
      '.docx': () => startsWith('504b0304') || startsWith('504b0506') || startsWith('504b0708'),
      '.xlsx': () => startsWith('504b0304') || startsWith('504b0506') || startsWith('504b0708'),
      '.pptx': () => startsWith('504b0304') || startsWith('504b0506') || startsWith('504b0708'),
      '.mp4': () => header.length > 12 && header.toString('ascii', 4, 8) === 'ftyp',
    };

    const check = checks[extension];
    if (check && !check()) {
      throw new ApiError('Uploaded file content does not match file extension', 400, 'INVALID_FILE_SIGNATURE');
    }
  }

  private async assertUploadSafety(file: Express.Multer.File): Promise<void> {
    if (!file || Number(file.size || 0) <= 0) {
      throw new ApiError('Uploaded file is empty', 400, 'EMPTY_FILE');
    }

    const filePath = this.getUploadedFilePath(file);
    const stat = await fsp.stat(filePath).catch(() => null);
    if (!stat || !stat.isFile() || stat.size <= 0) {
      throw new ApiError('Uploaded file is empty', 400, 'EMPTY_FILE');
    }

    await this.assertMagicBytes(file);
  }

  private normalizeDestination(destinationRaw: unknown): string {
    const value = String(destinationRaw ?? 'uploads').trim();
    const cleaned = value
      .replace(/[^a-zA-Z0-9_\-/]/g, '')
      .replace(/\/+/g, '/')
      .replace(/^\/+|\/+$/g, '');
    return cleaned || 'uploads';
  }

  private encodeRef(ref: StorageRef): string {
    return `ref_${Buffer.from(JSON.stringify(ref)).toString('base64url')}`;
  }

  private decodeRef(ref: string): StorageRef | null {
    if (!ref.startsWith('ref_')) return null;
    try {
      const json = Buffer.from(ref.substring(4), 'base64url').toString('utf8');
      const parsed = JSON.parse(json) as StorageRef;
      if (!parsed || !parsed.provider || !parsed.key) return null;
      return parsed;
    } catch {
      return null;
    }
  }

  private contentTypeFromExt(fileName: string): string {
    const ext = extname(fileName).toLowerCase();
    if (ext === '.pdf') return 'application/pdf';
    if (ext === '.png') return 'image/png';
    if (ext === '.jpg' || ext === '.jpeg') return 'image/jpeg';
    if (ext === '.mp4') return 'video/mp4';
    if (ext === '.zip') return 'application/zip';
    if (ext === '.doc') return 'application/msword';
    if (ext === '.docx') {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    return 'application/octet-stream';
  }

  private async uploadToCloudinary(file: Express.Multer.File, destination: string): Promise<StorageRef> {
    if (!hasCloudinary) {
      throw new ApiError('Cloudinary storage is not configured', 500, 'STORAGE_NOT_CONFIGURED');
    }

    const resourceType = file.mimetype.startsWith('video/')
      ? 'video'
      : file.mimetype.startsWith('image/')
      ? 'image'
      : 'raw';

    const folder = process.env.CLOUDINARY_FOLDER
      ? `${process.env.CLOUDINARY_FOLDER.replace(/\/+$/g, '')}/${destination}`
      : `excellence/${destination}`;

    const uploaded = await new Promise<any>((resolve, reject) => {
      const stream = cloudinary.uploader.upload_stream(
        {
          folder,
          resource_type: resourceType,
          use_filename: true,
          unique_filename: true,
          overwrite: false,
        },
        (error, result) => {
          if (error || !result) {
            reject(error ?? new Error('Cloudinary upload failed'));
            return;
          }
          resolve(result);
        },
      );

      const input = createReadStream(this.getUploadedFilePath(file));
      input.on('error', reject);
      input.pipe(stream);
    });

    return {
      provider: 'cloudinary',
      key: String(uploaded.public_id),
      resourceType,
      mimeType: file.mimetype,
      fileName: file.originalname,
      sizeKb: Math.ceil(file.size / 1024),
    };
  }

  private async uploadToSupabase(file: Express.Multer.File, destination: string): Promise<StorageRef> {
    if (!supabaseClient) {
      throw new ApiError('Supabase storage is not configured', 500, 'STORAGE_NOT_CONFIGURED');
    }

    const bucket = process.env.SUPABASE_DOCS_BUCKET || 'study-materials';
    const ext = extname(file.originalname).toLowerCase();
    const key = `${destination}/${uuidv4()}${ext}`;
    const fileBuffer = await fsp.readFile(this.getUploadedFilePath(file));

    const uploaded = await supabaseClient.storage
      .from(bucket)
      .upload(key, fileBuffer, {
        contentType: file.mimetype || this.contentTypeFromExt(file.originalname),
        upsert: false,
      });

    if (uploaded.error) {
      throw new ApiError(uploaded.error.message, 500, 'STORAGE_UPLOAD_FAILED');
    }

    return {
      provider: 'supabase',
      bucket,
      key,
      mimeType: file.mimetype,
      fileName: file.originalname,
      sizeKb: Math.ceil(file.size / 1024),
    };
  }

  private async uploadToB2(file: Express.Multer.File, destination: string): Promise<StorageRef> {
    const bucketName = process.env.B2_BUCKET_NAME;
    if (!bucketName) {
      throw new ApiError('B2 storage is not configured', 500, 'STORAGE_NOT_CONFIGURED');
    }

    const ext = extname(file.originalname) || '';
    const key = `${destination}/${uuidv4()}${ext}`;

    const uploader = new Upload({
      client: s3,
      params: {
        Bucket: bucketName,
        Key: key,
        Body: createReadStream(this.getUploadedFilePath(file)),
        ContentType: file.mimetype || this.contentTypeFromExt(file.originalname),
      },
    });

    await uploader.done();

    return {
      provider: 'b2',
      bucket: bucketName,
      key,
      mimeType: file.mimetype,
      fileName: file.originalname,
      sizeKb: Math.ceil(file.size / 1024),
    };
  }

  private async uploadToLocal(file: Express.Multer.File, destination: string): Promise<StorageRef> {
    const ext = extname(file.originalname) || '';
    const key = `${destination}/${uuidv4()}${ext}`.replace(/\\/g, '/');
    const absolutePath = this.localAbsolutePathFromKey(key);

    await fsp.mkdir(dirname(absolutePath), { recursive: true });
    await fsp.copyFile(this.getUploadedFilePath(file), absolutePath);

    return {
      provider: 'local',
      key,
      mimeType: file.mimetype || this.contentTypeFromExt(file.originalname),
      fileName: file.originalname,
      sizeKb: Math.ceil(file.size / 1024),
    };
  }

  private async resolveStorageRef(file: Express.Multer.File, destination: string): Promise<StorageRef> {
    const isMedia = file.mimetype.startsWith('image/') || file.mimetype.startsWith('video/');
    const isDocument = !isMedia;

    if (isMedia && hasCloudinary) {
      return this.uploadToCloudinary(file, destination);
    }

    if (isDocument && supabaseClient) {
      return this.uploadToSupabase(file, destination);
    }

    if (hasCloudinary) {
      return this.uploadToCloudinary(file, destination);
    }

    if (supabaseClient) {
      return this.uploadToSupabase(file, destination);
    }

    if (this.useLocalStorage()) {
      return this.uploadToLocal(file, destination);
    }

    return this.uploadToB2(file, destination);
  }

  async uploadSingleFile(params: {
    file: Express.Multer.File;
    destination?: string;
    origin: string;
  }): Promise<{
    fileUrl: string;
    storageProvider: StorageProvider;
    storageKey: string;
    storageBucket: string | null;
    fileName: string;
    fileMimeType: string;
    fileSizeKb: number;
  }> {
    await this.assertUploadSafety(params.file);
    params.file.originalname = this.sanitizeFileName(params.file.originalname);

    const destination = this.normalizeDestination(params.destination);
    try {
      const stored = await this.resolveStorageRef(params.file, destination);
      const fileKey = this.encodeRef(stored);
      const fileUrl = `${params.origin}/api/upload/file/${encodeURIComponent(fileKey)}`;

      return {
        fileUrl,
        storageProvider: stored.provider,
        storageKey: stored.key,
        storageBucket: stored.bucket ?? null,
        fileName: stored.fileName ?? params.file.originalname,
        fileMimeType: stored.mimeType ?? params.file.mimetype,
        fileSizeKb: stored.sizeKb ?? Math.ceil(params.file.size / 1024),
      };
    } finally {
      await this.cleanupUploadedFile(params.file);
    }
  }

  private async streamFromRef(ref: StorageRef): Promise<{ stream: NodeJS.ReadableStream; contentType?: string; contentLength?: number; fileName?: string }> {
    if (ref.provider === 'b2') {
      const command = new GetObjectCommand({
        Bucket: ref.bucket || process.env.B2_BUCKET_NAME!,
        Key: ref.key,
      });
      const data = await s3.send(command);

      return {
        // @ts-ignore
        stream: data.Body,
        contentType: (data.ContentType as string | undefined) ?? ref.mimeType,
        contentLength: data.ContentLength ? Number(data.ContentLength) : undefined,
        fileName: ref.fileName || basename(ref.key),
      };
    }

    if (ref.provider === 'supabase') {
      if (!supabaseClient || !ref.bucket) {
        throw new ApiError('Supabase storage is not configured', 500, 'STORAGE_NOT_CONFIGURED');
      }

      const signed = await supabaseClient.storage.from(ref.bucket).createSignedUrl(ref.key, 60);
      if (signed.error || !signed.data?.signedUrl) {
        throw new ApiError(signed.error?.message || 'Unable to access file', 500, 'SIGNED_URL_FAILED');
      }

      const response = await axios.get(signed.data.signedUrl, {
        responseType: 'stream',
      });

      return {
        stream: response.data,
        contentType: String(response.headers['content-type'] || ref.mimeType || ''),
        contentLength: response.headers['content-length'] ? Number(response.headers['content-length']) : undefined,
        fileName: ref.fileName || basename(ref.key),
      };
    }

    if (ref.provider === 'cloudinary') {
      if (!hasCloudinary) {
        throw new ApiError('Cloudinary storage is not configured', 500, 'STORAGE_NOT_CONFIGURED');
      }

      const url = cloudinary.url(ref.key, {
        secure: true,
        resource_type: ref.resourceType || 'raw',
      });

      const response = await axios.get(url, {
        responseType: 'stream',
      });

      return {
        stream: response.data,
        contentType: String(response.headers['content-type'] || ref.mimeType || ''),
        contentLength: response.headers['content-length'] ? Number(response.headers['content-length']) : undefined,
        fileName: ref.fileName || basename(ref.key),
      };
    }

    if (ref.provider === 'local') {
      const absolutePath = this.localAbsolutePathFromKey(ref.key);
      if (!existsSync(absolutePath)) {
        throw new ApiError('Local file not found', 404, 'NOT_FOUND');
      }

      const stat = await fsp.stat(absolutePath);
      return {
        stream: createReadStream(absolutePath),
        contentType: ref.mimeType || this.contentTypeFromExt(ref.fileName || basename(absolutePath)),
        contentLength: stat.size,
        fileName: ref.fileName || basename(absolutePath),
      };
    }

    throw new ApiError('Unsupported storage provider', 400, 'UNSUPPORTED_STORAGE');
  }
  
  // POST /api/upload
  async uploadFile(req: Request, res: Response) {
    if (!req.file) throw new ApiError('No file provided', 400);
    const payload = await this.uploadSingleFile({
      file: req.file,
      destination: req.body?.destination,
      origin: `${req.protocol}://${req.get('host')}`,
    });

    return sendResponse({
      res,
      data: payload,
      message: 'Uploaded successfully',
      statusCode: 201,
    });
  }

  // GET /api/upload/file/:key(*)
  async downloadFile(req: Request, res: Response) {
    const fileKey = String(req.params.key || req.params[0] || '').trim();
    const dispositionRaw = String(req.query?.disposition || 'inline').toLowerCase();
    const disposition = dispositionRaw === 'attachment' ? 'attachment' : 'inline';
    try {
      if (!fileKey || fileKey.length > 2048 || fileKey.includes('\u0000')) {
        throw new ApiError('Invalid file key', 400, 'INVALID_FILE_KEY');
      }

      const parsed = this.decodeRef(fileKey);

      if (!parsed) {
        const bucketName = process.env.B2_BUCKET_NAME!;
        const command = new GetObjectCommand({
          Bucket: bucketName,
          Key: fileKey,
        });

        const data = await s3.send(command);
        if (data.ContentType) res.setHeader('Content-Type', data.ContentType);
        if (data.ContentLength) res.setHeader('Content-Length', data.ContentLength);
        res.setHeader('X-Content-Type-Options', 'nosniff');
        if (disposition === 'attachment') {
          res.setHeader('Content-Disposition', `attachment; filename*=UTF-8''${encodeURIComponent(basename(fileKey))}`);
        }
        res.setHeader('Cache-Control', 'private, no-store');

        // @ts-ignore
        data.Body?.pipe(res);
        return;
      }

      const streamed = await this.streamFromRef(parsed);
      if (streamed.contentType) res.setHeader('Content-Type', streamed.contentType);
      if (streamed.contentLength) res.setHeader('Content-Length', streamed.contentLength.toString());
      res.setHeader('X-Content-Type-Options', 'nosniff');
      if (streamed.fileName) {
        res.setHeader('Content-Disposition', `${disposition}; filename*=UTF-8''${encodeURIComponent(streamed.fileName)}`);
      }
      res.setHeader('Cache-Control', 'private, no-store');
      streamed.stream.pipe(res);
    } catch (e: any) {
      console.error('Download error:', e);
      res.status(404).json({ message: 'File not found' });
    }
  }
}

