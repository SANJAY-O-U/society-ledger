// ============================================================
// routes/events.js
// ============================================================
const express = require('express');
const eventsRouter = express.Router();
const { protect, managementAccess } = require('../middleware/auth');
const { asyncHandler } = require('../middleware/asyncHandler');
const { Event } = require('../models/index');
const Member = require('../models/Member');
const { sendBroadcastNotification } = require('../services/notificationService');

eventsRouter.use(protect);

eventsRouter.get('/', asyncHandler(async (req, res) => {
  const { upcoming, category, page = 1, limit = 20 } = req.query;
  const filter = { isPublished: true };
  if (upcoming === 'true') filter.startDate = { $gte: new Date() };
  if (category) filter.category = category;

  const total = await Event.countDocuments(filter);
  const events = await Event.find(filter)
    .sort({ startDate: 1 })
    .skip((page - 1) * limit)
    .limit(parseInt(limit))
    .populate('organizer', 'name role');

  res.json({ success: true, data: events, pagination: { total, page: parseInt(page), pages: Math.ceil(total / limit) } });
}));

eventsRouter.get('/:id', asyncHandler(async (req, res) => {
  const event = await Event.findById(req.params.id).populate('organizer', 'name role').populate('rsvp.member', 'flatNumber wing');
  if (!event) return res.status(404).json({ success: false, message: 'Event not found' });
  res.json({ success: true, data: event });
}));

eventsRouter.post('/', managementAccess, asyncHandler(async (req, res) => {
  const event = await Event.create({ ...req.body, organizer: req.user.id });
  if (event.isPublished) {
    await sendBroadcastNotification({
      title: `📅 New Event: ${event.title}`,
      body: `${new Date(event.startDate).toLocaleDateString()} at ${event.venue || 'Society Premises'}`,
      data: { type: 'event', eventId: event._id.toString() },
    }).catch(() => {});
    event.notificationSent = true;
    await event.save();
  }
  res.status(201).json({ success: true, data: event });
}));

eventsRouter.put('/:id', managementAccess, asyncHandler(async (req, res) => {
  const event = await Event.findByIdAndUpdate(req.params.id, req.body, { new: true, runValidators: true });
  if (!event) return res.status(404).json({ success: false, message: 'Event not found' });
  res.json({ success: true, data: event });
}));

eventsRouter.post('/:id/rsvp', asyncHandler(async (req, res) => {
  const { status } = req.body;
  const member = await Member.findOne({ user: req.user.id });
  const event = await Event.findById(req.params.id);
  if (!event || !member) return res.status(404).json({ success: false, message: 'Not found' });

  const existingRsvp = event.rsvp.find((r) => r.member.toString() === member._id.toString());
  if (existingRsvp) {
    existingRsvp.status = status;
  } else {
    event.rsvp.push({ member: member._id, status });
  }
  await event.save();
  res.json({ success: true, message: 'RSVP updated', rsvpStatus: status });
}));

eventsRouter.delete('/:id', managementAccess, asyncHandler(async (req, res) => {
  await Event.findByIdAndDelete(req.params.id);
  res.json({ success: true, message: 'Event deleted' });
}));

// ============================================================
// routes/inventory.js
// ============================================================
const inventoryRouter = express.Router();
const { Inventory } = require('../models/index');

inventoryRouter.use(protect);

inventoryRouter.get('/', asyncHandler(async (req, res) => {
  const { category, status, search, page = 1, limit = 20 } = req.query;
  const filter = {};
  if (category) filter.category = category;
  if (status) filter.status = status;
  if (search) filter.itemName = new RegExp(search, 'i');

  const total = await Inventory.countDocuments(filter);
  const items = await Inventory.find(filter).sort({ itemName: 1 }).skip((page - 1) * limit).limit(parseInt(limit));
  res.json({ success: true, data: items, pagination: { total, page: parseInt(page), pages: Math.ceil(total / limit) } });
}));

inventoryRouter.post('/', managementAccess, asyncHandler(async (req, res) => {
  const item = await Inventory.create({ ...req.body, availableQuantity: req.body.quantity, createdBy: req.user.id });
  res.status(201).json({ success: true, data: item });
}));

inventoryRouter.put('/:id', managementAccess, asyncHandler(async (req, res) => {
  const item = await Inventory.findByIdAndUpdate(req.params.id, req.body, { new: true });
  if (!item) return res.status(404).json({ success: false, message: 'Item not found' });
  res.json({ success: true, data: item });
}));

inventoryRouter.post('/:id/checkout', managementAccess, asyncHandler(async (req, res) => {
  const { memberId, quantity = 1, purpose } = req.body;
  const item = await Inventory.findById(req.params.id);
  if (!item) return res.status(404).json({ success: false, message: 'Item not found' });
  if (item.availableQuantity < quantity) {
    return res.status(400).json({ success: false, message: 'Insufficient quantity available' });
  }
  item.availableQuantity -= quantity;
  item.checkoutLogs.push({ checkedOutBy: memberId, quantity, purpose });
  if (item.availableQuantity === 0) item.status = 'in_use';
  await item.save();
  res.json({ success: true, data: item });
}));

inventoryRouter.post('/:id/checkin', managementAccess, asyncHandler(async (req, res) => {
  const { logId, condition } = req.body;
  const item = await Inventory.findById(req.params.id);
  if (!item) return res.status(404).json({ success: false, message: 'Item not found' });

  const log = item.checkoutLogs.id(logId);
  if (log) {
    log.returnedAt = new Date();
    log.condition = condition;
    item.availableQuantity += log.quantity;
  }
  if (item.availableQuantity > 0) item.status = 'available';
  await item.save();
  res.json({ success: true, data: item });
}));

// ============================================================
// routes/documents.js
// ============================================================
const documentsRouter = express.Router();
const { Document } = require('../models/index');
const upload = require('../utils/fileUpload');

documentsRouter.use(protect);

documentsRouter.get('/', asyncHandler(async (req, res) => {
  const { category, page = 1, limit = 20 } = req.query;
  const filter = { isPublic: true };
  if (category) filter.category = category;

  const total = await Document.countDocuments(filter);
  const docs = await Document.find(filter)
    .sort({ createdAt: -1 })
    .skip((page - 1) * limit)
    .limit(parseInt(limit))
    .populate('uploadedBy', 'name role');

  res.json({ success: true, data: docs, pagination: { total, page: parseInt(page), pages: Math.ceil(total / limit) } });
}));

documentsRouter.post('/', managementAccess, upload.single('file'), asyncHandler(async (req, res) => {
  if (!req.file) return res.status(400).json({ success: false, message: 'File is required' });

  const doc = await Document.create({
    title: req.body.title,
    description: req.body.description,
    category: req.body.category,
    fileUrl: `/uploads/${req.file.filename}`,
    fileName: req.file.originalname,
    fileSize: req.file.size,
    mimeType: req.file.mimetype,
    uploadedBy: req.user.id,
    tags: req.body.tags ? req.body.tags.split(',') : [],
  });

  if (req.body.notify === 'true') {
    await sendDocNotif({
      title: `📄 New Document: ${doc.title}`,
      body: doc.description || 'A new document has been uploaded',
      data: { type: 'notice', documentId: doc._id.toString() },
    }).catch(() => {});
  }

  res.status(201).json({ success: true, data: doc });
}));

documentsRouter.put('/:id/download', asyncHandler(async (req, res) => {
  await Document.findByIdAndUpdate(req.params.id, { $inc: { downloadCount: 1 } });
  res.json({ success: true });
}));

// ============================================================
// routes/notifications.js
// ============================================================
const notificationsRouter = express.Router();
const { Notification } = require('../models/index');
const User = require('../models/User');
const { sendPushNotification} = require('../services/notificationService');

notificationsRouter.use(protect);

notificationsRouter.get('/', asyncHandler(async (req, res) => {
  const notifications = await Notification.find({
    $or: [
      { targetType: 'all' },
      { targetUsers: req.user.id },
      { targetRoles: req.user.role },
    ],
  }).sort({ createdAt: -1 }).limit(50);

  const unreadCount = notifications.filter((n) => !n.readBy.some((r) => r.user.toString() === req.user.id.toString())).length;

  res.json({ success: true, data: notifications, unreadCount });
}));

notificationsRouter.put('/:id/read', asyncHandler(async (req, res) => {
  const notif = await Notification.findById(req.params.id);
  if (!notif) return res.status(404).json({ success: false, message: 'Not found' });
  if (!notif.readBy.some((r) => r.user.toString() === req.user.id.toString())) {
    notif.readBy.push({ user: req.user.id, readAt: new Date() });
    await notif.save();
  }
  res.json({ success: true });
}));

notificationsRouter.post('/send', managementAccess, asyncHandler(async (req, res) => {
  const { title, body, targetType, targetUsers, targetRoles, type, data } = req.body;

  const notification = await Notification.create({
    title,
    body,
    type: type || 'general',
    targetType: targetType || 'all',
    targetUsers,
    targetRoles,
    data,
    createdBy: req.user.id,
    sentAt: new Date(),
    status: 'pending',
  });

  if (targetType === 'all') {
    await sendBroadcastNotification({ title, body, data }).catch(() => {});
  } else if (targetType === 'specific' && targetUsers?.length) {
    for (const userId of targetUsers) {
      await sendPushNotification({ userId, title, body, data }).catch(() => {});
    }
  }

  notification.status = 'sent';
  await notification.save();

  res.json({ success: true, notification });
}));

// ============================================================
// routes/dashboard.js
// ============================================================
const dashboardRouter = express.Router();
const { getAdminDashboard, getMemberDashboard } = require('../controllers/dashboardController');

dashboardRouter.use(protect);
dashboardRouter.get('/admin', managementAccess, getAdminDashboard);
dashboardRouter.get('/member', getMemberDashboard);

// ─── Exports ──────────────────────────────────────────────────────────────────
module.exports = {
  eventsRouter,
  inventoryRouter,
  documentsRouter,
  notificationsRouter,
  dashboardRouter,
};
