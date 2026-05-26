const mongoose = require('mongoose');

// ─── Payment Schema ───────────────────────────────────────────────────────────
const paymentSchema = new mongoose.Schema({
  member: { type: mongoose.Schema.Types.ObjectId, ref: 'Member', required: true, index: true },
  user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  amount: { type: Number, required: true, min: 0 },
  razorpayOrderId: { type: String, unique: true, sparse: true },
  razorpayPaymentId: { type: String, unique: true, sparse: true },
  razorpaySignature: String,
  status: { type: String, enum: ['created', 'pending', 'paid', 'failed', 'refunded'], default: 'created' },
  paymentMethod: { type: String, enum: ['upi', 'card', 'net_banking', 'wallet', 'cash', 'cheque', 'neft'], default: 'upi' },
  description: { type: String, required: true },
  month: Number,
  year: Number,
  ledgerTransaction: { type: mongoose.Schema.Types.ObjectId, ref: 'LedgerTransaction' },
  failureReason: String,
  refundId: String,
  paidAt: Date,
  metadata: mongoose.Schema.Types.Mixed,
}, { timestamps: true });

paymentSchema.index({ member: 1, status: 1 });
paymentSchema.index({ razorpayOrderId: 1 });

// ─── Expense Schema ───────────────────────────────────────────────────────────
const expenseSchema = new mongoose.Schema({
  category: {
    type: String,
    enum: ['property_tax', 'water_bill', 'electricity_bill', 'security_salary', 'cleaning', 'lift_maintenance', 'repairs', 'garden', 'admin', 'legal', 'insurance', 'miscellaneous'],
    required: true,
  },
  title: { type: String, required: true, trim: true, maxlength: 200 },
  description: { type: String, trim: true, maxlength: 1000 },
  amount: { type: Number, required: true, min: 0 },
  date: { type: Date, default: Date.now, index: true },
  month: Number,
  year: Number,
  vendor: {
    name: String,
    contact: String,
    invoiceNumber: String,
  },
  invoiceUrl: String,
  status: { type: String, enum: ['pending_approval', 'approved', 'rejected', 'paid'], default: 'pending_approval' },
  approvedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  approvedAt: Date,
  rejectionReason: String,
  paymentMode: { type: String, enum: ['cash', 'bank_transfer', 'cheque', 'upi'], default: 'bank_transfer' },
  createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  notes: String,
}, { timestamps: true });

expenseSchema.index({ category: 1, date: -1 });
expenseSchema.index({ month: 1, year: 1 });

// ─── Complaint Schema ─────────────────────────────────────────────────────────
const complaintSchema = new mongoose.Schema({
  member: { type: mongoose.Schema.Types.ObjectId, ref: 'Member', required: true },
  user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  title: { type: String, required: true, trim: true, maxlength: 200 },
  description: { type: String, required: true, trim: true, maxlength: 2000 },
  category: {
    type: String,
    enum: ['maintenance', 'water', 'electricity', 'security', 'cleanliness', 'parking', 'noise', 'neighbor', 'structural', 'suggestion', 'other'],
    required: true,
  },
  priority: { type: String, enum: ['low', 'medium', 'high', 'urgent'], default: 'medium' },
  status: { type: String, enum: ['open', 'in_progress', 'resolved', 'closed', 'rejected'], default: 'open', index: true },
  images: [{ url: String, uploadedAt: { type: Date, default: Date.now } }],
  assignedTo: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  responses: [{
    respondedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    message: { type: String, required: true },
    timestamp: { type: Date, default: Date.now },
    isInternal: { type: Boolean, default: false },
  }],
  resolvedAt: Date,
  closedAt: Date,
  rating: { type: Number, min: 1, max: 5 },
  feedback: String,
  ticketNumber: { type: String, unique: true },
}, { timestamps: true });

complaintSchema.index({ member: 1, status: 1 });
complaintSchema.pre('save', async function (next) {
  if (!this.ticketNumber) {
    const count = await this.constructor.countDocuments();
    this.ticketNumber = `TKT${new Date().getFullYear()}${String(count + 1).padStart(5, '0')}`;
  }
  next();
});

// ─── Event Schema ─────────────────────────────────────────────────────────────
const eventSchema = new mongoose.Schema({
  title: { type: String, required: true, trim: true, maxlength: 200 },
  description: { type: String, trim: true, maxlength: 2000 },
  category: { type: String, enum: ['meeting', 'festival', 'maintenance_notice', 'sports', 'cultural', 'health', 'other'], required: true },
  startDate: { type: Date, required: true, index: true },
  endDate: { type: Date, required: true },
  venue: String,
  isVirtual: { type: Boolean, default: false },
  meetingLink: String,
  organizer: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  rsvp: [{
    member: { type: mongoose.Schema.Types.ObjectId, ref: 'Member' },
    status: { type: String, enum: ['attending', 'not_attending', 'maybe'], default: 'maybe' },
    respondedAt: { type: Date, default: Date.now },
  }],
  coverImage: String,
  isPublished: { type: Boolean, default: false },
  notificationSent: { type: Boolean, default: false },
  maxAttendees: Number,
  agenda: [{ time: String, topic: String, speaker: String }],
  attachments: [{ name: String, url: String }],
}, { timestamps: true });

eventSchema.index({ startDate: 1, isPublished: 1 });

// ─── Inventory Schema ─────────────────────────────────────────────────────────
const inventorySchema = new mongoose.Schema({
  itemName: { type: String, required: true, trim: true, maxlength: 200 },
  category: {
    type: String,
    enum: ['furniture', 'electronics', 'tools', 'cleaning', 'sports', 'event', 'safety', 'vehicle', 'other'],
    required: true,
  },
  description: String,
  quantity: { type: Number, required: true, min: 0, default: 1 },
  availableQuantity: { type: Number, default: 0 },
  unit: { type: String, default: 'piece' },
  purchaseDate: Date,
  purchasePrice: { type: Number, default: 0 },
  vendor: { name: String, contact: String, invoiceNumber: String },
  location: String,
  condition: { type: String, enum: ['excellent', 'good', 'fair', 'poor', 'under_repair', 'disposed'], default: 'good' },
  status: { type: String, enum: ['available', 'in_use', 'maintenance', 'disposed'], default: 'available' },
  checkoutLogs: [{
    checkedOutBy: { type: mongoose.Schema.Types.ObjectId, ref: 'Member' },
    checkedOutAt: { type: Date, default: Date.now },
    returnedAt: Date,
    quantity: { type: Number, default: 1 },
    purpose: String,
    condition: String,
  }],
  maintenanceLogs: [{
    date: { type: Date, default: Date.now },
    description: String,
    cost: Number,
    performedBy: String,
  }],
  images: [String],
  createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  tags: [String],
}, { timestamps: true });

inventorySchema.index({ category: 1, status: 1 });

// ─── Document Schema ──────────────────────────────────────────────────────────
const documentSchema = new mongoose.Schema({
  title: { type: String, required: true, trim: true, maxlength: 200 },
  description: String,
  category: {
    type: String,
    enum: ['notice', 'agm', 'circular', 'bill', 'policy', 'legal', 'financial', 'other'],
    required: true,
  },
  fileUrl: { type: String, required: true },
  fileName: String,
  fileSize: Number,
  mimeType: String,
  isPublic: { type: Boolean, default: true },
  uploadedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  expiryDate: Date,
  tags: [String],
  viewCount: { type: Number, default: 0 },
  downloadCount: { type: Number, default: 0 },
}, { timestamps: true });

documentSchema.index({ category: 1, createdAt: -1 });

// ─── Notification Schema ──────────────────────────────────────────────────────
const notificationSchema = new mongoose.Schema({
  title: { type: String, required: true },
  body: { type: String, required: true },
  type: {
    type: String,
    enum: ['payment_reminder', 'payment_received', 'complaint_update', 'event', 'notice', 'maintenance', 'general'],
    required: true,
  },
  targetType: { type: String, enum: ['all', 'specific', 'role'], default: 'all' },
  targetUsers: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }],
  targetRoles: [String],
  data: mongoose.Schema.Types.Mixed,
  sentAt: Date,
  status: { type: String, enum: ['pending', 'sent', 'failed'], default: 'pending' },
  readBy: [{ user: { type: mongoose.Schema.Types.ObjectId, ref: 'User' }, readAt: Date }],
  createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
}, { timestamps: true });

notificationSchema.index({ targetUsers: 1, createdAt: -1 });

module.exports = {
  Payment: mongoose.model('Payment', paymentSchema),
  Expense: mongoose.model('Expense', expenseSchema),
  Complaint: mongoose.model('Complaint', complaintSchema),
  Event: mongoose.model('Event', eventSchema),
  Inventory: mongoose.model('Inventory', inventorySchema),
  Document: mongoose.model('Document', documentSchema),
  Notification: mongoose.model('Notification', notificationSchema),
};
