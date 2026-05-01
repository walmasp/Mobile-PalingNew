const db = require('../config/database');

exports.getAllcafe = (req, res) => {
    const query = 'SELECT * FROM cafes';
    
    db.query(query, (err, results) => {
        if (err) return res.status(500).json({ error: err.message });
        res.status(200).json({
            message: 'Berhasil mengambil data cabang',
            data: results
        });
    });
};