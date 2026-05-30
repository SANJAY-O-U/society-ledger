const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');
const path = require('path');
require('dotenv').config();

const logger = require('./utils/logger');
const { errorHandler } = require('./middleware/errorHandler');
const { startCronJobs } = require('./services/cronService');

// Route imports
const authRoutes = require('./routes/auth');
const memberRoutes = require('./routes/members');
const ledgerRoutes = require('./routes/ledger');
const paymentRoutes = require('./routes/payments');
const expenseRoutes = require('./routes/expenses');
const complaintRoutes = require('./routes/complaints');
const eventRoutes = require('./routes/events');
const inventoryRoutes = require('./routes/inventory');
const documentRoutes = require('./routes/documents');
const notificationRoutes = require('./routes/notifications');
const dashboardRoutes = require('./routes/dashboard');
const visitorRoutes   = require('./routes/visitors');

const app = express();

// ─── Security Middleware ───────────────────────────────────────────────────────
app.use(helmet());
app.use(cors({
  origin: process.env.FRONTEND_URL || '*',
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: process.env.NODE_ENV === 'production' ? 200 : 1000,
  message: { success: false, message: 'Too many requests, please try again later.' },
  skip: (req) => req.ip === '::1' || req.ip === '127.0.0.1', // skip localhost
});
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: process.env.NODE_ENV === 'production' ? 20 : 100,
  message: { success: false, message: 'Too many auth attempts, please try again later.' },
});

app.use('/api/', limiter);
app.use('/api/auth/', authLimiter);

// ─── Body Parsing ──────────────────────────────────────────────────────────────
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// ─── Logging ──────────────────────────────────────────────────────────────────
if (process.env.NODE_ENV === 'development') {
  app.use(morgan('dev'));
}

// ─── Static Files ─────────────────────────────────────────────────────────────
app.use('/uploads', express.static(path.join(__dirname, '../uploads')));

// ─── Routes ───────────────────────────────────────────────────────────────────
app.use('/api/auth', authRoutes);
app.use('/api/members', memberRoutes);
app.use('/api/ledger', ledgerRoutes);
app.use('/api/payments', paymentRoutes);
app.use('/api/expenses', expenseRoutes);
app.use('/api/complaints', complaintRoutes);
app.use('/api/events', eventRoutes);
app.use('/api/inventory', inventoryRoutes);
app.use('/api/documents', documentRoutes);
app.use('/api/notifications', notificationRoutes);
app.use('/api/dashboard', dashboardRoutes);
app.use('/api/visitors',  visitorRoutes);

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString(), version: '1.0.0' });
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({ success: false, message: 'Route not found' });
});

// Error handler
app.use(errorHandler);

// ─── Database Connection ───────────────────────────────────────────────────────
mongoose.connect(process.env.MONGODB_URI, {
  useNewUrlParser: true,
  useUnifiedTopology: true,
})
.then(() => {
  logger.info('✅ MongoDB connected successfully');
  
  const PORT = process.env.PORT || 5000;
  app.listen(PORT, '0.0.0.0', () => {
    logger.info(`🚀 Server running on port ${PORT} in ${process.env.NODE_ENV} mode`);
    startCronJobs(); // Start background jobs
  });
})
.catch((err) => {
  logger.error('❌ MongoDB connection error:', err);
  process.exit(1);
});

module.exports = app;
