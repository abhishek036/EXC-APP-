import { google } from 'googleapis';
import dotenv from 'dotenv';
dotenv.config();

export class YoutubeService {
  private oauth2Client;

  constructor() {
    this.oauth2Client = new google.auth.OAuth2(
        process.env.YOUTUBE_CLIENT_ID,
        process.env.YOUTUBE_CLIENT_SECRET,
        process.env.YOUTUBE_REDIRECT_URI
    );
  }

  // Set the stored refresh token from DB for the specific institute
  async setCredentials(_instituteId: string) {
    const token = process.env.YOUTUBE_REFRESH_TOKEN?.trim();
    if (!token) {
      throw new Error(
        'YouTube is not connected yet. Please authenticate via Settings → YouTube Integration first.',
      );
    }
    this.oauth2Client.setCredentials({ refresh_token: token });
  }

  getAuthUrl(instituteId: string) {
    return this.oauth2Client.generateAuthUrl({
      access_type: 'offline',
      scope: [
        'https://www.googleapis.com/auth/youtube',
        'https://www.googleapis.com/auth/youtube.upload',
      ],
      prompt: 'consent',
      state: instituteId, // Pass instituteId in state to associate
    });
  }

  async handleCallback(code: string) {
    const { tokens } = await this.oauth2Client.getToken(code);
    return tokens;
  }

  getYoutube() {
    return google.youtube({ version: 'v3', auth: this.oauth2Client });
  }

  async createLiveStream(title: string, description: string, privacyStatus: 'public' | 'unlisted' | 'private' = 'unlisted') {
    const youtube = this.getYoutube();

    // 1. Create Broadcast
    const broadcastResponse = await youtube.liveBroadcasts.insert({
      part: ['snippet', 'status', 'contentDetails'],
      requestBody: {
        snippet: {
          title: title,
          description: description,
          scheduledStartTime: new Date().toISOString(),
        },
        status: {
          privacyStatus: privacyStatus,
          selfDeclaredMadeForKids: false,
        },
        contentDetails: {
          enableAutoStart: true,
          enableAutoStop: true,
          enableEmbed: true,
          enableDvr: true,
          closedCaptionsType: 'closedCaptionsDisabled',
        }
      },
    });

    const broadcast = broadcastResponse.data;

    // 2. Create Stream Keys
    const streamResponse = await youtube.liveStreams.insert({
      part: ['snippet', 'cdn'],
      requestBody: {
        snippet: {
          title: `Stream: ${title}`,
        },
        cdn: {
          resolution: 'variable',
          frameRate: 'variable',
          ingestionType: 'rtmp',
        },
      },
    });

    const stream = streamResponse.data;

    // 3. Bind Broadcast to Stream
    if (broadcast.id && stream.id) {
      await youtube.liveBroadcasts.bind({
        id: broadcast.id,
        streamId: stream.id,
        part: ['id', 'contentDetails'],
      });
    }

    return {
      broadcastId: broadcast.id, // the Video ID
      streamKey: stream.cdn?.ingestionInfo?.streamName, // Teacher streams here
      streamUrl: stream.cdn?.ingestionInfo?.ingestionAddress, // rtmp://a.rtmp.youtube.com/live2
    };
  }
}
