const express = require('express');
const router = express.Router();
const authController = require('../controllers/authController');
const authMiddleware = require('../middlewares/authMiddleware');

// GET profile (butuh token)
router.get('/profile', authMiddleware.verifyToken, authController.getProfile);

// Register & Login (tidak butuh token)
router.post('/register', authController.register);
router.post('/login', authController.login);

// Update profil foto & kesan pesan
// PENTING: Sekarang pakai authMiddleware.verifyToken agar user_id diambil dari token,
// bukan dari body request. Ini lebih aman.
router.post('/update-profile', authMiddleware.verifyToken, authController.updateProfile);

// Endpoint untuk menyimpan poin dari Mini Games
router.post('/add-points', authController.addGamePoints);

// Endpoint untuk mengambil poin user (dipakai oleh ProfileScreen & PointProvider)
router.post('/get-poin', authController.getUserPoints);

// Endpoint klaim reward (reset poin ke 0 di DB)
router.post('/claim-reward', authController.claimReward);

// Endpoint untuk Forgot Password
router.post('/forgot-password', authController.forgotPassword);

module.exports = router;