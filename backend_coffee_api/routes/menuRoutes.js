const express = require('express');
const router = express.Router();
const menuController = require('../controllers/menuController');

const authMiddleware = require('../middlewares/authMiddleware');

router.get('/', menuController.getAllMenus);

router.post('/', authMiddleware.verifyToken, authMiddleware.isAdmin, menuController.addMenu);

module.exports = router;
