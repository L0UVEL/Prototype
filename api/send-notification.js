const admin = require('firebase-admin');

// Initialize Firebase Admin SDK if not already initialized
if (!admin.apps.length) {
  try {
    // If FIREBASE_SERVICE_ACCOUNT is provided in Vercel, parse it and use it.
    // Otherwise, try to use default credentials (will fail locally without GOOGLE_APPLICATION_CREDENTIALS)
    const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT;
    if (serviceAccountJson) {
      admin.initializeApp({
        credential: admin.credential.cert(JSON.parse(serviceAccountJson)),
      });
    } else {
      admin.initializeApp();
    }
  } catch (error) {
    console.error('Firebase Admin initialization error:', error);
  }
}

module.exports = async (req, res) => {
  // Set CORS headers
  res.setHeader('Access-Control-Allow-Credentials', true);
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,OPTIONS,PATCH,DELETE,POST,PUT');
  res.setHeader(
    'Access-Control-Allow-Headers',
    'X-CSRF-Token, X-Requested-With, Accept, Accept-Version, Content-Length, Content-MD5, Content-Type, Date, X-Api-Version, Authorization'
  );

  // Handle preflight OPTIONS request
  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  // Only allow POST requests
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method Not Allowed' });
  }

  const { title, body, topic } = req.body;
  const authHeader = req.headers.authorization;

  // Validate request parameters
  if (!title || !body || !topic) {
    return res.status(400).json({ error: 'Missing required fields: title, body, topic' });
  }

  // Retrieve SMTP configuration from Environment Variables as our shared secret for simplicity
  const smtpPasswordValue = process.env.SMTP_PASSWORD;

  if (!smtpPasswordValue) {
    return res.status(500).json({ error: 'Authentication not configured on Vercel' });
  }

  // Simple token authorization check
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Unauthorized: Missing token' });
  }

  const token = authHeader.split(' ')[1];
  // Verify that the token matches the cleaned SMTP password
  const cleanPassword = smtpPasswordValue.replace(/\s/g, '');
  if (token !== cleanPassword) {
    return res.status(403).json({ error: 'Forbidden: Invalid authorization token' });
  }

  try {
    const message = {
      notification: {
        title: title,
        body: body,
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'high_importance_channel',
          defaultSound: true,
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            contentAvailable: true,
          },
        },
      },
      topic: topic,
    };

    // Send a message to devices subscribed to the provided topic.
    const response = await admin.messaging().send(message);
    return res.status(200).json({ message: 'Successfully sent notification', messageId: response });
  } catch (error) {
    console.error('Error sending message:', error);
    return res.status(500).json({ error: 'Failed to send notification', details: error.message });
  }
};
