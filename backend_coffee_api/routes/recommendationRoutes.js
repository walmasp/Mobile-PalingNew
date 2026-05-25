const express = require('express');
const router = express.Router();
const recommendationController = require('../controllers/recommendationController');
const authMiddleware = require('../middlewares/authMiddleware'); // Opsional jika API ini butuh token

// Endpoint: GET /api/recommendations/:userId
// Gunakan authMiddleware jika endpoint ini butuh token JWT, hapus jika public
router.get('/:userId', recommendationController.getRecommendations);

module.exports = router;