const db = require('../config/database');

// --- TAMPILKAN MEJA (Bisa di-filter per cafe) ---
exports.getAllTables = (req, res) => {
    // Mengecek apakah Flutter meminta meja untuk cafe tertentu (?cafe_id=1)
    const cafe_id = req.query.cafe_id; 
    
    let query = 'SELECT * FROM tables WHERE is_active = 1';
    let params = [];

    if (cafe_id) {
        query += ' AND cafe_id = ?'; 
        params.push(cafe_id);
    }
    
    db.query(query, params, (err, results) => {
        if (err) return res.status(500).json({ error: err.message });
        res.status(200).json({
            message: 'Berhasil mengambil data meja',
            data: results
        });
    });
};

// --- TAMBAH MEJA BARU ---
exports.addTable = (req, res) => {
    const { nomor_meja, kapasitas, area, cafe_id } = req.body;
    
    const query = 'INSERT INTO tables (nomor_meja, kapasitas, area, cafe_id) VALUES (?, ?, ?, ?)';
    
    db.query(query, [nomor_meja, kapasitas, area, cafe_id], (err, result) => {
        if (err) return res.status(500).json({ error: err.message });
        res.status(201).json({ 
            message: 'Meja baru berhasil ditambahkan ke cafe tersebut!',
            tableId: result.insertId 
        });
    });
};
