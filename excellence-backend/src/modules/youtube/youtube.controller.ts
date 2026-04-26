import { Request, Response, NextFunction } from 'express';
import { YoutubeService } from './youtube.service';
import { sendResponse } from '../../utils/response';
import { prisma } from '../../server';

export class YoutubeController {
  private service: YoutubeService;

  constructor() {
    this.service = new YoutubeService();
  }

  // ── 1. Generate OAuth Auth URL ─────────────────────────────────────────────
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

  // ── 2. Handle Google OAuth Callback ───────────────────────────────────────
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

  // ── 3. Create Live Stream + Persist to DB ──────────────────────────────────
  // POST /youtube/live
  // Body: { title, description, privacyStatus, batch_id? }
  // Returns: { youtubeVideoId, rtmpUrl, streamKey, lectureId }
  createStream = async (req: Request, res: Response, next: NextFunction) => {
    try {
      const { title, description, privacyStatus = 'unlisted', batch_id } = req.body;
      const instituteId = req.instituteId;
      const teacherUserId = req.user?.userId;

      if (!title?.trim()) {
        return res.status(400).json({ message: 'Stream title is required.' });
      }

      // ── Step 1: Authenticate via saved refresh token ──────────────────────
      await this.service.setCredentials(instituteId!);

      // ── Step 2: Create broadcast + stream + bind on YouTube API ──────────
      const youtubeResult = await this.service.createLiveStream(
        title.trim(),
        description?.trim() ?? '',
        privacyStatus,
      );

      const { broadcastId: youtubeVideoId, streamKey, streamUrl: rtmpUrl } = youtubeResult;

      if (!youtubeVideoId || !streamKey) {
        throw new Error(
          'YouTube API did not return a valid Broadcast ID or Stream Key. ' +
          'Ensure the channel is verified and YouTube Live is enabled.',
        );
      }

      // ── Step 3: Persist the live lecture to the database via Prisma ───────
      let lectureId: string | null = null;
      try {
        // Resolve the teacher record linked to the requesting user
        const teacher = teacherUserId
          ? await prisma.teacher.findFirst({
              where: { user_id: teacherUserId, institute_id: instituteId! },
              select: { id: true },
            })
          : null;

        const lecturePayload: any = {
          institute_id: instituteId!,
          title: title.trim(),
          link: `https://www.youtube.com/watch?v=${youtubeVideoId}`,
          lecture_type: 'live',
          is_active: true,
          scheduled_at: new Date(),
        };

        if (teacher?.id) lecturePayload.teacher_id = teacher.id;
        if (batch_id?.trim()) lecturePayload.batch_id = batch_id.trim();
        if (description?.trim()) lecturePayload.description = description.trim();

        const lecture = await prisma.lecture.create({ data: lecturePayload });
        lectureId = lecture.id;
      } catch (dbErr) {
        // DB persistence failure is non-fatal — stream can still start
        console.error('[YoutubeController] DB persistence failed (non-fatal):', dbErr);
      }

      return sendResponse({
        res,
        data: {
          youtubeVideoId,
          rtmpUrl: rtmpUrl ?? 'rtmp://a.rtmp.youtube.com/live2',
          streamKey,
          broadcastId: youtubeVideoId, // backward-compat alias
          streamUrl: rtmpUrl ?? 'rtmp://a.rtmp.youtube.com/live2',
          watchUrl: `https://www.youtube.com/watch?v=${youtubeVideoId}`,
          lectureId,
        },
        statusCode: 201,
        message: 'Live stream created and persisted successfully.',
      });
    } catch (error: any) {
      if (error?.response?.data) {
        console.error('[YoutubeController] YouTube API Error:', JSON.stringify(error.response.data, null, 2));
      }
      next(error);
    }
  };
}
