const Razorpay = require('razorpay');
const crypto = require('crypto');
const { Payment } = require('../models/index');
const LedgerTransaction = require('../models/LedgerTransaction');
const Member = require('../models/Member');
const { asyncHandler } = require('../middleware/asyncHandler');
const { sendPushNotification } = require('../services/notificationService');
const logger = require('../utils/logger');

const razorpay = new Razorpay({
  key_id: process.env.RAZORPAY_KEY_ID,
  key_secret: process.env.RAZORPAY_KEY_SECRET,
});

// ─── @route  POST /api/payments/create-order ─────────────────────────────────
exports.createOrder = asyncHandler(async (req, res) => {
  const { amount, description, month, year } = req.body;

  if (!amount || amount <= 0) {
    return res.status(400).json({ success: false, message: 'Valid amount required' });
  }

  const member = await Member.findOne({ user: req.user.id });
  if (!member) {
    return res.status(404).json({ success: false, message: 'Member profile not found' });
  }

  // Create Razorpay order
  const razorpayOrder = await razorpay.orders.create({
    amount: Math.round(amount * 100), // paise
    currency: 'INR',
    receipt: `rcpt_${Date.now()}`,
    notes: {
      memberId: member._id.toString(),
      flatNumber: `${member.wing}-${member.flatNumber}`,
      month: month || '',
      year: year || '',
    },
  });

  // Save payment record
  const payment = await Payment.create({
    member: member._id,
    user: req.user.id,
    amount,
    razorpayOrderId: razorpayOrder.id,
    status: 'created',
    description: description || 'Maintenance Payment',
    month: month || new Date().getMonth() + 1,
    year: year || new Date().getFullYear(),
  });

  res.json({
    success: true,
    orderId: razorpayOrder.id,
    amount: razorpayOrder.amount,
    currency: razorpayOrder.currency,
    paymentId: payment._id,
    key: process.env.RAZORPAY_KEY_ID,
  });
});

// ─── @route  POST /api/payments/verify ───────────────────────────────────────
exports.verifyPayment = asyncHandler(async (req, res) => {
  const { razorpay_order_id, razorpay_payment_id, razorpay_signature, paymentId } = req.body;

  if (!razorpay_order_id || !razorpay_payment_id || !razorpay_signature) {
    return res.status(400).json({ success: false, message: 'Missing payment details' });
  }

  // Verify signature
  const body = `${razorpay_order_id}|${razorpay_payment_id}`;
  const expectedSignature = crypto
    .createHmac('sha256', process.env.RAZORPAY_KEY_SECRET)
    .update(body)
    .digest('hex');

  if (expectedSignature !== razorpay_signature) {
    logger.warn(`Payment signature mismatch for order: ${razorpay_order_id}`);
    return res.status(400).json({ success: false, message: 'Payment verification failed' });
  }

  // Update payment record
  const payment = await Payment.findOne({ razorpayOrderId: razorpay_order_id }).populate('member');
  if (!payment) {
    return res.status(404).json({ success: false, message: 'Payment record not found' });
  }

  payment.razorpayPaymentId = razorpay_payment_id;
  payment.razorpaySignature = razorpay_signature;
  payment.status = 'paid';
  payment.paidAt = new Date();

  // Fetch payment details from Razorpay
  try {
    const rpPayment = await razorpay.payments.fetch(razorpay_payment_id);
    payment.paymentMethod = rpPayment.method;
    payment.metadata = rpPayment;
  } catch (err) {
    logger.error('Failed to fetch Razorpay payment details:', err);
  }

  // Create ledger credit entry
  const currentBalance = await LedgerTransaction.getRunningBalance(payment.member._id);
  const ledgerEntry = await LedgerTransaction.create({
    member: payment.member._id,
    type: 'credit',
    category: 'maintenance',
    amount: payment.amount,
    description: `${payment.description} (Razorpay: ${razorpay_payment_id})`,
    date: new Date(),
    month: payment.month,
    year: payment.year,
    balance: currentBalance - payment.amount,
    status: 'paid',
    paidOn: new Date(),
    paymentId: payment._id,
    createdBy: req.user.id,
  });

  payment.ledgerTransaction = ledgerEntry._id;
  await payment.save();

  // Mark any pending maintenance as paid
  await LedgerTransaction.updateMany(
    {
      member: payment.member._id,
      month: payment.month,
      year: payment.year,
      category: 'maintenance',
      status: { $in: ['pending', 'overdue'] },
    },
    { status: 'paid', paidOn: new Date() }
  );

  // Send push notification
  await sendPushNotification({
    userId: req.user.id,
    title: '✅ Payment Successful',
    body: `Payment of ₹${payment.amount.toLocaleString('en-IN')} received. Receipt: ${ledgerEntry.receiptNumber}`,
    data: { type: 'payment_received', paymentId: payment._id.toString() },
  }).catch(() => {});

  res.json({
    success: true,
    message: 'Payment verified successfully',
    payment,
    receipt: { receiptNumber: ledgerEntry.receiptNumber },
  });
});

// ─── @route  POST /api/payments/cash ─────────────────────────────────────────
// ─── @desc   Record offline cash/cheque/NEFT payment (admin only) ─────────────
exports.recordOfflinePayment = asyncHandler(async (req, res) => {
  const { memberId, amount, paymentMethod, description, month, year, referenceNumber } = req.body;

  const member = await Member.findById(memberId);
  if (!member) return res.status(404).json({ success: false, message: 'Member not found' });

  const payment = await Payment.create({
    member: memberId,
    user: req.user.id,
    amount,
    status: 'paid',
    paymentMethod: paymentMethod || 'cash',
    description: description || 'Offline Payment',
    month: month || new Date().getMonth() + 1,
    year: year || new Date().getFullYear(),
    paidAt: new Date(),
  });

  const currentBalance = await LedgerTransaction.getRunningBalance(memberId);
  const ledgerEntry = await LedgerTransaction.create({
    member: memberId,
    type: 'credit',
    category: 'maintenance',
    amount,
    description: `${description} (${paymentMethod?.toUpperCase() || 'CASH'}${referenceNumber ? ` - Ref: ${referenceNumber}` : ''})`,
    date: new Date(),
    month: month || new Date().getMonth() + 1,
    year: year || new Date().getFullYear(),
    balance: currentBalance - amount,
    status: 'paid',
    paidOn: new Date(),
    referenceNumber,
    paymentId: payment._id,
    createdBy: req.user.id,
  });

  payment.ledgerTransaction = ledgerEntry._id;
  await payment.save();

  res.status(201).json({ success: true, payment, receipt: ledgerEntry });
});

// ─── @route  GET /api/payments ────────────────────────────────────────────────
exports.getPayments = asyncHandler(async (req, res) => {
  const { page = 1, limit = 20, status, memberId, month, year } = req.query;
  const filter = {};

  // Members see only their own
  if (req.user.role === 'member') {
    const member = await Member.findOne({ user: req.user.id });
    if (!member) return res.json({ success: true, data: [], pagination: {} });
    filter.member = member._id;
  } else if (memberId) {
    filter.member = memberId;
  }

  if (status) filter.status = status;
  if (month) filter.month = parseInt(month);
  if (year) filter.year = parseInt(year);

  const total = await Payment.countDocuments(filter);
  const payments = await Payment.find(filter)
    .sort({ createdAt: -1 })
    .skip((page - 1) * limit)
    .limit(parseInt(limit))
    .populate({ path: 'member', populate: { path: 'user', select: 'name phone' } });

  res.json({
    success: true,
    data: payments,
    pagination: { total, page: parseInt(page), pages: Math.ceil(total / limit) },
  });
});

// ─── @route  GET /api/payments/stats ─────────────────────────────────────────
exports.getPaymentStats = asyncHandler(async (req, res) => {
  const { year } = req.query;
  const targetYear = parseInt(year) || new Date().getFullYear();

  const stats = await Payment.aggregate([
    { $match: { status: 'paid', year: targetYear } },
    {
      $group: {
        _id: '$month',
        totalCollected: { $sum: '$amount' },
        count: { $sum: 1 },
      },
    },
    { $sort: { _id: 1 } },
  ]);

  const totalCollectedYear = stats.reduce((s, m) => s + m.totalCollected, 0);

  res.json({ success: true, monthlyStats: stats, totalCollectedYear, year: targetYear });
});
