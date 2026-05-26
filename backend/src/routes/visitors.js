const express = require('express');
const router  = express.Router();
const crypto  = require('crypto');
const { protect, managementAccess } = require('../middleware/auth');
const { asyncHandler } = require('../middleware/asyncHandler');
const Visitor = require('../models/Visitor');
const Member  = require('../models/Member');
const { sendPushNotification } = require('../services/notificationService');

router.use(protect);

// ─── GET  all active visitors (security / management) ────────────────────────
router.get('/', managementAccess, asyncHandler(async (req, res) => {
  const { page = 1, limit = 20, active, memberId } = req.query;
  const filter = {};
  if (active === 'true')  filter.checkOut = { $exists: false };
  if (active === 'false') filter.checkOut = { $exists: true };
  if (memberId) filter.host = memberId;

  const total    = await Visitor.countDocuments(filter);
  const visitors = await Visitor.find(filter)
    .sort({ checkIn: -1 })
    .skip((page - 1) * limit)
    .limit(parseInt(limit))
    .populate({ path: 'host', populate: { path: 'user', select: 'name phone' } })
    .populate('loggedBy', 'name role');

  res.json({ success: true, data: visitors, pagination: { total, page: parseInt(page), pages: Math.ceil(total / limit) } });
}));

// ─── GET  my visitors (member) ───────────────────────────────────────────────
router.get('/my', asyncHandler(async (req, res) => {
  const member = await Member.findOne({ user: req.user.id });
  if (!member) return res.json({ success: true, data: [] });

  const visitors = await Visitor.find({ host: member._id }).sort({ checkIn: -1 }).limit(50);
  res.json({ success: true, data: visitors });
}));

// ─── POST check-in a visitor (security logs) ─────────────────────────────────
router.post('/check-in', managementAccess, asyncHandler(async (req, res) => {
  const { name, phone, purpose, hostFlatId, vehicleNumber, idType, idNumber, photo, preApprovedToken } = req.body;

  // Validate pre-approval token if given
  if (preApprovedToken) {
    const preApproved = await Visitor.findOne({
      preApprovedToken,
      preApprovedExpiry: { $gt: new Date() },
      checkIn: { $exists: false },
    });
    if (!preApproved) {
      return res.status(400).json({ success: false, message: 'Invalid or expired pre-approval token' });
    }
    preApproved.checkIn  = new Date();
    preApproved.isActive = true;
    preApproved.loggedBy = req.user.id;
    await preApproved.save();

    // Notify host
    await sendPushNotification({
      userId: preApproved.hostUser,
      title: '🔔 Your visitor has arrived',
      body: `${preApproved.name} has checked in at the gate`,
      data: { type: 'visitor', visitorId: preApproved._id.toString() },
    }).catch(() => {});

    return res.json({ success: true, data: preApproved });
  }

  const host = await Member.findById(hostFlatId).populate('user');
  if (!host) return res.status(404).json({ success: false, message: 'Host flat not found' });

  const visitor = await Visitor.create({
    name, phone, purpose, vehicleNumber, idType, idNumber, photo,
    host: hostFlatId,
    hostUser: host.user._id,
    checkIn: new Date(),
    loggedBy: req.user.id,
  });

  // Notify host
  await sendPushNotification({
    userId: host.user._id,
    title: '🔔 Visitor at Gate',
    body: `${name} is at the main gate to see you`,
    data: { type: 'visitor', visitorId: visitor._id.toString() },
  }).catch(() => {});

  res.status(201).json({ success: true, data: visitor });
}));

// ─── PUT check-out a visitor ──────────────────────────────────────────────────
router.put('/:id/check-out', managementAccess, asyncHandler(async (req, res) => {
  const visitor = await Visitor.findByIdAndUpdate(
    req.params.id,
    { checkOut: new Date(), isActive: false },
    { new: true },
  );
  if (!visitor) return res.status(404).json({ success: false, message: 'Visitor not found' });
  res.json({ success: true, data: visitor });
}));

// ─── POST generate pre-approval QR (member generates for their guest) ─────────
router.post('/pre-approve', asyncHandler(async (req, res) => {
  const { visitorName, visitorPhone, purpose, validForHours = 24 } = req.body;
  const member = await Member.findOne({ user: req.user.id });
  if (!member) return res.status(400).json({ success: false, message: 'Only members can pre-approve visitors' });

  const token   = crypto.randomBytes(16).toString('hex');
  const expiry  = new Date(Date.now() + validForHours * 60 * 60 * 1000);

  const visitor = await Visitor.create({
    name: visitorName,
    phone: visitorPhone,
    purpose: purpose || 'guest',
    host: member._id,
    hostUser: req.user.id,
    preApproved: true,
    preApprovedToken: token,
    preApprovedExpiry: expiry,
  });

  res.status(201).json({
    success: true,
    data: visitor,
    token,
    qrData: `SOCIETY_VISITOR:${token}`,
    validUntil: expiry,
  });
}));

// ─── GET today's visitor log ──────────────────────────────────────────────────
router.get('/today', managementAccess, asyncHandler(async (req, res) => {
  const start = new Date(); start.setHours(0, 0, 0, 0);
  const end   = new Date(); end.setHours(23, 59, 59, 999);

  const visitors = await Visitor.find({ checkIn: { $gte: start, $lte: end } })
    .sort({ checkIn: -1 })
    .populate({ path: 'host', populate: { path: 'user', select: 'name' } });

  res.json({ success: true, data: visitors, count: visitors.length });
}));

module.exports = router;
