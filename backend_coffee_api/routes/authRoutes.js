const express = require('express');
const router = express.Router();
const authController = require('../controllers/authController');

const authMiddleware = require('../middlewares/authMiddleware');

router.get('/profile', authMiddleware.verifyToken, authController.getProfile);

// Mendaftarkan URL untuk Register dan Login
router.post('/register', authController.register);
router.post('/login', authController.login);

module.exports = router;