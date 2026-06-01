const db = require('../config/database');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const multer = require('multer');
const path = require('path');
const fs = require('fs');

// ==========================================
// KONFIGURASI MULTER (Untuk Foto Profil)
// ==========================================

// Pastikan folder uploads ada, buat jika belum ada
const uploadsDir = path.join(__dirname, '..', 'uploads');
if (!fs.existsSync(uploadsDir)) {
    fs.mkdirSync(uploadsDir, { recursive: true });
}

const storage = multer.diskStorage({
    destination: function (req, file, cb) {
        cb(null, uploadsDir);
    },
    filename: function (req, file, cb) {
        // Nama file unik berdasarkan timestamp agar tidak bentrok
        cb(null, 'profile-' + Date.now() + path.extname(file.originalname));
    }
});

const upload = multer({
    storage: storage,
    limits: { fileSize: 5 * 1024 * 1024 }, // Maksimal 5MB
    fileFilter: function (req, file, cb) {
        // Flutter/Android kadang mengirim MIME type yang tidak standar:
        // - 'image/jpg' (bukan 'image/jpeg')
        // - 'application/octet-stream' (binary stream)
        // - 'image/jpeg;charset=UTF-8' (dengan charset)
        // Solusi: cek MIME type dengan startsWith('image/') ATAU cek ekstensi file.
        // Jika salah satu lolos, izinkan. Ini menangani semua variasi dari Android/iOS.
        const allowedExtensions = /\.(jpeg|jpg|png|gif|webp)$/i;
        const extOk = allowedExtensions.test(path.extname(file.originalname));
        const mimeOk = file.mimetype.startsWith('image/') ||
                       file.mimetype === 'application/octet-stream';

        console.log(`[Upload] filename: ${file.originalname}, mimetype: ${file.mimetype}, extOk: ${extOk}, mimeOk: ${mimeOk}`);

        if (extOk || mimeOk) {
            cb(null, true);
        } else {
            cb(new Error(`Tipe file tidak didukung: ${file.mimetype}. Gunakan gambar (jpg, png, gif, webp).`));
        }
    }
}).single('foto_profil');

// --- FITUR REGISTER ---
exports.register = async (req, res) => {
    const { nama, email, password, role } = req.body;

    try {
        const salt = await bcrypt.genSalt(10);
        const hashedPassword = await bcrypt.hash(password, salt);

        const query = 'INSERT INTO users (nama, email, password, role) VALUES (?, ?, ?, ?)';
        const userRole = role || 'pelanggan';

        db.query(query, [nama, email, hashedPassword, userRole], (err, result) => {
            if (err) {
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

    const query = 'SELECT * FROM users WHERE email = ?';
    db.query(query, [email], async (err, results) => {
        if (err) return res.status(500).json({ error: err.message });

        if (results.length === 0) {
            return res.status(404).json({ message: 'Email tidak ditemukan!' });
        }

        const user = results[0];

        const isMatch = await bcrypt.compare(password, user.password);
        if (!isMatch) {
            return res.status(401).json({ message: 'Password salah!' });
        }

        const token = jwt.sign(
            { id: user.id, role: user.role },
            process.env.JWT_SECRET,
            { expiresIn: '1d' }
        );

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
                poin: user.poin
            }
        });
    });
};

// --- FITUR GET PROFILE ---
exports.getProfile = (req, res) => {
    const user_id = req.user.id;

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
// FITUR UPDATE PROFIL (FOTO & KESAN PESAN)
// ==========================================
// PENTING: Endpoint ini sekarang menggunakan JWT token (authMiddleware)
// untuk mendapatkan user_id, sehingga tidak perlu mengirim email di body.
// Ini lebih aman karena user tidak bisa mengubah profil user lain.
exports.updateProfile = (req, res) => {
    upload(req, res, function (err) {
        if (err) {
            return res.status(400).json({ error: err.message });
        }

        // Ambil user_id dari token JWT yang sudah diverifikasi oleh authMiddleware
        const user_id = req.user.id;
        const { kesan_pesan } = req.body;
        let fotoUrl = null;

        // Jika ada file yang diupload, buat URL-nya
        if (req.file) {
            fotoUrl = `${req.protocol}://${req.get('host')}/uploads/${req.file.filename}`;
        }

        // Bangun query UPDATE secara dinamis
        // - Jika ada foto: update kesan_pesan DAN foto_profil
        // - Jika tidak ada foto: update kesan_pesan saja
        let query;
        let values;

        if (fotoUrl) {
            query = 'UPDATE users SET kesan_pesan = ?, foto_profil = ? WHERE id = ?';
            values = [kesan_pesan || '', fotoUrl, user_id];
        } else {
            query = 'UPDATE users SET kesan_pesan = ? WHERE id = ?';
            values = [kesan_pesan || '', user_id];
        }

        db.query(query, values, (dbErr, result) => {
            if (dbErr) return res.status(500).json({ error: dbErr.message });

            if (result.affectedRows === 0) {
                return res.status(404).json({ message: 'User tidak ditemukan' });
            }

            res.status(200).json({
                message: 'Profil berhasil diperbarui!',
                foto_url: fotoUrl,
                kesan_pesan: kesan_pesan || ''
            });
        });
    });
};

// ==========================================
// FITUR TAMBAH POIN & CATAT AKTIVITAS
// ==========================================
exports.addGamePoints = (req, res) => {
    const { email, poin_tambahan, nama_game } = req.body;

    db.query('SELECT id FROM users WHERE email = ?', [email], (err, users) => {
        if (err) return res.status(500).json({ error: err.message });
        if (users.length === 0) return res.status(404).json({ message: 'User tidak ditemukan' });

        const user_id = users[0].id;

        db.query('UPDATE users SET poin = poin + ? WHERE email = ?', [poin_tambahan, email], (err, result) => {
            if (err) return res.status(500).json({ error: err.message });

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

// ==========================================
// FITUR AMBIL POIN USER
// ==========================================
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

        res.status(200).json({ poin: results[0].poin });
    });
};

// ==========================================
// FITUR KLAIM REWARD (RESET POIN KE 0 DI DB)
// ==========================================
exports.claimReward = (req, res) => {
    const { email } = req.body;

    if (!email) {
        return res.status(400).json({ message: 'Email wajib diisi!' });
    }

    db.query('SELECT id, poin FROM users WHERE email = ?', [email], (err, users) => {
        if (err) return res.status(500).json({ error: err.message });
        if (users.length === 0) return res.status(404).json({ message: 'User tidak ditemukan' });

        const user = users[0];

        if (user.poin < 200) {
            return res.status(400).json({
                message: `Poin tidak mencukupi. Poin saat ini: ${user.poin}. Dibutuhkan minimal 200 poin.`
            });
        }

        db.query('UPDATE users SET poin = 0 WHERE email = ?', [email], (err, result) => {
            if (err) return res.status(500).json({ error: err.message });

            const judul = 'Reward Diklaim! 🎁';
            const pesan = 'Selamat! Kamu telah berhasil menukarkan poinmu dengan Voucher Diskon 50%.';

            db.query(
                'INSERT INTO notifications (user_id, judul, pesan) VALUES (?, ?, ?)',
                [user.id, judul, pesan],
                (err) => {
                    if (err) return res.status(500).json({ error: err.message });

                    res.status(200).json({
                        message: 'Reward berhasil diklaim! Poin telah direset.',
                        poin_sekarang: 0
                    });
                }
            );
        });
    });
};

// ==========================================
// FITUR RESET PASSWORD (LANGSUNG UPDATE)
// ==========================================
exports.forgotPassword = async (req, res) => {
    const { email, newPassword } = req.body;

    if (!email || !newPassword) {
        return res.status(400).json({ message: 'Email dan Password baru wajib diisi!' });
    }

    try {
        const checkQuery = 'SELECT * FROM users WHERE email = ?';
        db.query(checkQuery, [email], async (err, results) => {
            if (err) return res.status(500).json({ error: err.message });

            if (results.length === 0) {
                return res.status(404).json({ message: 'Email tidak terdaftar!' });
            }

            const salt = await bcrypt.genSalt(10);
            const hashedPassword = await bcrypt.hash(newPassword, salt);

            const updateQuery = 'UPDATE users SET password = ? WHERE email = ?';
            db.query(updateQuery, [hashedPassword, email], (updateErr, updateResults) => {
                if (updateErr) return res.status(500).json({ error: updateErr.message });

                res.status(200).json({
                    message: 'Password berhasil diperbarui! Silakan login kembali.'
                });
            });
        });
    } catch (error) {
        res.status(500).json({ error: 'Terjadi kesalahan pada server' });
    }
};