const jwt = require('jsonwebtoken');
require('dotenv').config();

// --- Lapis 1: Satpam Pengecek Tiket Login (Semua yang punya token boleh lewat) ---
exports.verifyToken = (req, res, next) => {
    const authHeader = req.headers['authorization'];
    // Tiket/Token dari HP biasanya dikirim dengan format: "Bearer <token_panjang>"
    const token = authHeader && authHeader.split(' ')[1];

    if (!token) {
        return res.status(401).json({ message: 'Akses ditolak! Anda belum login (Token tidak ada).' });
    }

    // Cek keaslian tiket
    jwt.verify(token, process.env.JWT_SECRET, (err, decoded) => {
        if (err) {
            return res.status(403).json({ message: 'Token tidak valid atau sudah kedaluwarsa silakan login ulang!' });
        }
        
        // Menyimpan data user (id dan role) dari dalam tiket JWT ke dalam req
        // agar bisa dicek oleh satpam lapis 2
        req.user = decoded; 
        next(); 
    });
};

// --- Lapis 2: Satpam Pengecek Jabatan (Hanya role 'admin' yang boleh lewat) ---
exports.isAdmin = (req, res, next) => {
    if (req.user.role !== 'admin') {
        return res.status(403).json({ message: 'Akses ditolak! Fitur ini khusus Admin / Kasir.' });
    }
    next(); 
};
