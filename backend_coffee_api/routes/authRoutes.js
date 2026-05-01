const express = require('express');
const router = express.Router();
const authController = require('../controllers/authController');
const authMiddleware = require('../middlewares/authMiddleware');

router.get('/profile', authMiddleware.verifyToken, authController.getProfile);

// Mendaftarkan URL untuk Register dan Login
router.post('/register', authController.register);
router.post('/login', authController.login);

// 🔥 Cukup panggil controllernya saja, karena Multer sudah di-handle di dalam authController
router.post('/update-profile', authController.updateProfile);

// Endpoint untuk menyimpan poin dari Mini Games
router.post('/add-points', authController.addGamePoints);

router.post('/get-poin', authController.getUserPoints);

module.exports = router;