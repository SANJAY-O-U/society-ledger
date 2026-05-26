// ============================================================
// routes/payments.js
// ============================================================
const express = require('express');
const router = express.Router();
const { protect, financeAccess } = require('../middleware/auth');
const { createOrder, verifyPayment, recordOfflinePayment, getPayments, getPaymentStats } = require('../controllers/paymentController');

router.use(protect);
router.post('/create-order', createOrder);
router.post('/verify', verifyPayment);
router.post('/cash', financeAccess, recordOfflinePayment);
router.get('/', getPayments);
router.get('/stats', financeAccess, getPaymentStats);

module.exports = router;
