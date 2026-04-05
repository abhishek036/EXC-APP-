import { Request, Response, NextFunction } from 'express';
import { YoutubeService } from './youtube.service';
import { sendResponse } from '../../utils/response';

export class YoutubeController {
  private service: YoutubeService;

  constructor() {
    this.service = new YoutubeService();
  }

  // 1. Generate OAuth Auth URL
  getAuthUrl = (req: Request, res: Response, next: NextFunction) => {
    try {
      // Pass a dummy institute ID for this setup phase
      const url = this.service.getAuthUrl('test_institute_id');
      return res.redirect(url);
    } catch (error) {
           next(error);
    }
  };

  // 2. Handle Google Callback
  handleCallback = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const code = req.query.code as string;

      if (!code) {
        return res.status(400).send('Authorization code missing');
      }

      const tokens = await this.service.handleCallback(code);

      // Ideally, save the refresh_token to the institute settings via Prisma here
      // const refreshToken = tokens.refresh_token; 

      return res.status(200).send(`
        <html>
          <body style="font-family: Arial; padding: 2rem; text-align: center;">
            <h1 style="color: green;">YouTube Authentication Successful!</h1>
            <p>You may close this window and return to the CoachPro Dashboard.</p>
            <p><strong>Refresh Token:</strong> <br><br><code>${tokens.refresh_token}</code></p>
            <p style="font-size: 12px; color: gray;">(Copy this and paste into your backend .env file as YOUTUBE_REFRESH_TOKEN for now)</p>
          </body>
        </html>
      `);
    } catch (error) {
      next(error);
    }
  };

  // 3. Create Live Stream
  createStream = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const { title, description, privacyStatus } = req.body;
      const instituteId = req.instituteId;

      await this.service.setCredentials(instituteId!);

      const result = await this.service.createLiveStream(title, description, privacyStatus);

      return sendResponse({
        res,
        data: result,
        statusCode: 201,
        message: 'Live stream created successfully on YouTube',
      });
    } catch (error: any) {
      if (error?.response?.data) {
        console.error('YouTube API Error:', error.response.data);
      }
      next(error);
    }
  };
}
