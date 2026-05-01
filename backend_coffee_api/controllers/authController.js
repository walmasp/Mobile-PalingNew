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
                foto_profil: user.foto_profil, 
                kesan_pesan: user.kesan_pesan,
                poin: user.poin // 🔥 PERBAIKAN: Poin ikut dikirim ke HP saat login
            }
        });
    });
};

// --- FITUR GET PROFILE ---
exports.getProfile = (req, res) => {
    const user_id = req.user.id;

    // 🔥 PERBAIKAN: Tambahkan 'poin' ke dalam daftar yang diambil dari database
    const query = 'SELECT id, nama, email, role, foto_profil, kesan_pesan, poin FROM users WHERE id = ?';

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
// 🔥 PERBAIKAN: FITUR UPDATE PROFIL (FOTO & KESAN PESAN)
// ==========================================
exports.updateProfile = (req, res) => {
    upload(req, res, function (err) {
        // Tangani error multer
        if (err) return res.status(500).json({ error: err.message });
        
        // Tangkap data yang dikirim dari Flutter (karena pakai FormData, ada di req.body)
        const { email, kesan_pesan } = req.body;
        let fotoUrl = null;

        // Jika user mengupload foto baru
        if (req.file) {
            // URL otomatis mendeteksi protokol (http/https) dan host/IP komputer kamu
            fotoUrl = `${req.protocol}://${req.get('host')}/uploads/${req.file.filename}`;
        }

        // Siapkan query update untuk MySQL
        let query = "UPDATE users SET kesan_pesan = ?";
        let values = [kesan_pesan];

        // Jika foto juga dikirim, tambahkan ke query
        if (fotoUrl) {
            query += ", foto_profil = ?";
            values.push(fotoUrl);
        }

        // Kondisi update berdasarkan email
        query += " WHERE email = ?";
        values.push(email);

        // Eksekusi query ke database
        db.query(query, values, (err, result) => {
            if (err) return res.status(500).json({ error: err.message });
            
            res.status(200).json({ 
                message: "Profil berhasil diperbarui!", 
                foto_url: fotoUrl,
                kesan_pesan: kesan_pesan
            });
        });
    });
};

// ==========================================
// FITUR TAMBAH POIN & CATAT AKTIVITAS
// ==========================================
exports.addGamePoints = (req, res) => {
    const { email, poin_tambahan, nama_game } = req.body;

    // 1. Cari ID user berdasarkan email
    db.query('SELECT id FROM users WHERE email = ?', [email], (err, users) => {
        if (err) return res.status(500).json({ error: err.message });
        if (users.length === 0) return res.status(404).json({ message: 'User tidak ditemukan' });

        const user_id = users[0].id;

        // 2. Tambahkan poin ke tabel users
        db.query('UPDATE users SET poin = poin + ? WHERE email = ?', [poin_tambahan, email], (err, result) => {
            if (err) return res.status(500).json({ error: err.message });

            // 3. Catat history ke tabel notifications (Aktivitas)
            const judul = `Game Reward! 🎮`;
            const pesan = `Hore! Kamu berhasil mendapatkan ${poin_tambahan} Poin dari permainan ${nama_game}.`;

            db.query('INSERT INTO notifications (user_id, judul, pesan) VALUES (?, ?, ?)', [user_id, judul, pesan], (err, notifResult) => {
                if (err) return res.status(500).json({ error: err.message });
                
                res.status(200).json({ 
                    message: 'Poin berhasil ditambahkan dan aktivitas dicatat!',
                    poin_tambahan: poin_tambahan 
                });
            });
        });
    });
};

// Fungsi untuk mengambil sisa poin user
exports.getUserPoints = (req, res) => {
    const { email } = req.body;

    db.query('SELECT poin FROM users WHERE email = ?', [email], (err, results) => {
        if (err) {
            console.error("Gagal mengambil poin:", err);
            return res.status(500).json({ error: 'Server error' });
        }
        if (results.length === 0) {
            return res.status(404).json({ message: 'User tidak ditemukan' });
        }
        
        // Kirimkan jumlah poin ke Flutter
        res.status(200).json({ poin: results[0].poin });
    });
};