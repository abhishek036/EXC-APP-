import express from 'express';
import { google } from 'googleapis';
import dotenv from 'dotenv';
dotenv.config();

const app = express();
const oauth2Client = new google.auth.OAuth2(
  process.env.YOUTUBE_CLIENT_ID,
  process.env.YOUTUBE_CLIENT_SECRET,
  process.env.YOUTUBE_REDIRECT_URI
);

// Get the URL immediately and print it out
const authUrl = oauth2Client.generateAuthUrl({
  access_type: 'offline',
  scope: ['https://www.googleapis.com/auth/youtube.upload', 'https://www.googleapis.com/auth/youtube'],
  prompt: 'consent'
});

console.log('\n======================================================');
console.log('🔗 CLICK THIS LINK TO AUTHORIZE YOUTUBE:');
console.log(authUrl);
console.log('======================================================\n');

app.get('/api/youtube/callback', async (req, res) => {
  try {
    const { tokens } = await oauth2Client.getToken(req.query.code as string);
    console.log('\n\n✅ SUCCESS! YOUR YOUTUBE REFRESH TOKEN IS:\n\n' + tokens.refresh_token + '\n\n');
    res.send('<h1 style="color:green;font-family:sans-serif;text-align:center;margin-top:50px;">Success! You can close this window. Check your VS Code terminal for the token.</h1>');
    setTimeout(() => process.exit(0), 1000); // Wait a second for network response to finish then exit
  } catch(e) {
    console.error(e);
    res.send('ERROR: ' + e);
    setTimeout(() => process.exit(1), 1000);
  }
});

app.listen(3000, () => {
  console.log('⏳ Waiting for you to login and be redirected...\n');
});
