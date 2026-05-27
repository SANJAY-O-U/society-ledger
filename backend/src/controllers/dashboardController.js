const Member = require('../models/Member');
const LedgerTransaction = require('../models/LedgerTransaction');
const { Payment, Expense, Complaint, Event, Inventory } = require('../models/index');
const { asyncHandler } = require('../middleware/asyncHandler');

// ─── @route  GET /api/dashboard/admin ────────────────────────────────────────
exports.getAdminDashboard = asyncHandler(async (req, res) => {
  const currentMonth = new Date().getMonth() + 1;
  const currentYear = new Date().getFullYear();

  const [
    totalMembers,
    activeMembers,
    monthlyCollection,
    totalPendingDues,
    monthlyExpenses,
    openComplaints,
    inProgressComplaints,
    upcomingEvents,
    inventoryStats,
    recentPayments,
    collectionTrend,
    expenseByCategory,
  ] = await Promise.all([
    Member.countDocuments(),
    Member.countDocuments({ isActive: true }),

    // Monthly collection
    Payment.aggregate([
      { $match: { status: 'paid', month: currentMonth, year: currentYear } },
      { $group: { _id: null, total: { $sum: '$amount' } } },
    ]),

    // Total pending dues
    LedgerTransaction.aggregate([
      { $match: { type: 'debit', status: { $in: ['pending', 'overdue'] } } },
      { $group: { _id: null, total: { $sum: '$amount' } } },
    ]),

    // Monthly expenses
    Expense.aggregate([
      { $match: { month: currentMonth, year: currentYear, status: { $ne: 'rejected' } } },
      { $group: { _id: null, total: { $sum: '$amount' } } },
    ]),

    Complaint.countDocuments({ status: 'open' }),
    Complaint.countDocuments({ status: 'in_progress' }),

    // Upcoming events (next 30 days)
    Event.find({
      startDate: { $gte: new Date(), $lte: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000) },
      isPublished: true,
    }).sort({ startDate: 1 }).limit(5).select('title startDate endDate venue category description'),

    // Inventory low stock
    Inventory.aggregate([
      { $group: { _id: '$status', count: { $sum: 1 } } },
    ]),

    // Recent payments
    Payment.find({ status: 'paid' })
      .sort({ paidAt: -1 })
      .limit(5)
      .populate({ path: 'member', populate: { path: 'user', select: 'name' } })
      .select('amount paidAt description'),

    // 6-month collection trend
    Payment.aggregate([
      {
        $match: {
          status: 'paid',
          paidAt: { $gte: new Date(Date.now() - 6 * 30 * 24 * 60 * 60 * 1000) },
        },
      },
      {
        $group: {
          _id: { month: '$month', year: '$year' },
          total: { $sum: '$amount' },
          count: { $sum: 1 },
        },
      },
      { $sort: { '_id.year': 1, '_id.month': 1 } },
    ]),

    // Expense by category (current month)
    Expense.aggregate([
      { $match: { month: currentMonth, year: currentYear, status: { $ne: 'rejected' } } },
      { $group: { _id: '$category', total: { $sum: '$amount' } } },
      { $sort: { total: -1 } },
    ]),
  ]);

  // Format inventory stats
  const inventoryStatusMap = {};
  inventoryStats.forEach(({ _id, count }) => { inventoryStatusMap[_id] = count; });

  res.json({
    success: true,
    data: {
      members: { total: totalMembers, active: activeMembers, inactive: totalMembers - activeMembers },
      finance: {
        monthlyCollection: monthlyCollection[0]?.total || 0,
        totalPendingDues: totalPendingDues[0]?.total || 0,
        monthlyExpenses: monthlyExpenses[0]?.total || 0,
        netBalance: (monthlyCollection[0]?.total || 0) - (monthlyExpenses[0]?.total || 0),
      },
      complaints: { open: openComplaints, inProgress: inProgressComplaints },
      upcomingEvents,
      inventory: inventoryStatusMap,
      recentPayments,
      charts: {
        collectionTrend,
        expenseByCategory,
      },
    },
  });
});

// ─── @route  GET /api/dashboard/member ───────────────────────────────────────
exports.getMemberDashboard = asyncHandler(async (req, res) => {
  const member = await Member.findOne({ user: req.user.id });
  if (!member) {
    return res.status(404).json({ success: false, message: 'Member profile not found' });
  }

  const currentMonth = new Date().getMonth() + 1;
  const currentYear = new Date().getFullYear();

  const [
    currentBalance,
    pendingDues,
    myComplaints,
    recentTransactions,
    upcomingEvents,
    lastPayment,
  ] = await Promise.all([
    LedgerTransaction.getRunningBalance(member._id),
    LedgerTransaction.getPendingDues(member._id),
    Complaint.find({ member: member._id, status: { $nin: ['closed', 'resolved'] } }).select('title status priority createdAt'),
    LedgerTransaction.find({ member: member._id }).sort({ date: -1 }).limit(5),
    Event.find({ startDate: { $gte: new Date() }, isPublished: true }).sort({ startDate: 1 }).limit(3),
    Payment.findOne({ member: member._id, status: 'paid' }).sort({ paidAt: -1 }).select('amount paidAt description'),
  ]);

  res.json({
    success: true,
    data: {
      member: {
        flatNumber: member.flatNumber,
        wing: member.wing,
        monthlyMaintenance: member.monthlyMaintenance,
        dueDay: member.maintenanceDueDay,
      },
      finance: {
        currentBalance,
        pendingDues,
        lastPayment,
      },
      myComplaints,
      recentTransactions,
      upcomingEvents,
    },
  });
});