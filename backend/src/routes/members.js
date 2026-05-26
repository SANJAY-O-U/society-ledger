const express = require('express');
const router  = express.Router();
const { protect, managementAccess, authorize } = require('../middleware/auth');
const upload  = require('../utils/fileUpload');
const {
  getMembers, getMember, createMember, updateMember,
  deactivateMember, downloadStatement, getWings, exportCSV,
} = require('../controllers/memberController');

router.use(protect);

router.get('/meta/wings', managementAccess, getWings);
router.get('/export/csv', managementAccess, exportCSV);

router.get('/',    getMembers);
router.post('/',   managementAccess, createMember);
router.get('/:id', getMember);
router.put('/:id', managementAccess, updateMember);
router.delete('/:id', authorize('admin'), deactivateMember);
router.get('/:id/statement', downloadStatement);

router.post('/:id/documents', managementAccess, upload.single('document'), async (req, res) => {
  const Member = require('../models/Member');
  const member = await Member.findById(req.params.id);
  if (!member) return res.status(404).json({ success: false, message: 'Member not found' });
  if (!req.file) return res.status(400).json({ success: false, message: 'No file uploaded' });
  member.documents.push({ name: req.body.name || req.file.originalname, type: req.body.docType || 'other', url: `/uploads/${req.file.filename}` });
  await member.save();
  res.json({ success: true, data: member.documents });
});

module.exports = router;
