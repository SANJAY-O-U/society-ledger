// ============================================================
// routes/ledger.js
// ============================================================
const express = require('express');
const router = express.Router();
const { protect, managementAccess, financeAccess } = require('../middleware/auth');
const {
  getMemberLedger, getAllPendingDues, addTransaction,
  generateMonthlyMaintenance, applyLateFees, downloadReceipt, getLedgerSummary,
} = require('../controllers/ledgerController');

router.use(protect);
router.get('/pending-dues', financeAccess, getAllPendingDues);
router.get('/summary', financeAccess, getLedgerSummary);
router.get('/receipt/:transactionId', downloadReceipt);
router.get('/:memberId', getMemberLedger);
router.post('/add-transaction', financeAccess, addTransaction);
router.post('/generate-maintenance', financeAccess, generateMonthlyMaintenance);
router.post('/apply-late-fee', financeAccess, applyLateFees);

module.exports = router;
