const db = require('../config/database');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
// 🔥 TAMBAHAN: Import multer dan path untuk upload file
const multer = require('multer');
const path = require('path');

// ==========================================
// KONFIGURASI MULTER (Untuk Foto Profil)
// ==========================================
const storage = multer.diskStorage({
    destination: function (req, file, cb) {
        cb(null, 'uploads/') // Pastikan folder 'uploads' sudah kamu buat di root backend!
    },
    filename: function (req, file, cb) {
        // Nama file unik agar tidak bertabrakan
        cb(null, 'profile-' + Date.now() + path.extname(file.originalname))
    }
});

const upload = multer({ storage: storage }).single('foto_profil');


// --- FITUR REGISTER ---
exports.register = async (req, res) => {
    const { nama, email, password, role } = req.body;

    try {
        // 1. Enkripsi Password (Hashing)
        const salt = await bcrypt.genSalt(10);
        const hashedPassword = await bcrypt.hash(password, salt);

        // 2. Simpan ke Database
        const query = 'INSERT INTO users (nama, email, password, role) VALUES (?, ?, ?, ?)';
        // Default role kita set 'pelanggan' jika tidak diisi
        const userRole = role || 'pelanggan'; 

        db.query(query, [nama, email, hashedPassword, userRole], (err, result) => {
            if (err) {
                // Jika email sudah terdaftar (karena di DB kita set UNIQUE)
                if (err.code === 'ER_DUP_ENTRY') {
                    return res.status(400).json({ message: 'Email sudah terdaftar!' });
                }
                return res.status(500).json({ error: err.message });
            }
            res.status(201).json({ message: 'Register berhasil! Silakan login.' });
        });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
};

// --- FITUR LOGIN ---
exports.login = (req, res) => {
    const { email, password } = req.body;

    // 1. Cari user berdasarkan email
    const query = 'SELECT * FROM users WHERE email = ?';
    db.query(query, [email], async (err, results) => {
        if (err) return res.status(500).json({ error: err.message });
        
        // Jika user tidak ditemukan
        if (results.length === 0) {
            return res.status(404).json({ message: 'Email tidak ditemukan!' });
        }

        const user = results[0];

        // 2. Cek kecocokan password asli dengan password enkripsi di DB
        const isMatch = await bcrypt.compare(password, user.password);
        if (!isMatch) {
            return res.status(401).json({ message: 'Password salah!' });
        }

        // 3. Buat Session (JWT Token)
        // Token ini berisi ID dan Role user, dan akan kedaluwarsa dalam 1 hari
        const token = jwt.sign(
            { id: user.id, role: user.role }, 
            process.env.JWT_SECRET, 
            { expiresIn: '1d' }
        );

        // 4. Kirim balasan ke HP (Flutter)
        res.status(200).json({
            message: 'Login berhasil!',
            token: token,
            user: {
                id: user.id,
                nama: user.nama,
                email: user.email,
                role: user.role,
                foto_profil: user.foto_profil // 🔥 TAMBAHAN: Kirim URL foto profil agar tersimpan di SharedPreferences HP
            }
        });
    });
};

// --- FITUR GET PROFILE ---
exports.getProfile = (req, res) => {
    const user_id = req.user.id;

    // 🔥 TAMBAHAN: Masukkan foto_profil di dalam daftar SELECT
    const query = 'SELECT id, nama, email, role, foto_profil FROM users WHERE id = ?';

    db.query(query, [user_id], (err, results) => {
        if (err) return res.status(500).json({ error: err.message });

        if (results.length === 0) {
            return res.status(404).json({ message: 'User tidak ditemukan' });
        }

        res.status(200).json({
            message: 'Berhasil ambil profile',
            user: results[0]
        });
    });
};

// ==========================================
// 🔥 FITUR UPLOAD FOTO PROFIL
// ==========================================
exports.uploadProfilePhoto = (req, res) => {
    upload(req, res, function (err) {
        // Tangani error multer
        if (err) return res.status(500).json({ error: err.message });
        
        // Cek jika user tidak mengirimkan file gambar
        if (!req.file) return res.status(400).json({ message: "Tidak ada file yang dipilih" });

        // Path gambar yang akan disimpan di database
        const fotoUrl = `/uploads/${req.file.filename}`;
        const userId = req.user.id; // Didapat dari verifyToken

        // Update URL foto di tabel users
        const query = "UPDATE users SET foto_profil = ? WHERE id = ?";
        db.query(query, [fotoUrl, userId], (err, result) => {
            if (err) return res.status(500).json({ error: err.message });
            
            res.status(200).json({ 
                message: "Foto profil berhasil diubah!", 
                foto_profil: fotoUrl 
            });
        });
    });
};