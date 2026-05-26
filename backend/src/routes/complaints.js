const express = require('express');
const router = express.Router();
const { protect, managementAccess } = require('../middleware/auth');
const { asyncHandler } = require('../middleware/asyncHandler');
const { Complaint } = require('../models/index');
const Member = require('../models/Member');
const upload = require('../utils/fileUpload');
const { sendPushNotification } = require('../services/notificationService');

router.use(protect);

// GET all complaints
router.get('/', asyncHandler(async (req, res) => {
  const { page = 1, limit = 20, status, category, priority } = req.query;
  const filter = {};

  if (req.user.role === 'member') {
    const member = await Member.findOne({ user: req.user.id });
    if (member) filter.member = member._id;
  }

  if (status) filter.status = status;
  if (category) filter.category = category;
  if (priority) filter.priority = priority;

  const total = await Complaint.countDocuments(filter);
  const complaints = await Complaint.find(filter)
    .sort({ createdAt: -1 })
    .skip((page - 1) * limit)
    .limit(parseInt(limit))
    .populate({ path: 'member', populate: { path: 'user', select: 'name' } })
    .populate('assignedTo', 'name role');

  res.json({ success: true, data: complaints, pagination: { total, page: parseInt(page), pages: Math.ceil(total / limit) } });
}));

// GET single complaint
router.get('/:id', asyncHandler(async (req, res) => {
  const complaint = await Complaint.findById(req.params.id)
    .populate({ path: 'member', populate: { path: 'user', select: 'name phone' } })
    .populate('assignedTo', 'name role')
    .populate('responses.respondedBy', 'name role');
  if (!complaint) return res.status(404).json({ success: false, message: 'Complaint not found' });
  res.json({ success: true, data: complaint });
}));

// POST create complaint (member)
router.post('/', upload.array('images', 5), asyncHandler(async (req, res) => {
  const member = await Member.findOne({ user: req.user.id });
  if (!member) return res.status(400).json({ success: false, message: 'Only members can raise complaints' });

  const { title, description, category, priority } = req.body;
  const images = req.files?.map((f) => ({ url: `/uploads/${f.filename}` })) || [];

  const complaint = await Complaint.create({
    member: member._id,
    user: req.user.id,
    title,
    description,
    category,
    priority: priority || 'medium',
    images,
  });

  res.status(201).json({ success: true, data: complaint });
}));

// PUT update status (management)
router.put('/:id/status', managementAccess, asyncHandler(async (req, res) => {
  const { status, assignedTo } = req.body;
  const complaint = await Complaint.findById(req.params.id);
  if (!complaint) return res.status(404).json({ success: false, message: 'Complaint not found' });

  complaint.status = status;
  if (assignedTo) complaint.assignedTo = assignedTo;
  if (status === 'resolved') complaint.resolvedAt = new Date();
  if (status === 'closed') complaint.closedAt = new Date();
  await complaint.save();

  // Notify member
  const member = await Member.findById(complaint.member).populate('user', 'name');
  await sendPushNotification({
    userId: complaint.user,
    title: `Complaint ${status.replace('_', ' ').toUpperCase()}`,
    body: `Your complaint "${complaint.title}" has been updated to ${status}`,
    data: { type: 'complaint_update', complaintId: complaint._id.toString() },
  }).catch(() => {});

  res.json({ success: true, data: complaint });
}));

// POST add response
router.post('/:id/respond', asyncHandler(async (req, res) => {
  const { message, isInternal } = req.body;
  const complaint = await Complaint.findById(req.params.id);
  if (!complaint) return res.status(404).json({ success: false, message: 'Complaint not found' });

  complaint.responses.push({
    respondedBy: req.user.id,
    message,
    isInternal: isInternal || false,
  });
  await complaint.save();

  // Notify if response is from management
  if (req.user.role !== 'member' && !isInternal) {
    await sendPushNotification({
      userId: complaint.user,
      title: 'New Response on Your Complaint',
      body: `${req.user.name} responded: ${message.substring(0, 50)}...`,
      data: { type: 'complaint_update', complaintId: complaint._id.toString() },
    }).catch(() => {});
  }

  res.json({ success: true, data: complaint });
}));

// PUT rate/feedback
router.put('/:id/feedback', asyncHandler(async (req, res) => {
  const { rating, feedback } = req.body;
  const complaint = await Complaint.findById(req.params.id);
  if (!complaint) return res.status(404).json({ success: false, message: 'Complaint not found' });
  if (complaint.user.toString() !== req.user.id.toString()) {
    return res.status(403).json({ success: false, message: 'Access denied' });
  }
  complaint.rating = rating;
  complaint.feedback = feedback;
  await complaint.save();
  res.json({ success: true, message: 'Feedback submitted' });
}));

module.exports = router;
