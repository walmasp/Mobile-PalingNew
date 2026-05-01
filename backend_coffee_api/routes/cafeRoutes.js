const express = require('express');
const router = express.Router();
const cafeController = require('../controllers/cafeController');

// Bisa diakses tanpa login agar muncul di halaman awal peta
router.get('/', cafeController.getAllcafe);

module.exports = router;