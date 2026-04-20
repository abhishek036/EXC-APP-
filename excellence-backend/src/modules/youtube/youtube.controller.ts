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
      const instituteId = req.instituteId;
      if (!instituteId) {
        return res.status(401).send('Institute context missing');
      }

      const url = this.service.getAuthUrl(instituteId);
      return res.redirect(url);
    } catch (error) {
           next(error);
    }
  };

  // 2. Handle Google Callback
  handleCallback = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const code = req.query.code as string;
      const state = req.query.state as string;

      if (!code) {
        return res.status(400).send('Authorization code missing');
      }

      if (!state || state.trim().length < 4) {
        return res.status(400).send('Invalid OAuth state');
      }

      const tokens = await this.service.handleCallback(code);
      const tokenStoredHint = tokens.refresh_token
        ? 'Refresh token received successfully. Store it in secure server-side institute settings.'
        : 'No new refresh token was returned by Google (this can happen on re-consent).';

      return res.status(200).send(`
        <html>
          <body style="font-family: Arial; padding: 2rem; text-align: center;">
            <h1 style="color: green;">YouTube Authentication Successful!</h1>
            <p>You may close this window and return to the Excellence Dashboard.</p>
            <p style="font-size: 14px; color: #333;">${tokenStoredHint}</p>
            <p style="font-size: 12px; color: gray;">For security, sensitive OAuth tokens are never shown in browser responses.</p>
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

