const Member = require('../models/Member');
const User = require('../models/User');
const LedgerTransaction = require('../models/LedgerTransaction');
const { Payment } = require('../models/index');
const { asyncHandler } = require('../middleware/asyncHandler');
const PDFDocument = require('pdfkit');

// ─── @route  GET /api/members ─────────────────────────────────────────────────
exports.getMembers = asyncHandler(async (req, res) => {
  const {
    page = 1, limit = 20,
    wing, status, search, ownershipType, sortBy = 'wing', sortOrder = 'asc',
  } = req.query;

  // Members only see own profile
  if (req.user.role === 'member') {
    const member = await Member.findOne({ user: req.user.id })
      .populate('user', '-password -fcmTokens -refreshToken');
    return res.json({ success: true, data: member });
  }

  const filter = {};
  if (wing) filter.wing = wing.toUpperCase();
  if (status === 'active')   filter.isActive = true;
  if (status === 'inactive') filter.isActive = false;
  if (ownershipType) filter.ownershipType = ownershipType;

  // Text search via User sub-document
  if (search) {
    const matchedUsers = await User.find({
      $or: [
        { name:  { $regex: search, $options: 'i' } },
        { phone: { $regex: search, $options: 'i' } },
        { email: { $regex: search, $options: 'i' } },
      ],
    }).select('_id');
    const userIds = matchedUsers.map(u => u._id);
    filter.$or = [
      { user: { $in: userIds } },
      { flatNumber: { $regex: search, $options: 'i' } },
    ];
  }

  const sortField = sortBy === 'name' ? 'wing' : sortBy;
  const sortDir   = sortOrder === 'desc' ? -1 : 1;

  const total   = await Member.countDocuments(filter);
  const members = await Member.find(filter)
    .populate('user', 'name phone email profilePhoto role lastLogin')
    .sort({ [sortField]: sortDir, flatNumber: 1 })
    .skip((page - 1) * limit)
    .limit(parseInt(limit));

  res.json({
    success: true,
    data: members,
    pagination: {
      total,
      page: parseInt(page),
      pages: Math.ceil(total / limit),
      limit: parseInt(limit),
    },
  });
});

// ─── @route  GET /api/members/:id ────────────────────────────────────────────
exports.getMember = asyncHandler(async (req, res) => {
  const member = await Member.findById(req.params.id)
    .populate('user', '-password -fcmTokens -refreshToken -passwordResetToken');

  if (!member) {
    return res.status(404).json({ success: false, message: 'Member not found' });
  }

  // Members can only see their own profile
  if (req.user.role === 'member') {
    const myMember = await Member.findOne({ user: req.user.id });
    if (!myMember || myMember._id.toString() !== req.params.id) {
      return res.status(403).json({ success: false, message: 'Access denied' });
    }
  }

  // Attach outstanding balance
  const pendingDues  = await LedgerTransaction.getPendingDues(member._id);
  const totalBalance = await LedgerTransaction.getRunningBalance(member._id);

  res.json({
    success: true,
    data: { ...member.toObject(), pendingDues, totalBalance },
  });
});

// ─── @route  POST /api/members ────────────────────────────────────────────────
exports.createMember = asyncHandler(async (req, res) => {
  const {
    userId, flatNumber, wing, flatArea, ownershipType,
    monthlyMaintenance, maintenanceDueDay, lateFeePercentage,
    parking, emergencyContact, numberOfResidents, agreementValue, notes,
  } = req.body;

  // Check user exists
  const user = await User.findById(userId);
  if (!user) {
    return res.status(404).json({ success: false, message: 'User not found' });
  }

  // Check flat not already occupied
  const existing = await Member.findOne({
    flatNumber: flatNumber.toUpperCase(),
    wing: wing.toUpperCase(),
    isActive: true,
  });
  if (existing) {
    return res.status(400).json({ success: false, message: `Flat ${wing.toUpperCase()}-${flatNumber.toUpperCase()} already has an active member` });
  }

  const member = await Member.create({
    user: userId,
    flatNumber: flatNumber.toUpperCase(),
    wing: wing.toUpperCase(),
    flatArea,
    ownershipType,
    monthlyMaintenance,
    maintenanceDueDay: maintenanceDueDay || 10,
    lateFeePercentage: lateFeePercentage || 2,
    parking,
    emergencyContact,
    numberOfResidents,
    agreementValue,
    notes,
  });

  // Link member to user
  await User.findByIdAndUpdate(userId, { member: member._id, role: user.role === 'admin' ? 'admin' : 'member' });

  await member.populate('user', 'name phone email role');
  res.status(201).json({ success: true, data: member });
});

// ─── @route  PUT /api/members/:id ────────────────────────────────────────────
exports.updateMember = asyncHandler(async (req, res) => {
  // Disallow changing flatNumber/wing after creation unless admin
  if ((req.body.flatNumber || req.body.wing) && req.user.role !== 'admin') {
    return res.status(403).json({ success: false, message: 'Only admin can change flat assignment' });
  }

  const member = await Member.findByIdAndUpdate(
    req.params.id,
    req.body,
    { new: true, runValidators: true },
  ).populate('user', 'name phone email');

  if (!member) {
    return res.status(404).json({ success: false, message: 'Member not found' });
  }

  res.json({ success: true, data: member });
});

// ─── @route  DELETE /api/members/:id ─────────────────────────────────────────
exports.deactivateMember = asyncHandler(async (req, res) => {
  const member = await Member.findById(req.params.id);
  if (!member) {
    return res.status(404).json({ success: false, message: 'Member not found' });
  }

  member.isActive = false;
  member.occupancyStatus = 'vacant';
  await member.save();

  // Deactivate associated user
  await User.findByIdAndUpdate(member.user, { isActive: false });

  res.json({ success: true, message: 'Member deactivated successfully' });
});

// ─── @route  GET /api/members/:id/statement ──────────────────────────────────
// ─── @desc   Download PDF statement for a member ─────────────────────────────
exports.downloadStatement = asyncHandler(async (req, res) => {
  const member = await Member.findById(req.params.id)
    .populate('user', 'name phone email');
  if (!member) {
    return res.status(404).json({ success: false, message: 'Member not found' });
  }

  const { fromMonth, fromYear, toMonth, toYear } = req.query;
  const filter = { member: member._id };
  // Date range filter
  if (fromYear) {
    filter.$or = [];
    for (let y = parseInt(fromYear); y <= parseInt(toYear || fromYear); y++) {
      const startM = y === parseInt(fromYear) ? parseInt(fromMonth || 1) : 1;
      const endM   = y === parseInt(toYear || fromYear) ? parseInt(toMonth || 12) : 12;
      for (let m = startM; m <= endM; m++) {
        filter.$or.push({ month: m, year: y });
      }
    }
  }

  const transactions = await LedgerTransaction.find(filter).sort({ date: 1 });
  const pendingDues  = await LedgerTransaction.getPendingDues(member._id);

  const doc = new PDFDocument({ size: 'A4', margin: 50 });
  res.setHeader('Content-Type', 'application/pdf');
  res.setHeader('Content-Disposition', `attachment; filename=statement_${member.flatIdentifier}.pdf`);
  doc.pipe(res);

  // Header
  doc.fontSize(20).font('Helvetica-Bold').text('SOCIETY LEDGER', { align: 'center' });
  doc.fontSize(12).font('Helvetica').text('Member Account Statement', { align: 'center' });
  doc.moveDown(0.5);
  doc.moveTo(50, doc.y).lineTo(545, doc.y).stroke();
  doc.moveDown();

  // Member info
  doc.font('Helvetica-Bold').fontSize(13).text('Member Details');
  doc.moveDown(0.3);
  doc.font('Helvetica').fontSize(11);
  doc.text(`Name: ${member.user?.name || 'N/A'}   |   Flat: ${member.flatIdentifier}   |   Phone: ${member.user?.phone || 'N/A'}`);
  doc.text(`Monthly Maintenance: ₹${member.monthlyMaintenance.toLocaleString('en-IN')}   |   Due Day: ${member.maintenanceDueDay}th`);
  doc.moveDown();

  // Transactions table
  doc.font('Helvetica-Bold').fontSize(11);
  const col = [50, 140, 290, 360, 430, 490];
  doc.text('Date', col[0], doc.y, { continued: true });
  doc.text('Description', col[1], doc.y, { continued: true });
  doc.text('Debit', col[2], doc.y, { continued: true });
  doc.text('Credit', col[3], doc.y, { continued: true });
  doc.text('Balance', col[4], doc.y);
  doc.moveTo(50, doc.y + 2).lineTo(545, doc.y + 2).stroke();
  doc.moveDown(0.5);
  doc.font('Helvetica').fontSize(10);

  for (const txn of transactions) {
    const y = doc.y;
    if (y > 720) { doc.addPage(); }
    const isCredit = txn.type === 'credit';
    const desc = txn.description.length > 35 ? txn.description.substring(0, 32) + '...' : txn.description;
    doc.text(new Date(txn.date).toLocaleDateString('en-IN'), col[0], doc.y);
    doc.text(desc, col[1], doc.y - 10);
    doc.fillColor(isCredit ? 'green' : 'red')
       .text(isCredit ? '' : `₹${txn.amount.toLocaleString('en-IN')}`, col[2], doc.y - 10);
    doc.fillColor(isCredit ? 'green' : 'red')
       .text(isCredit ? `₹${txn.amount.toLocaleString('en-IN')}` : '', col[3], doc.y - 10);
    doc.fillColor('black')
       .text(`₹${Math.abs(txn.balance).toLocaleString('en-IN')}`, col[4], doc.y - 10);
    doc.moveDown(0.3);
  }

  doc.moveDown();
  doc.moveTo(50, doc.y).lineTo(545, doc.y).stroke();
  doc.moveDown(0.5);

  // Summary
  doc.font('Helvetica-Bold').fontSize(12).fillColor('#1E40AF')
     .text(`Pending Dues: ₹${pendingDues.toLocaleString('en-IN')}`, { align: 'right' });
  doc.moveDown(2);
  doc.fontSize(9).fillColor('#666').font('Helvetica')
     .text('This is a computer-generated statement. No signature required.', { align: 'center' });

  doc.end();
});

// ─── @route  GET /api/members/meta/wings ─────────────────────────────────────
exports.getWings = asyncHandler(async (req, res) => {
  const wings = await Member.distinct('wing', { isActive: true });
  const stats = await Member.aggregate([
    { $match: { isActive: true } },
    { $group: { _id: '$wing', count: { $sum: 1 }, totalMaintenance: { $sum: '$monthlyMaintenance' } } },
    { $sort: { _id: 1 } },
  ]);
  res.json({ success: true, data: stats });
});

// ─── @route  GET /api/members/export/csv ─────────────────────────────────────
exports.exportCSV = asyncHandler(async (req, res) => {
  const members = await Member.find({ isActive: true })
    .populate('user', 'name phone email')
    .sort({ wing: 1, flatNumber: 1 });

  const rows = ['Name,Phone,Email,Wing,Flat,Area(sqft),Ownership,Monthly Maintenance,Due Day,Parking'];
  for (const m of members) {
    rows.push([
      m.user?.name || '',
      m.user?.phone || '',
      m.user?.email || '',
      m.wing,
      m.flatNumber,
      m.flatArea,
      m.ownershipType,
      m.monthlyMaintenance,
      m.maintenanceDueDay,
      m.parking?.hasParking ? 'Yes' : 'No',
    ].join(','));
  }

  res.setHeader('Content-Type', 'text/csv');
  res.setHeader('Content-Disposition', 'attachment; filename=members_export.csv');
  res.send(rows.join('\n'));
});
