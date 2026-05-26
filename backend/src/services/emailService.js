// ============================================================
// services/emailService.js
// ============================================================
const nodemailer = require('nodemailer');
const logger = require('../utils/logger');

const transporter = nodemailer.createTransport({
  service: process.env.EMAIL_SERVICE || 'gmail',
  auth: { user: process.env.EMAIL_USER, pass: process.env.EMAIL_PASS },
});

const templates = {
  welcome: ({ name }) => ({
    subject: 'Welcome to Society Ledger',
    html: `<h2>Welcome, ${name}!</h2><p>Your Society Ledger account has been created.</p>`,
  }),
  resetPassword: ({ name, resetUrl }) => ({
    subject: 'Password Reset Request',
    html: `<h2>Hi ${name},</h2><p>Reset your password: <a href="${resetUrl}">Click here</a></p><p>Expires in 10 minutes.</p>`,
  }),
  paymentReminder: ({ name, amount, dueDate, flat }) => ({
    subject: '⚠️ Maintenance Payment Overdue',
    html: `<h2>Hi ${name},</h2><p>Your maintenance payment of <strong>₹${amount}</strong> for flat <strong>${flat}</strong> was due on <strong>${dueDate}</strong>.</p><p>Please pay immediately to avoid additional late fees.</p>`,
  }),
  paymentReceived: ({ name, amount, receiptNo }) => ({
    subject: '✅ Payment Receipt',
    html: `<h2>Hi ${name},</h2><p>Payment of <strong>₹${amount}</strong> received successfully.</p><p>Receipt No: <strong>${receiptNo}</strong></p>`,
  }),
};

exports.sendEmail = async ({ to, subject, template, data, html }) => {
  try {
    let emailContent = {};
    if (template && templates[template]) {
      emailContent = templates[template](data);
    } else {
      emailContent = { subject, html };
    }

    await transporter.sendMail({
      from: process.env.EMAIL_FROM,
      to,
      subject: emailContent.subject || subject,
      html: emailContent.html || html,
    });

    logger.info(`Email sent to ${to}: ${emailContent.subject}`);
  } catch (err) {
    logger.error('Email send error:', err);
    throw err;
  }
};
