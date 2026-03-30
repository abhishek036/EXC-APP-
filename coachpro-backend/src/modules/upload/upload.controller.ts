import { Request, Response } from 'express';
import { S3Client, GetObjectCommand } from '@aws-sdk/client-s3';
import { Upload } from '@aws-sdk/lib-storage';
import { v4 as uuidv4 } from 'uuid';
import { sendResponse } from '../../utils/response';
import { ApiError } from '../../middleware/error.middleware';
import { extname } from 'path';

const s3 = new S3Client({
  region: process.env.B2_REGION || 'us-east-005',
  endpoint: process.env.B2_ENDPOINT || 'https://s3.us-east-005.backblazeb2.com',
  credentials: {
    accessKeyId: process.env.B2_KEY_ID!,
    secretAccessKey: process.env.B2_APP_KEY!,
  },
});

export class UploadController {
  
  // POST /api/upload
  async uploadFile(req: Request, res: Response) {
    if (!req.file) throw new ApiError('No file provided', 400);

    const bucketName = process.env.B2_BUCKET_NAME!;
    // Create a unique file name
    const ext = extname(req.file.originalname) || '';
    const fileKey = `uploads/${uuidv4()}${ext}`;

    const uploader = new Upload({
      client: s3,
      params: {
        Bucket: bucketName,
        Key: fileKey,
        Body: req.file.buffer,
        ContentType: req.file.mimetype,
      },
    });

    await uploader.done();

    // Since our bucket is private, we will serve it through our own backend proxy endpoint
    const fileUrl = `${req.protocol}://${req.get('host')}/api/upload/file/${encodeURIComponent(fileKey)}`;
    
    return sendResponse({ res, data: { fileUrl }, message: 'Uploaded successfully', statusCode: 201 });
  }

  // GET /api/upload/file/:key(*)
  async downloadFile(req: Request, res: Response) {
    const fileKey = req.params.key || req.params[0];

    const bucketName = process.env.B2_BUCKET_NAME!;

    try {
      const command = new GetObjectCommand({
        Bucket: bucketName,
        Key: fileKey,
      });

      const data = await s3.send(command);

      if (data.ContentType) res.setHeader('Content-Type', data.ContentType);
      if (data.ContentLength) res.setHeader('Content-Length', data.ContentLength);
      
      // We can add cache headers here for better performance
      res.setHeader('Cache-Control', 'public, max-age=31536000, immutable');

      // @ts-ignore
      data.Body?.pipe(res);
    } catch (e: any) {
      console.error('Download error:', e);
      res.status(404).json({ message: 'File not found' });
    }
  }
}
