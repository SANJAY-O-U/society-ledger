// ============================================================
// routes/auth.js
// ============================================================
const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/auth');
const {
  sendOTP, verifyOTP, register, login, refreshToken,
  getMe, updateProfile, changePassword,
  forgotPassword, resetPassword, updateFCMToken, logout,
} = require('../controllers/authController');

router.post('/send-otp', sendOTP);
router.post('/verify-otp', verifyOTP);
router.post('/register', register);
router.post('/login', login);
router.post('/refresh-token', refreshToken);
router.post('/forgot-password', forgotPassword);
router.put('/reset-password/:token', resetPassword);

// Protected
router.use(protect);
router.get('/me', getMe);
router.put('/update-profile', updateProfile);
router.put('/change-password', changePassword);
router.put('/fcm-token', updateFCMToken);
router.post('/logout', logout);

module.exports = router;
