const express = require('express');
const router = express.Router();
const authController = require('../controllers/authController');
const authMiddleware = require('../middlewares/authMiddleware');

router.get('/profile', authMiddleware.verifyToken, authController.getProfile);

// Mendaftarkan URL untuk Register dan Login
router.post('/register', authController.register);
router.post('/login', authController.login);

// Update profil (foto & kesan pesan)
router.post('/update-profile', authController.updateProfile);

// Endpoint untuk menyimpan poin dari Mini Games
router.post('/add-points', authController.addGamePoints);

// Endpoint untuk mengambil poin user (dipakai oleh ProfileScreen & PointProvider)
router.post('/get-poin', authController.getUserPoints);

// 🔥 Endpoint baru: klaim reward (reset poin ke 0 di DB)
router.post('/claim-reward', authController.claimReward);

// Endpoint untuk Forgot Password
router.post('/forgot-password', authController.forgotPassword);

module.exports = router;