const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const admin = require('../config/firebase');
const User = require('../models/User');
const { asyncHandler } = require('../middleware/asyncHandler');
const { sendEmail } = require('../services/emailService');
const logger = require('../utils/logger');

// ─── Helper: Send token response ──────────────────────────────────────────────
const sendTokenResponse = (user, statusCode, res) => {
  const accessToken = user.generateAccessToken();
  const refreshToken = user.generateRefreshToken();

  // Remove sensitive fields
  const userObj = user.toObject();
  delete userObj.password;
  delete userObj.refreshToken;
  delete userObj.passwordResetToken;
  delete userObj.passwordResetExpire;

  res.status(statusCode).json({
    success: true,
    accessToken,
    refreshToken,
    user: userObj,
  });
};

// ─── @route  POST /api/auth/send-otp ─────────────────────────────────────────
// ─── @desc   Send OTP to mobile via Firebase ──────────────────────────────────
exports.sendOTP = asyncHandler(async (req, res) => {
  const { phone } = req.body;
  if (!phone) return res.status(400).json({ success: false, message: 'Phone number is required' });

  // Firebase handles OTP sending on the client side
  // This endpoint validates the phone is registered
  const user = await User.findOne({ phone });

  res.json({
    success: true,
    message: 'Proceed with Firebase OTP verification',
    isRegistered: !!user,
    phone,
  });
});

// ─── @route  POST /api/auth/verify-otp ───────────────────────────────────────
// ─── @desc   Verify Firebase OTP token & login ────────────────────────────────
exports.verifyOTP = asyncHandler(async (req, res) => {
  const { firebaseToken, phone, name, fcmToken } = req.body;

  if (!firebaseToken || !phone) {
    return res.status(400).json({ success: false, message: 'Firebase token and phone are required' });
  }

  // Verify the Firebase token
  let decodedToken;
  try {
    decodedToken = await admin.auth().verifyIdToken(firebaseToken);
  } catch (err) {
    logger.error('Firebase token verification failed:', err);
    return res.status(401).json({ success: false, message: 'OTP verification failed' });
  }

  // Extract phone from Firebase token (normalized format)
  const firebasePhone = decodedToken.phone_number;
  const normalizedPhone = phone.replace(/\D/g, '').slice(-10);

  if (!firebasePhone || !firebasePhone.includes(normalizedPhone)) {
    return res.status(401).json({ success: false, message: 'Phone number mismatch' });
  }

  let user = await User.findOne({ phone: normalizedPhone });

  if (!user) {
    // Auto-register new user
    user = await User.create({
      name: name || `User ${normalizedPhone}`,
      phone: normalizedPhone,
      isPhoneVerified: true,
    });
  } else {
    user.isPhoneVerified = true;
    user.lastLogin = new Date();
    await user.save();
  }

  if (fcmToken) await user.addFCMToken(fcmToken);

  sendTokenResponse(user, 200, res);
});

// ─── @route  POST /api/auth/register ─────────────────────────────────────────
exports.register = asyncHandler(async (req, res) => {
  const { name, email, phone, password, role } = req.body;

  // Only admin can create admin/management users
  const allowedRoles = ['member'];
  const finalRole = allowedRoles.includes(role) ? role : 'member';

  const user = await User.create({ name, email, phone, password, role: finalRole });

  // Send welcome email
  if (email) {
    await sendEmail({
      to: email,
      subject: 'Welcome to Society Ledger',
      template: 'welcome',
      data: { name },
    }).catch(() => {}); // Non-blocking
  }

  sendTokenResponse(user, 201, res);
});

// ─── @route  POST /api/auth/login ────────────────────────────────────────────
exports.login = asyncHandler(async (req, res) => {
  const { email, phone, password } = req.body;

  if (!password || (!email && !phone)) {
    return res.status(400).json({ success: false, message: 'Please provide credentials' });
  }

  const query = email ? { email: email.toLowerCase() } : { phone };
  const user = await User.findOne(query).select('+password');

  if (!user || !user.password) {
    return res.status(401).json({ success: false, message: 'Invalid credentials' });
  }

  const isMatch = await user.comparePassword(password);
  if (!isMatch) {
    return res.status(401).json({ success: false, message: 'Invalid credentials' });
  }

  if (!user.isActive) {
    return res.status(401).json({ success: false, message: 'Account is deactivated' });
  }

  user.lastLogin = new Date();
  await user.save({ validateBeforeSave: false });

  sendTokenResponse(user, 200, res);
});

// ─── @route  POST /api/auth/refresh-token ────────────────────────────────────
exports.refreshToken = asyncHandler(async (req, res) => {
  const { refreshToken } = req.body;
  if (!refreshToken) {
    return res.status(400).json({ success: false, message: 'Refresh token required' });
  }

  let decoded;
  try {
    decoded = jwt.verify(refreshToken, process.env.JWT_REFRESH_SECRET);
  } catch {
    return res.status(401).json({ success: false, message: 'Invalid or expired refresh token' });
  }

  const user = await User.findById(decoded.id);
  if (!user || !user.isActive) {
    return res.status(401).json({ success: false, message: 'User not found or inactive' });
  }

  const newAccessToken = user.generateAccessToken();
  res.json({ success: true, accessToken: newAccessToken });
});

// ─── @route  GET /api/auth/me ─────────────────────────────────────────────────
exports.getMe = asyncHandler(async (req, res) => {
  const user = await User.findById(req.user.id).populate({
    path: 'member',
    select: 'flatNumber wing monthlyMaintenance isActive occupancyStatus',
  });
  res.json({ success: true, user });
});

// ─── @route  PUT /api/auth/update-profile ────────────────────────────────────
exports.updateProfile = asyncHandler(async (req, res) => {
  const allowedFields = ['name', 'email'];
  const updates = {};
  allowedFields.forEach((f) => { if (req.body[f] !== undefined) updates[f] = req.body[f]; });

  const user = await User.findByIdAndUpdate(req.user.id, updates, { new: true, runValidators: true });
  res.json({ success: true, user });
});

// ─── @route  PUT /api/auth/change-password ───────────────────────────────────
exports.changePassword = asyncHandler(async (req, res) => {
  const { currentPassword, newPassword } = req.body;
  const user = await User.findById(req.user.id).select('+password');

  if (user.password) {
    const isMatch = await user.comparePassword(currentPassword);
    if (!isMatch) {
      return res.status(400).json({ success: false, message: 'Current password is incorrect' });
    }
  }

  user.password = newPassword;
  await user.save();
  res.json({ success: true, message: 'Password changed successfully' });
});

// ─── @route  POST /api/auth/forgot-password ──────────────────────────────────
exports.forgotPassword = asyncHandler(async (req, res) => {
  const { email } = req.body;
  const user = await User.findOne({ email });

  if (!user) {
    return res.status(404).json({ success: false, message: 'No account with that email' });
  }

  const resetToken = crypto.randomBytes(20).toString('hex');
  user.passwordResetToken = crypto.createHash('sha256').update(resetToken).digest('hex');
  user.passwordResetExpire = Date.now() + 10 * 60 * 1000; // 10 minutes
  await user.save({ validateBeforeSave: false });

  const resetUrl = `${process.env.FRONTEND_URL}/reset-password/${resetToken}`;
  await sendEmail({
    to: email,
    subject: 'Password Reset Request',
    template: 'resetPassword',
    data: { name: user.name, resetUrl },
  });

  res.json({ success: true, message: 'Password reset email sent' });
});

// ─── @route  PUT /api/auth/reset-password/:token ─────────────────────────────
exports.resetPassword = asyncHandler(async (req, res) => {
  const resetToken = crypto.createHash('sha256').update(req.params.token).digest('hex');
  const user = await User.findOne({
    passwordResetToken: resetToken,
    passwordResetExpire: { $gt: Date.now() },
  });

  if (!user) {
    return res.status(400).json({ success: false, message: 'Invalid or expired reset token' });
  }

  user.password = req.body.password;
  user.passwordResetToken = undefined;
  user.passwordResetExpire = undefined;
  await user.save();

  sendTokenResponse(user, 200, res);
});

// ─── @route  PUT /api/auth/fcm-token ─────────────────────────────────────────
exports.updateFCMToken = asyncHandler(async (req, res) => {
  const { fcmToken } = req.body;
  if (!fcmToken) return res.status(400).json({ success: false, message: 'FCM token required' });

  await req.user.addFCMToken(fcmToken);
  res.json({ success: true, message: 'FCM token updated' });
});

// ─── @route  POST /api/auth/logout ───────────────────────────────────────────
exports.logout = asyncHandler(async (req, res) => {
  const { fcmToken } = req.body;
  if (fcmToken) {
    req.user.fcmTokens = req.user.fcmTokens.filter((t) => t !== fcmToken);
    await req.user.save({ validateBeforeSave: false });
  }
  res.json({ success: true, message: 'Logged out successfully' });
});
