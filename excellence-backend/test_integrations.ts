import { S3Client, PutObjectCommand, GetObjectCommand, DeleteObjectCommand } from '@aws-sdk/client-s3';
import { YoutubeService } from './src/modules/youtube/youtube.service';
import dotenv from 'dotenv';
dotenv.config();

async function runTests() {
  console.log('--- STARTING INTEGRATION TESTS ---\n');

  // TEST 1: Backblaze B2 Storage
  console.log('[1/2] Testing Backblaze B2 Storage...');
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
    const testKey = 'test-integration-upload.txt';
    const testData = 'Hello from Excellence Integration Tests!';

    console.log(`      -> Uploading test file to ${bucketName}/${testKey}...`);
    await s3.send(new PutObjectCommand({
      Bucket: bucketName,
      Key: testKey,
      Body: Buffer.from(testData, 'utf-8'),
      ContentType: 'text/plain',
    }));
    console.log('      -> Upload SUCCESS!');

    // Test Delete
    await s3.send(new DeleteObjectCommand({
      Bucket: bucketName,
      Key: testKey,
    }));
    console.log('      -> Cleanup/Delete SUCCESS!\n');
    console.log('✅ Backblaze B2 Integration is working perfectly!\n');

  } catch (error: any) {
    console.error('❌ Backblaze B2 Integration FAILED!');
    console.error('   Error:', error.message, '\n');
  }

  // TEST 2: YouTube API Integration
  console.log('[2/2] Testing YouTube Live API...');
  try {
    const ytService = new YoutubeService();
    
    // Set credentials from .env
    await ytService.setCredentials('test-institute-integration');

    console.log('      -> Attempting to define a private test broadcast on YouTube Channel...');
    // We create a completely 'private' broadcast so nobody is alerted on the channel
    const testStream = await ytService.createLiveStream(
      'Excellence Test Integration Stream',
      'This is an automated test from the Excellence backend.',
      'private'
    );
    
    console.log('      -> Broadcast creation SUCCESS!');
    console.log(`      -> Broadcast ID (Video ID): ${testStream.broadcastId}`);
    console.log(`      -> RTMP URL / Stream Key: ${testStream.streamUrl}/${testStream.streamKey}`);
    console.log('\n✅ YouTube Integration is working perfectly!\n');

  } catch (error: any) {
    console.error('❌ YouTube Integration FAILED!');
    console.error('   Notes: This usually means the YOUTUBE_REFRESH_TOKEN is expired or invalid.');
    console.error('   Error:', error.message, '\n');
  }

  console.log('--- INTEGRATION TESTS COMPLETE ---');
}

runTests();

