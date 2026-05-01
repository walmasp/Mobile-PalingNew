const express = require('express');
const router = express.Router();
const menuController = require('../controllers/menuController');

// 1. Panggil file satpamnya
const authMiddleware = require('../middlewares/authMiddleware');

// 2. URL Lihat Menu: Tidak perlu satpam, karena pelanggan yang belum login juga boleh lihat-lihat katalog.
router.get('/', menuController.getAllMenus);

// 3. URL Tambah Menu: Pasang 2 satpam (verifyToken dan isAdmin) di tengah-tengah!
router.post('/', authMiddleware.verifyToken, authMiddleware.isAdmin, menuController.addMenu);

module.exports = router;