const express = require('express');
const router = express.Router();
const tableController = require('../controllers/tableController');
const authMiddleware = require('../middlewares/authMiddleware');

// URL Lihat Meja (Bisa diakses siapa saja)
router.get('/', tableController.getAllTables);

// URL Tambah Meja (Harus login DAN wajib Admin)
router.post('/', authMiddleware.verifyToken, authMiddleware.isAdmin, tableController.addTable);

module.exports = router;