// ============================================================
// models/Visitor.js  — Visitor Management (Optional feature)
// ============================================================
const mongoose = require('mongoose');

const visitorSchema = new mongoose.Schema({
  name: { type: String, required: true, trim: true },
  phone: { type: String, trim: true },
  purpose: { type: String, enum: ['guest', 'delivery', 'service', 'cab', 'other'], default: 'guest' },
  host: { type: mongoose.Schema.Types.ObjectId, ref: 'Member', required: true },
  hostUser: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  vehicleNumber: String,
  photo: String,
  idType: { type: String, enum: ['aadhaar', 'pan', 'passport', 'driving_license', 'other'] },
  idNumber: String,
  qrCode: String,                          // base64 QR for pre-approval
  preApproved: { type: Boolean, default: false },
  preApprovedToken: String,
  preApprovedExpiry: Date,
  checkIn: { type: Date, default: Date.now },
  checkOut: Date,
  isActive: { type: Boolean, default: true },
  securityNotes: String,
  loggedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
}, { timestamps: true });

visitorSchema.index({ host: 1, checkIn: -1 });
visitorSchema.index({ preApprovedToken: 1 });

module.exports = mongoose.model('Visitor', visitorSchema);
