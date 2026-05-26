const express = require('express');
const router = express.Router();
const { protect, managementAccess, financeAccess, authorize } = require('../middleware/auth');
const { asyncHandler } = require('../middleware/asyncHandler');
const { Expense } = require('../models/index');
const upload = require('../utils/fileUpload');

router.use(protect);

// GET all expenses
router.get('/', asyncHandler(async (req, res) => {
  const { page = 1, limit = 20, category, status, month, year } = req.query;
  const filter = {};
  if (category) filter.category = category;
  if (status) filter.status = status;
  if (month) filter.month = parseInt(month);
  if (year) filter.year = parseInt(year);

  const total = await Expense.countDocuments(filter);
  const expenses = await Expense.find(filter)
    .sort({ date: -1 })
    .skip((page - 1) * limit)
    .limit(parseInt(limit))
    .populate('createdBy', 'name role')
    .populate('approvedBy', 'name role');

  const summary = await Expense.aggregate([
    { $match: filter },
    { $group: { _id: null, total: { $sum: '$amount' } } },
  ]);

  res.json({
    success: true,
    data: expenses,
    total: summary[0]?.total || 0,
    pagination: { total, page: parseInt(page), pages: Math.ceil(total / limit) },
  });
}));

// GET expense stats by category
router.get('/stats', financeAccess, asyncHandler(async (req, res) => {
  const { year } = req.query;
  const targetYear = parseInt(year) || new Date().getFullYear();

  const stats = await Expense.aggregate([
    { $match: { year: targetYear, status: { $ne: 'rejected' } } },
    {
      $group: {
        _id: { month: '$month', category: '$category' },
        total: { $sum: '$amount' },
      },
    },
    { $sort: { '_id.month': 1 } },
  ]);

  res.json({ success: true, data: stats });
}));

// POST create expense
router.post('/', managementAccess, upload.single('invoice'), asyncHandler(async (req, res) => {
  const { category, title, description, amount, date, vendor, paymentMode, notes } = req.body;
  const d = date ? new Date(date) : new Date();

  const expense = await Expense.create({
    category,
    title,
    description,
    amount: parseFloat(amount),
    date: d,
    month: d.getMonth() + 1,
    year: d.getFullYear(),
    vendor: vendor ? JSON.parse(vendor) : undefined,
    paymentMode,
    notes,
    invoiceUrl: req.file ? `/uploads/${req.file.filename}` : undefined,
    createdBy: req.user.id,
    status: ['admin', 'chairman'].includes(req.user.role) ? 'approved' : 'pending_approval',
  });

  res.status(201).json({ success: true, data: expense });
}));

// PUT update expense
router.put('/:id', managementAccess, asyncHandler(async (req, res) => {
  const expense = await Expense.findById(req.params.id);
  if (!expense) return res.status(404).json({ success: false, message: 'Expense not found' });
  if (expense.status === 'paid') {
    return res.status(400).json({ success: false, message: 'Cannot edit a paid expense' });
  }
  Object.assign(expense, req.body);
  await expense.save();
  res.json({ success: true, data: expense });
}));

// PUT approve/reject
router.put('/:id/approve', financeAccess, asyncHandler(async (req, res) => {
  const { action, reason } = req.body; // action: 'approve' | 'reject'
  const expense = await Expense.findById(req.params.id);
  if (!expense) return res.status(404).json({ success: false, message: 'Expense not found' });

  if (action === 'approve') {
    expense.status = 'approved';
    expense.approvedBy = req.user.id;
    expense.approvedAt = new Date();
  } else {
    expense.status = 'rejected';
    expense.rejectionReason = reason;
  }
  await expense.save();
  res.json({ success: true, data: expense });
}));

// DELETE expense
router.delete('/:id', authorize('admin', 'chairman'), asyncHandler(async (req, res) => {
  await Expense.findByIdAndDelete(req.params.id);
  res.json({ success: true, message: 'Expense deleted' });
}));

module.exports = router;
