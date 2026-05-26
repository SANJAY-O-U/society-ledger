const PDFDocument = require('pdfkit');
const Member = require('../models/Member');
const LedgerTransaction = require('../models/LedgerTransaction');
const { asyncHandler } = require('../middleware/asyncHandler');

// ─── @route  GET /api/ledger/:memberId ───────────────────────────────────────
exports.getMemberLedger = asyncHandler(async (req, res) => {
  const { memberId } = req.params;
  const { page = 1, limit = 20, month, year, category, status } = req.query;

  // Permission: members can only see their own ledger
  if (req.user.role === 'member') {
    const member = await Member.findOne({ user: req.user.id });
    if (!member || member._id.toString() !== memberId) {
      return res.status(403).json({ success: false, message: 'Access denied' });
    }
  }

  const filter = { member: memberId };
  if (month) filter.month = parseInt(month);
  if (year) filter.year = parseInt(year);
  if (category) filter.category = category;
  if (status) filter.status = status;

  const total = await LedgerTransaction.countDocuments(filter);
  const transactions = await LedgerTransaction.find(filter)
    .sort({ date: -1 })
    .skip((page - 1) * limit)
    .limit(parseInt(limit))
    .populate('createdBy', 'name role')
    .populate('paymentId', 'razorpayPaymentId paymentMethod');

  // Summary stats
  const summary = await LedgerTransaction.aggregate([
    { $match: { member: require('mongoose').Types.ObjectId(memberId) } },
    {
      $group: {
        _id: null,
        totalDebit: { $sum: { $cond: [{ $eq: ['$type', 'debit'] }, '$amount', 0] } },
        totalCredit: { $sum: { $cond: [{ $eq: ['$type', 'credit'] }, '$amount', 0] } },
        pendingAmount: {
          $sum: {
            $cond: [{ $and: [{ $eq: ['$type', 'debit'] }, { $in: ['$status', ['pending', 'overdue']] }] }, '$amount', 0],
          },
        },
      },
    },
  ]);

  const stats = summary[0] || { totalDebit: 0, totalCredit: 0, pendingAmount: 0 };
  const currentBalance = stats.totalDebit - stats.totalCredit;

  res.json({
    success: true,
    data: transactions,
    pagination: { total, page: parseInt(page), pages: Math.ceil(total / limit), limit: parseInt(limit) },
    summary: { ...stats, currentBalance },
  });
});

// ─── @route  GET /api/ledger/all-pending ─────────────────────────────────────
exports.getAllPendingDues = asyncHandler(async (req, res) => {
  const { wing, minAmount } = req.query;

  const pendingDues = await LedgerTransaction.aggregate([
    { $match: { type: 'debit', status: { $in: ['pending', 'overdue'] } } },
    {
      $group: {
        _id: '$member',
        totalPending: { $sum: '$amount' },
        transactions: { $push: { id: '$_id', amount: '$amount', dueDate: '$dueDate', description: '$description', status: '$status' } },
      },
    },
    { $match: minAmount ? { totalPending: { $gte: parseFloat(minAmount) } } : {} },
    {
      $lookup: {
        from: 'members',
        localField: '_id',
        foreignField: '_id',
        as: 'memberInfo',
      },
    },
    { $unwind: '$memberInfo' },
    ...(wing ? [{ $match: { 'memberInfo.wing': wing.toUpperCase() } }] : []),
    {
      $lookup: {
        from: 'users',
        localField: 'memberInfo.user',
        foreignField: '_id',
        as: 'userInfo',
      },
    },
    { $unwind: '$userInfo' },
    {
      $project: {
        memberId: '$_id',
        totalPending: 1,
        wing: '$memberInfo.wing',
        flatNumber: '$memberInfo.flatNumber',
        name: '$userInfo.name',
        phone: '$userInfo.phone',
        email: '$userInfo.email',
      },
    },
    { $sort: { totalPending: -1 } },
  ]);

  const grandTotal = pendingDues.reduce((sum, d) => sum + d.totalPending, 0);

  res.json({ success: true, data: pendingDues, total: pendingDues.length, grandTotal });
});

// ─── @route  POST /api/ledger/add-transaction ────────────────────────────────
exports.addTransaction = asyncHandler(async (req, res) => {
  const { memberId, type, category, amount, description, date, month, year, dueDate, notes } = req.body;

  const member = await Member.findById(memberId);
  if (!member) return res.status(404).json({ success: false, message: 'Member not found' });

  // Get current balance
  const currentBalance = await LedgerTransaction.getRunningBalance(memberId);
  const newBalance = type === 'debit' ? currentBalance + amount : currentBalance - amount;

  const transaction = await LedgerTransaction.create({
    member: memberId,
    type,
    category,
    amount,
    description,
    date: date || new Date(),
    month: month || new Date().getMonth() + 1,
    year: year || new Date().getFullYear(),
    balance: newBalance,
    dueDate,
    notes,
    createdBy: req.user.id,
  });

  res.status(201).json({ success: true, data: transaction });
});

// ─── @route  POST /api/ledger/generate-maintenance ───────────────────────────
// ─── @desc   Manually generate monthly maintenance for all active members ─────
exports.generateMonthlyMaintenance = asyncHandler(async (req, res) => {
  const { month, year } = req.body;
  const targetMonth = month || new Date().getMonth() + 1;
  const targetYear = year || new Date().getFullYear();

  const activeMembers = await Member.find({ isActive: true }).populate('user', 'name');

  let created = 0;
  let skipped = 0;
  const results = [];

  for (const member of activeMembers) {
    // Check if already generated
    const existing = await LedgerTransaction.findOne({
      member: member._id,
      month: targetMonth,
      year: targetYear,
      category: 'maintenance',
      isAutoGenerated: true,
    });

    if (existing) {
      skipped++;
      continue;
    }

    const currentBalance = await LedgerTransaction.getRunningBalance(member._id);
    const dueDate = new Date(targetYear, targetMonth - 1, member.maintenanceDueDay);

    const transaction = await LedgerTransaction.create({
      member: member._id,
      type: 'debit',
      category: 'maintenance',
      amount: member.monthlyMaintenance,
      description: `Monthly Maintenance - ${new Date(targetYear, targetMonth - 1).toLocaleString('default', { month: 'long', year: 'numeric' })}`,
      date: new Date(targetYear, targetMonth - 1, 1),
      month: targetMonth,
      year: targetYear,
      balance: currentBalance + member.monthlyMaintenance,
      dueDate,
      status: 'pending',
      isAutoGenerated: true,
      createdBy: req.user.id,
    });

    results.push({ memberId: member._id, name: member.user?.name, amount: member.monthlyMaintenance });
    created++;
  }

  res.json({
    success: true,
    message: `Maintenance generated for ${targetMonth}/${targetYear}`,
    created,
    skipped,
    results,
  });
});

// ─── @route  POST /api/ledger/apply-late-fee ─────────────────────────────────
exports.applyLateFees = asyncHandler(async (req, res) => {
  const { month, year } = req.body;

  const overdueTransactions = await LedgerTransaction.find({
    month: month || new Date().getMonth() + 1,
    year: year || new Date().getFullYear(),
    category: 'maintenance',
    status: { $in: ['pending', 'overdue'] },
    dueDate: { $lt: new Date() },
    lateFeeApplied: false,
  }).populate('member');

  let applied = 0;

  for (const txn of overdueTransactions) {
    const lateFeeAmount = (txn.amount * txn.member.lateFeePercentage) / 100;
    const currentBalance = await LedgerTransaction.getRunningBalance(txn.member._id);

    await LedgerTransaction.create({
      member: txn.member._id,
      type: 'debit',
      category: 'late_fee',
      amount: lateFeeAmount,
      description: `Late fee (${txn.member.lateFeePercentage}%) for ${txn.description}`,
      date: new Date(),
      month: new Date().getMonth() + 1,
      year: new Date().getFullYear(),
      balance: currentBalance + lateFeeAmount,
      status: 'pending',
      createdBy: req.user.id,
    });

    txn.lateFeeApplied = true;
    txn.status = 'overdue';
    await txn.save();
    applied++;
  }

  res.json({ success: true, message: `Late fees applied to ${applied} transactions`, applied });
});

// ─── @route  GET /api/ledger/receipt/:transactionId ──────────────────────────
exports.downloadReceipt = asyncHandler(async (req, res) => {
  const txn = await LedgerTransaction.findById(req.params.transactionId)
    .populate({ path: 'member', populate: { path: 'user', select: 'name phone email' } });

  if (!txn) return res.status(404).json({ success: false, message: 'Transaction not found' });
  if (txn.type !== 'credit') {
    return res.status(400).json({ success: false, message: 'Receipt only available for credit transactions' });
  }

  const doc = new PDFDocument({ size: 'A4', margin: 50 });
  res.setHeader('Content-Type', 'application/pdf');
  res.setHeader('Content-Disposition', `attachment; filename=receipt_${txn.receiptNumber}.pdf`);
  doc.pipe(res);

  // PDF Header
  doc.fontSize(24).font('Helvetica-Bold').text('SOCIETY LEDGER', { align: 'center' });
  doc.fontSize(14).font('Helvetica').text('Payment Receipt', { align: 'center' });
  doc.moveDown();
  doc.moveTo(50, doc.y).lineTo(545, doc.y).stroke();
  doc.moveDown();

  // Receipt details
  doc.fontSize(12).font('Helvetica-Bold').text('Receipt Details', { underline: true });
  doc.moveDown(0.5);
  doc.font('Helvetica');
  doc.text(`Receipt No: ${txn.receiptNumber}`);
  doc.text(`Date: ${new Date(txn.date).toLocaleDateString('en-IN', { dateStyle: 'long' })}`);
  doc.moveDown();
  doc.font('Helvetica-Bold').text('Member Details', { underline: true });
  doc.moveDown(0.5);
  doc.font('Helvetica');
  doc.text(`Name: ${txn.member?.user?.name || 'N/A'}`);
  doc.text(`Flat: ${txn.member?.wing}-${txn.member?.flatNumber}`);
  doc.text(`Phone: ${txn.member?.user?.phone}`);
  doc.moveDown();
  doc.font('Helvetica-Bold').text('Payment Details', { underline: true });
  doc.moveDown(0.5);
  doc.font('Helvetica');
  doc.text(`Description: ${txn.description}`);
  doc.text(`Amount Paid: ₹${txn.amount.toLocaleString('en-IN')}`);
  doc.moveDown(2);
  doc.font('Helvetica-Bold').fontSize(16).fillColor('#2563EB').text(`Total: ₹${txn.amount.toLocaleString('en-IN')}`, { align: 'right' });
  doc.fillColor('#000');
  doc.moveDown(2);
  doc.fontSize(10).font('Helvetica').text('This is a computer-generated receipt. No signature required.', { align: 'center' });

  doc.end();
});

// ─── @route  GET /api/ledger/summary ─────────────────────────────────────────
exports.getLedgerSummary = asyncHandler(async (req, res) => {
  const { year } = req.query;
  const targetYear = parseInt(year) || new Date().getFullYear();

  const monthlyData = await LedgerTransaction.aggregate([
    { $match: { year: targetYear } },
    {
      $group: {
        _id: { month: '$month', type: '$type' },
        total: { $sum: '$amount' },
      },
    },
    { $sort: { '_id.month': 1 } },
  ]);

  // Format by month
  const months = Array.from({ length: 12 }, (_, i) => ({
    month: i + 1,
    debit: 0,
    credit: 0,
  }));

  monthlyData.forEach(({ _id, total }) => {
    const m = months.find((m) => m.month === _id.month);
    if (m) m[_id.type] = total;
  });

  res.json({ success: true, data: months, year: targetYear });
});
