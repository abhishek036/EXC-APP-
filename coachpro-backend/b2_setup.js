const axios = require('axios');

const KEY_ID = '87648cf21c05';
const APP_KEY = '005cbf6e698fc182315a761918acc83683e0aef50a';
const BUCKET_NAME = 'coachpro-' + Math.floor(Math.random() * 1000000) + '-storage';

async function setup() {
  try {
    const authString = Buffer.from(`${KEY_ID}:${APP_KEY}`).toString('base64');
    const authRes = await axios.get('https://api.backblazeb2.com/b2api/v2/b2_authorize_account', {
      headers: { Authorization: `Basic ${authString}` }
    });

    const apiUrl = authRes.data.apiUrl;
    const downloadUrl = authRes.data.downloadUrl;
    const authToken = authRes.data.authorizationToken;
    const accountId = authRes.data.accountId;

    console.log('Authorized. Account ID:', accountId);
    console.log('API URL:', apiUrl);

    // Get buckets
    const listRes = await axios.post(`${apiUrl}/b2api/v2/b2_list_buckets`, { accountId }, {
      headers: { Authorization: authToken }
    });

    let bucket = listRes.data.buckets.find(b => b.bucketType === 'allPrivate' && b.bucketName.startsWith('coachpro'));

    if (!bucket) {
      console.log('Creating new private bucket...');
      const createRes = await axios.post(`${apiUrl}/b2api/v2/b2_create_bucket`, {
        accountId,
        bucketName: BUCKET_NAME,
        bucketType: 'allPrivate'
      }, {
        headers: { Authorization: authToken }
      });
      bucket = createRes.data;
    }

    console.log('BUCKET_ID=' + bucket.bucketId);
    console.log('BUCKET_NAME=' + bucket.bucketName);
    console.log('DOWNLOAD_URL=' + downloadUrl);

  } catch (err) {
    console.error('Error:', err.response ? err.response.data : err.message);
  }
}

setup();
