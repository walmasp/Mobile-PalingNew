const db = require('../config/database');

// --- TAMPILKAN MENU (Bisa di-filter per Cafe) ---
exports.getAllMenus = (req, res) => {
    // Mengecek apakah Flutter meminta menu untuk cafe tertentu (?cafe_id=1)
    const cafe_id = req.query.cafe_id; 
    
    let query = 'SELECT * FROM menus';
    let params = [];

    // Jika ada filter cafe_id, tampilkan menu cafe tersebut saja
    if (cafe_id) {
        query += ' WHERE cafe_id = ?';
        params.push(cafe_id);
    }
    
    db.query(query, params, (err, results) => {
        if (err) return res.status(500).json({ error: err.message });
        res.status(200).json({
            message: 'Berhasil mengambil data menu',
            data: results
        });
    });
};

// --- TAMBAH MENU BARU ---
exports.addMenu = (req, res) => {
    const { cafe_id, nama_menu, deskripsi, harga, kategori, stok_tersedia, foto_url } = req.body;

    const query = 'INSERT INTO menus (cafe_id, nama_menu, deskripsi, harga, kategori, stok_tersedia, foto_url) VALUES (?, ?, ?, ?, ?, ?, ?)';
    
    const stok = stok_tersedia !== undefined ? stok_tersedia : 1;

    db.query(query, [cafe_id, nama_menu, deskripsi, harga, kategori, stok, foto_url], (err, result) => {
        if (err) return res.status(500).json({ error: err.message });
        res.status(201).json({ 
            message: 'Menu baru berhasil ditambahkan ke Cafe tersebut!',
            menuId: result.insertId 
        });
    });
};
