const express = require('express');
const router = express.Router();
const bookingController = require('../controllers/bookingController');
const authMiddleware = require('../middlewares/authMiddleware');

// ==========================================
// URL UNTUK PELANGGAN
// ==========================================
// Membuat booking baru
router.post('/', authMiddleware.verifyToken, bookingController.createFullBooking);

// Melihat daftar booking milik saya
router.get('/my-bookings', authMiddleware.verifyToken, bookingController.getMyBookings);

// Mengecek status booking dari HP (Polling)
router.get('/status/:id', authMiddleware.verifyToken, bookingController.getBookingStatus);

// 🔥 RUTE NOTIFIKASI (TARUH DI SINI)
// 1. Mengambil daftar notifikasi milik saya
router.get('/notifications/me', authMiddleware.verifyToken, bookingController.getMyNotifications);

// 2. Menyimpan notifikasi baru (Pemicu dari Flutter saat bayar/menang game)
router.post('/notifications', authMiddleware.verifyToken, bookingController.createNotification);


// ==========================================
// URL UNTUK ADMIN / KASIR
// ==========================================
// 1. Lihat semua booking (Wajib Admin)
router.get('/admin/all', authMiddleware.verifyToken, authMiddleware.isAdmin, bookingController.getAllBookings);

// 2. Update status booking (Wajib Admin) - ':id' adalah angka ID bookingnya
router.put('/admin/status/:id', authMiddleware.verifyToken, authMiddleware.isAdmin, bookingController.updateBookingStatus);

// 3. Scan QR Code dari pelanggan (Wajib Admin)
router.post('/admin/scan', authMiddleware.verifyToken, authMiddleware.isAdmin, bookingController.scanQRCode);


// 🔥 PASTIKAN module.exports BERADA DI PALING BAWAH
module.exports = router;