const mongoose = require('mongoose');

const memberSchema = new mongoose.Schema({
  user: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
  },
  flatNumber: {
    type: String,
    required: [true, 'Flat number is required'],
    trim: true,
    uppercase: true,
  },
  wing: {
    type: String,
    required: [true, 'Wing is required'],
    trim: true,
    uppercase: true,
  },
  flatArea: {
    type: Number,
    required: [true, 'Flat area is required'],
    min: [0, 'Flat area cannot be negative'],
  },
  ownershipType: {
    type: String,
    enum: ['owner', 'tenant', 'caretaker'],
    default: 'owner',
  },
  registrationDate: {
    type: Date,
    default: Date.now,
  },
  agreementValue: {
    type: Number,
    default: 0,
  },
  parking: {
    hasParking: { type: Boolean, default: false },
    parkingNumber: { type: String, default: null },
    vehicleType: { type: String, enum: ['two-wheeler', 'four-wheeler', 'both', 'none'], default: 'none' },
    vehicleNumber: { type: String, default: null },
  },
  monthlyMaintenance: {
    type: Number,
    required: [true, 'Monthly maintenance amount is required'],
    default: 0,
  },
  maintenanceDueDay: {
    type: Number,
    default: 10, // 10th of every month
    min: 1,
    max: 28,
  },
  lateFeePercentage: {
    type: Number,
    default: 2, // 2% per month
  },
  documents: [{
    name: String,
    type: { type: String, enum: ['id_proof', 'address_proof', 'agreement', 'noc', 'other'] },
    url: String,
    uploadedAt: { type: Date, default: Date.now },
  }],
  emergencyContact: {
    name: String,
    phone: String,
    relation: String,
  },
  isActive: {
    type: Boolean,
    default: true,
  },
  occupancyStatus: {
    type: String,
    enum: ['occupied', 'vacant', 'under-renovation'],
    default: 'occupied',
  },
  numberOfResidents: {
    type: Number,
    default: 1,
  },
  notes: {
    type: String,
    maxlength: 500,
  },
}, {
  timestamps: true,
  toJSON: { virtuals: true },
  toObject: { virtuals: true },
});

// ─── Indexes ─────────────────────────────────────────────────────────────────
memberSchema.index({ flatNumber: 1, wing: 1 }, { unique: true });
memberSchema.index({ user: 1 });
memberSchema.index({ isActive: 1 });

// ─── Virtuals ─────────────────────────────────────────────────────────────────
memberSchema.virtual('flatIdentifier').get(function () {
  return `${this.wing}-${this.flatNumber}`;
});

// ─── Static Methods ────────────────────────────────────────────────────────────
memberSchema.statics.getActiveCount = function () {
  return this.countDocuments({ isActive: true });
};

module.exports = mongoose.model('Member', memberSchema);
