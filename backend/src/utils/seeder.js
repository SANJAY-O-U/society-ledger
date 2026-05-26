/**
 * Society Ledger — Database Seeder
 * Run: npm run seed
 * Seeds admin user, sample members, and initial data
 */

require('dotenv').config();
const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const User = require('../models/User');
const Member = require('../models/Member');
const LedgerTransaction = require('../models/LedgerTransaction');
const { Expense, Event, Inventory } = require('../models/index');

const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://localhost:27017/society_ledger';

// ─── Sample Data ───────────────────────────────────────────────────────────────
const usersData = [
  { name: 'Rajesh Sharma', phone: '9999999999', email: 'admin@society.com', role: 'admin',    password: 'Admin@123' },
  { name: 'Priya Mehta',   phone: '9888888888', email: 'secretary@society.com', role: 'secretary', password: 'Secretary@123' },
  { name: 'Amit Joshi',    phone: '9777777777', email: 'treasurer@society.com', role: 'treasurer', password: 'Treasurer@123' },
  { name: 'Sunita Patel',  phone: '9666666666', email: 'member1@society.com',  role: 'member',    password: 'Member@123' },
  { name: 'Vikram Singh',  phone: '9555555555', email: 'member2@society.com',  role: 'member',    password: 'Member@123' },
  { name: 'Anita Desai',   phone: '9444444444', email: 'member3@society.com',  role: 'member',    password: 'Member@123' },
  { name: 'Deepak Gupta',  phone: '9333333333', email: 'member4@society.com',  role: 'member',    password: 'Member@123' },
  { name: 'Kavita Reddy',  phone: '9222222222', email: 'member5@society.com',  role: 'member',    password: 'Member@123' },
];

const membersData = [
  { wingFlat: ['A', '101'], area: 950,  maintenance: 3500, ownership: 'owner',  parking: true },
  { wingFlat: ['A', '102'], area: 950,  maintenance: 3500, ownership: 'tenant', parking: false },
  { wingFlat: ['A', '201'], area: 1200, maintenance: 4200, ownership: 'owner',  parking: true },
  { wingFlat: ['B', '101'], area: 850,  maintenance: 3000, ownership: 'owner',  parking: false },
  { wingFlat: ['B', '102'], area: 1050, maintenance: 3800, ownership: 'tenant', parking: true },
];

const expensesData = [
  { category: 'electricity_bill', title: 'Common Area Electricity - November', amount: 12500 },
  { category: 'security_salary',  title: 'Security Guard Salary - November',   amount: 18000 },
  { category: 'cleaning',         title: 'Housekeeping Staff - November',       amount: 15000 },
  { category: 'water_bill',       title: 'Water Board Bill - November',         amount: 8500 },
  { category: 'lift_maintenance', title: 'Lift AMC - Quarterly',                amount: 22000 },
  { category: 'garden',           title: 'Garden Maintenance - November',       amount: 4500 },
  { category: 'repairs',          title: 'Pump Room Repair',                    amount: 7800 },
];

const eventsData = [
  {
    title: 'Annual General Meeting (AGM)',
    description: 'Annual General Meeting to discuss society accounts, maintenance, and upcoming projects.',
    category: 'meeting',
    venue: 'Society Clubhouse',
    daysFromNow: 7,
  },
  {
    title: 'Diwali Celebration 2025',
    description: 'Join us for a wonderful Diwali celebration with rangoli, diyas, and sweets!',
    category: 'festival',
    venue: 'Society Garden',
    daysFromNow: 14,
  },
  {
    title: 'Cricket Tournament',
    description: 'Inter-wing cricket tournament. Teams of 6. Register by 5th.',
    category: 'sports',
    venue: 'Society Ground',
    daysFromNow: 21,
  },
];

const inventoryData = [
  { itemName: 'Folding Chairs', category: 'furniture', quantity: 50, location: 'Store Room A', purchasePrice: 25000 },
  { itemName: 'Tables (Round)', category: 'furniture', quantity: 10, location: 'Store Room A', purchasePrice: 15000 },
  { itemName: 'PA System',      category: 'electronics', quantity: 1, location: 'Clubhouse',    purchasePrice: 18000 },
  { itemName: 'Generator',      category: 'electronics', quantity: 1, location: 'Pump Room',    purchasePrice: 85000 },
  { itemName: 'Cricket Kit',    category: 'sports',      quantity: 2, location: 'Store Room B', purchasePrice: 12000 },
  { itemName: 'Badminton Rackets', category: 'sports',   quantity: 8, location: 'Store Room B', purchasePrice: 8000 },
  { itemName: 'Fire Extinguisher', category: 'safety',   quantity: 12, location: 'Various',    purchasePrice: 18000 },
  { itemName: 'Pressure Washer',   category: 'tools',    quantity: 1, location: 'Pump Room',   purchasePrice: 14000 },
];

// ─── Seeder ────────────────────────────────────────────────────────────────────
async function seed() {
  try {
    await mongoose.connect(MONGODB_URI);
    console.log('✅ MongoDB connected');

    // Clear existing data
    console.log('🗑️  Clearing existing data...');
    await Promise.all([
      User.deleteMany({}),
      Member.deleteMany({}),
      LedgerTransaction.deleteMany({}),
      Expense.deleteMany({}),
      Event.deleteMany({}),
      Inventory.deleteMany({}),
    ]);

    // ─── Create Users ──────────────────────────────────────────────────
    console.log('👤 Creating users...');
    const createdUsers = [];
    for (const userData of usersData) {
      const user = await User.create({
        ...userData,
        isPhoneVerified: true,
        isEmailVerified: true,
      });
      createdUsers.push(user);
    }
    console.log(`   ✓ ${createdUsers.length} users created`);

    // ─── Create Members (link to member users) ─────────────────────────
    console.log('🏠 Creating members...');
    // member users start at index 3 (after admin, secretary, treasurer)
    const memberUsers = createdUsers.slice(3);
    const createdMembers = [];

    for (let i = 0; i < membersData.length; i++) {
      const mData = membersData[i];
      const user = memberUsers[i];
      if (!user) break;

      const member = await Member.create({
        user: user._id,
        flatNumber: mData.wingFlat[1],
        wing: mData.wingFlat[0],
        flatArea: mData.area,
        ownershipType: mData.ownership,
        monthlyMaintenance: mData.maintenance,
        maintenanceDueDay: 10,
        lateFeePercentage: 2,
        parking: {
          hasParking: mData.parking,
          parkingNumber: mData.parking ? `P-${i + 1}` : null,
          vehicleType: mData.parking ? 'four-wheeler' : 'none',
        },
        isActive: true,
        occupancyStatus: 'occupied',
      });

      // Link member back to user
      await User.findByIdAndUpdate(user._id, { member: member._id });
      createdMembers.push(member);
    }
    console.log(`   ✓ ${createdMembers.length} members created`);

    // ─── Create Ledger Transactions (last 3 months) ────────────────────
    console.log('📒 Creating ledger transactions...');
    const adminUser = createdUsers[0];
    let txnCount = 0;

    for (const member of createdMembers) {
      let runningBalance = 0;

      for (let monthOffset = 2; monthOffset >= 0; monthOffset--) {
        const d = new Date();
        d.setMonth(d.getMonth() - monthOffset);
        const month = d.getMonth() + 1;
        const year = d.getFullYear();
        const dueDate = new Date(year, month - 1, member.maintenanceDueDay);

        // Debit: maintenance charge
        runningBalance += member.monthlyMaintenance;
        const debitTxn = await LedgerTransaction.create({
          member: member._id,
          type: 'debit',
          category: 'maintenance',
          amount: member.monthlyMaintenance,
          description: `Monthly Maintenance - ${d.toLocaleString('default', { month: 'long', year: 'numeric' })}`,
          date: new Date(year, month - 1, 1),
          month,
          year,
          balance: runningBalance,
          dueDate,
          status: monthOffset > 0 ? 'paid' : 'pending',
          isAutoGenerated: true,
          createdBy: adminUser._id,
        });

        // Credit: payment (for past months only)
        if (monthOffset > 0) {
          const payDate = new Date(year, month - 1, Math.floor(Math.random() * 5) + 8);
          runningBalance -= member.monthlyMaintenance;
          await LedgerTransaction.create({
            member: member._id,
            type: 'credit',
            category: 'maintenance',
            amount: member.monthlyMaintenance,
            description: `Payment Received - ${d.toLocaleString('default', { month: 'long', year: 'numeric' })}`,
            date: payDate,
            month,
            year,
            balance: runningBalance,
            status: 'paid',
            paidOn: payDate,
            createdBy: adminUser._id,
          });
        }
        txnCount += 2;
      }
    }
    console.log(`   ✓ ${txnCount} ledger transactions created`);

    // ─── Create Expenses ───────────────────────────────────────────────
    console.log('💸 Creating expenses...');
    const now = new Date();
    for (const eData of expensesData) {
      await Expense.create({
        ...eData,
        date: new Date(now.getFullYear(), now.getMonth(), Math.floor(Math.random() * 20) + 1),
        month: now.getMonth() + 1,
        year: now.getFullYear(),
        status: 'approved',
        approvedBy: adminUser._id,
        approvedAt: new Date(),
        createdBy: createdUsers[2]._id, // treasurer
      });
    }
    console.log(`   ✓ ${expensesData.length} expenses created`);

    // ─── Create Events ─────────────────────────────────────────────────
    console.log('📅 Creating events...');
    for (const eData of eventsData) {
      const startDate = new Date(Date.now() + eData.daysFromNow * 24 * 60 * 60 * 1000);
      startDate.setHours(10, 0, 0, 0);
      const endDate = new Date(startDate);
      endDate.setHours(13, 0, 0, 0);

      await Event.create({
        title: eData.title,
        description: eData.description,
        category: eData.category,
        startDate,
        endDate,
        venue: eData.venue,
        organizer: adminUser._id,
        isPublished: true,
      });
    }
    console.log(`   ✓ ${eventsData.length} events created`);

    // ─── Create Inventory ──────────────────────────────────────────────
    console.log('📦 Creating inventory...');
    for (const iData of inventoryData) {
      await Inventory.create({
        ...iData,
        availableQuantity: iData.quantity,
        purchaseDate: new Date(Date.now() - Math.random() * 365 * 24 * 60 * 60 * 1000),
        condition: 'good',
        status: 'available',
        createdBy: adminUser._id,
      });
    }
    console.log(`   ✓ ${inventoryData.length} inventory items created`);

    // ─── Summary ───────────────────────────────────────────────────────
    console.log('\n🎉 Seeding complete!\n');
    console.log('═══════════════════════════════════════');
    console.log('  Test Login Credentials');
    console.log('═══════════════════════════════════════');
    console.log('  Admin:');
    console.log('    Phone: 9999999999 | Email: admin@society.com');
    console.log('    Password: Admin@123');
    console.log('');
    console.log('  Secretary:');
    console.log('    Phone: 9888888888 | Password: Secretary@123');
    console.log('');
    console.log('  Treasurer:');
    console.log('    Phone: 9777777777 | Password: Treasurer@123');
    console.log('');
    console.log('  Member (Flat A-101):');
    console.log('    Phone: 9666666666 | Password: Member@123');
    console.log('═══════════════════════════════════════\n');

    process.exit(0);
  } catch (err) {
    console.error('❌ Seeding failed:', err);
    process.exit(1);
  }
}

seed();
