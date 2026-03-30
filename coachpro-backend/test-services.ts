import 'dotenv/config';
import { S3Client, GetObjectCommand, PutObjectCommand, DeleteObjectCommand } from '@aws-sdk/client-s3';
import { google } from 'googleapis';

async function testStorage() {
  console.log('--- Testing Backblaze B2 Storage ---');
  try {
    const s3 = new S3Client({
      region: process.env.B2_REGION || 'us-east-005',
      endpoint: process.env.B2_ENDPOINT || 'https://s3.us-east-005.backblazeb2.com',
      credentials: {
        accessKeyId: process.env.B2_KEY_ID!,
        secretAccessKey: process.env.B2_APP_KEY!,
      },
    });

    const bucketName = process.env.B2_BUCKET_NAME!;
    if (!bucketName) {
      throw new Error('B2_BUCKET_NAME is not set in .env');
    }

    const testFileKey = `test-folder/test-upload-${Date.now()}.txt`;
    const testFileContent = 'Hello from testing script!';

    console.log(`[Storage] Uploading to ${bucketName}/${testFileKey}...`);
    await s3.send(new PutObjectCommand({
      Bucket: bucketName,
      Key: testFileKey,
      Body: Buffer.from(testFileContent),
      ContentType: 'text/plain',
    }));
    console.log('[Storage] Upload successful!');

    console.log(`[Storage] Downloading ${testFileKey}...`);
    const getRes = await s3.send(new GetObjectCommand({
      Bucket: bucketName,
      Key: testFileKey,
    }));
    
    const bodyStr = await getRes.Body?.transformToString();
    if (bodyStr === testFileContent) {
      console.log(`[Storage] Downloaded content matches!`);
    } else {
      console.error(`[Storage] Downloaded content mismatch. Expected: ${testFileContent}, Got: ${bodyStr}`);
    }

    console.log(`[Storage] Cleaning up (deleting)...`);
    await s3.send(new DeleteObjectCommand({
      Bucket: bucketName,
      Key: testFileKey,
    }));
    console.log('[Storage] Delete successful!');
    console.log('--- Storage Test Passed! ---\n');

  } catch (error: any) {
    console.error('[Storage] Test failed with error:', error);
    console.log('\n');
  }
}

async function testYouTube() {
  console.log('--- Testing YouTube API ---');
  try {
    const clientId = process.env.YOUTUBE_CLIENT_ID;
    const clientSecret = process.env.YOUTUBE_CLIENT_SECRET;
    const redirectUri = process.env.YOUTUBE_REDIRECT_URI;
    const refreshToken = process.env.YOUTUBE_REFRESH_TOKEN;

    if (!clientId || !clientSecret || !refreshToken) {
      throw new Error('Missing YouTube credentials in .env');
    }

    const oauth2Client = new google.auth.OAuth2(clientId, clientSecret, redirectUri);
    oauth2Client.setCredentials({ refresh_token: refreshToken });

    const youtube = google.youtube({ version: 'v3', auth: oauth2Client });

    console.log('[YouTube] Fetching channel info...');
    const result = await youtube.channels.list({
      part: ['snippet', 'contentDetails', 'statistics'],
      mine: true,
    });

    if (result.data.items && result.data.items.length > 0) {
      const channel = result.data.items[0];
      console.log(`[YouTube] Channel Found: ${channel.snippet?.title} (ID: ${channel.id})`);
      console.log(`[YouTube] View Count: ${channel.statistics?.viewCount}, Subscriber Count: ${channel.statistics?.subscriberCount}`);
      console.log('--- YouTube Test Passed! ---\n');
    } else {
      console.log('[YouTube] No channels found for this account. Authentication might still be working, but no channel exists.');
    }

  } catch (error: any) {
    console.error('[YouTube] Test failed with error:', error);
    console.log('\n');
  }
}

async function runTests() {
  await testStorage();
  await testYouTube();
}

runTests();
