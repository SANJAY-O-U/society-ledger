const jwt = require('jsonwebtoken');
const User = require('../models/User');
const { asyncHandler } = require('./asyncHandler');

// ─── Protect Routes ───────────────────────────────────────────────────────────
exports.protect = asyncHandler(async (req, res, next) => {
  let token;

  if (req.headers.authorization && req.headers.authorization.startsWith('Bearer')) {
    token = req.headers.authorization.split(' ')[1];
  }

  if (!token) {
    return res.status(401).json({ success: false, message: 'Not authorized. No token provided.' });
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    
    const user = await User.findById(decoded.id).populate('member');
    if (!user) {
      return res.status(401).json({ success: false, message: 'User not found.' });
    }
    if (!user.isActive) {
      return res.status(401).json({ success: false, message: 'Account is deactivated.' });
    }
    if (user.changedPasswordAfter(decoded.iat)) {
      return res.status(401).json({ success: false, message: 'Password was changed. Please login again.' });
    }

    req.user = user;
    next();
  } catch (err) {
    return res.status(401).json({ success: false, message: 'Token is invalid or expired.' });
  }
});

// ─── Role Authorization ───────────────────────────────────────────────────────
exports.authorize = (...roles) => {
  return (req, res, next) => {
    if (!roles.includes(req.user.role)) {
      return res.status(403).json({
        success: false,
        message: `Role '${req.user.role}' is not authorized for this action.`,
      });
    }
    next();
  };
};

// ─── Admin Only ───────────────────────────────────────────────────────────────
exports.adminOnly = exports.authorize('admin');

// ─── Admin or Treasurer ───────────────────────────────────────────────────────
exports.financeAccess = exports.authorize('admin', 'treasurer', 'chairman');

// ─── Management Access ─────────────────────────────────────────────────────────
exports.managementAccess = exports.authorize('admin', 'chairman', 'secretary', 'treasurer');
