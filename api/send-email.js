const nodemailer = require('nodemailer');

module.exports = async (req, res) => {
  // Set CORS headers to allow requests from local development if needed
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

  const { to, subject, htmlBody } = req.body;
  const authHeader = req.headers.authorization;

  // Validate request parameters
  if (!to || !subject || !htmlBody) {
    return res.status(400).json({ error: 'Missing required fields: to, subject, htmlBody' });
  }

  // Retrieve SMTP configuration from Environment Variables
  const smtpUsername = process.env.SMTP_USERNAME;
  const smtpPasswordValue = process.env.SMTP_PASSWORD;
  const smtpServer = process.env.SMTP_SERVER;
  const smtpPort = process.env.SMTP_PORT ? parseInt(process.env.SMTP_PORT, 10) : 587;

  if (!smtpUsername || !smtpPasswordValue || !smtpServer) {
    return res.status(500).json({ error: 'SMTP server environment variables are not configured on Vercel' });
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
    // Setup SMTP Transporter
    const transporter = nodemailer.createTransport({
      host: smtpServer,
      port: smtpPort,
      secure: smtpPort === 465, // True for port 465, false for 587 (uses STARTTLS)
      auth: {
        user: smtpUsername,
        pass: cleanPassword,
      },
      tls: {
        rejectUnauthorized: false // Match mailer's allowInsecure: true
      }
    });

    const mailOptions = {
      from: `"Health Support System" <${smtpUsername}>`,
      to,
      subject,
      html: htmlBody,
    };

    const info = await transporter.sendMail(mailOptions);
    return res.status(200).json({ message: 'Email sent successfully', messageId: info.messageId });
  } catch (error) {
    console.error('SMTP sending error:', error);
    return res.status(500).json({ error: 'Failed to send email', details: error.message });
  }
};
