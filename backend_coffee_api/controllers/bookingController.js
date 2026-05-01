const QRCode = require('qrcode');
const db = require('../config/database');

// --- FITUR PELANGGAN ---
// --- BUAT BOOKING + MENU (Checkout) ---
exports.createFullBooking = (req, res) => {
    const user_id = req.user.id;
    const { cafe_id, table_id, jumlah_orang, tanggal_booking, jam_mulai, jam_selesai, items, jenis_pembayaran } = req.body;

    if (!cafe_id || !table_id || !tanggal_booking || !jam_mulai || !jam_selesai) {
        return res.status(400).json({ message: 'Data booking (cafe, meja, tanggal, jam) tidak lengkap' });
    }

    if (!items || items.length === 0) {
        return res.status(400).json({ message: 'Item menu tidak boleh kosong' });
    }

    const checkTableQuery = `
        SELECT id FROM bookings 
        WHERE table_id = ? 
        AND tanggal_booking = ? 
        AND status != 'dibatalkan'
        AND (
            (jam_mulai < ? AND jam_selesai > ?) OR 
            (jam_mulai < ? AND jam_selesai > ?)
        )
    `;

    db.query(checkTableQuery, [table_id, tanggal_booking, jam_selesai, jam_mulai, jam_mulai, jam_selesai], (err, bookedTables) => {
        if (err) return res.status(500).json({ error: err.message });

        if (bookedTables.length > 0) {
            return res.status(400).json({ message: 'Maaf, meja ini sudah dibooking pada jam tersebut.' });
        }

        let total_harga = 0;
        const menuIds = items.map(item => item.menu_id);
        const menuQuery = 'SELECT id, harga FROM menus WHERE id IN (?)';

        db.query(menuQuery, [menuIds], (err, menus) => {
            if (err) return res.status(500).json({ error: err.message });

            const menuMap = {};
            menus.forEach(m => {
                menuMap[m.id] = m.harga;
            });

            const detailValues = [];

            items.forEach(item => {
                const harga = menuMap[item.menu_id];
                const subtotal = harga * item.jumlah;
                total_harga += subtotal;

                detailValues.push([
                    item.menu_id,
                    item.jumlah,
                    harga,
                    subtotal,
                    item.catatan || null
                ]);
            });

            const payment_type = jenis_pembayaran === 'dp_50' ? 'dp_50' : 'lunas';
            const jumlah_dibayar = payment_type === 'dp_50' ? (total_harga / 2) : total_harga;

            const qr_code = 'BK-' + Date.now();
            
            QRCode.toDataURL(qr_code, (err, qr_image) => {
                if (err) return res.status(500).json({ error: err.message });

                const bookingQuery = `
                    INSERT INTO bookings 
                    (user_id, cafe_id, table_id, jumlah_orang, tanggal_booking, jam_mulai, jam_selesai, qr_code, total_harga, jenis_pembayaran, jumlah_dibayar) 
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                `;

                db.query(bookingQuery, 
                    [user_id, cafe_id, table_id, jumlah_orang || 1, tanggal_booking, jam_mulai, jam_selesai, qr_code, total_harga, payment_type, jumlah_dibayar],
                    (err, result) => {
                        if (err) return res.status(500).json({ error: err.message });

                        const booking_id = result.insertId;

                        const detailQuery = `
                            INSERT INTO booking_details 
                            (booking_id, menu_id, jumlah, harga_satuan, subtotal, catatan)
                            VALUES ?
                        `;

                        const finalDetails = detailValues.map(d => [booking_id, ...d]);

                        db.query(detailQuery, [finalDetails], (err) => {
                            if (err) return res.status(500).json({ error: err.message });

                            res.status(201).json({
                                message: 'Booking meja dan pesanan menu berhasil!',
                                booking_id: booking_id,
                                total_harga: total_harga,
                                jenis_pembayaran: payment_type,
                                tagihan_sekarang: jumlah_dibayar,
                                qr_code: qr_code,
                                qr_image: qr_image 
                            });
                        });
                    }
                );
            });
        });
    });
};

exports.getMyBookings = (req, res) => {
    const user_id = req.user.id;
    
    const query = `
        SELECT b.*, t.nomor_meja, t.area, c.nama_cafe 
        FROM bookings b
        JOIN tables t ON b.table_id = t.id
        JOIN cafes c ON b.cafe_id = c.id
        WHERE b.user_id = ?
        ORDER BY b.tanggal_booking DESC, b.jam_mulai DESC
    `;

    db.query(query, [user_id], (err, results) => {
        if (err) return res.status(500).json({ error: err.message });
        res.status(200).json({
            message: 'Berhasil mengambil riwayat booking',
            data: results
        });
    });
};

// --- FITUR KHUSUS ADMIN & KASIR ---
exports.getAllBookings = (req, res) => {
    const query = `
        SELECT b.*, u.nama AS nama_pelanggan, t.nomor_meja, c.nama_cafe 
        FROM bookings b
        JOIN users u ON b.user_id = u.id
        JOIN tables t ON b.table_id = t.id
        JOIN cafes c ON b.cafe_id = c.id
        ORDER BY b.tanggal_booking DESC, b.jam_mulai ASC
    `;

    db.query(query, (err, results) => {
        if (err) return res.status(500).json({ error: err.message });
        res.status(200).json({
            message: 'Berhasil mengambil semua data booking',
            data: results
        });
    });
};

exports.updateBookingStatus = (req, res) => {
    const booking_id = req.params.id;
    const { status } = req.body;

    const query = 'UPDATE bookings SET status = ? WHERE id = ?';
    
    db.query(query, [status, booking_id], (err, result) => {
        if (err) return res.status(500).json({ error: err.message });
        
        if (result.affectedRows === 0) {
            return res.status(404).json({ message: 'Data booking tidak ditemukan!' });
        }
        
        res.status(200).json({ message: `Status booking berhasil diubah menjadi: ${status}` });
    });
};

exports.scanQRCode = (req, res) => {
    const { qr_code } = req.body;

    const query = 'SELECT * FROM bookings WHERE qr_code = ?';
    
    db.query(query, [qr_code], (err, results) => {
        if (err) return res.status(500).json({ error: err.message });
        
        if (results.length === 0) {
            return res.status(404).json({ message: 'QR Code tidak valid atau tidak ditemukan!' });
        }

        const booking = results[0];

        const updateQuery = 'UPDATE bookings SET status = "selesai" WHERE id = ?';
        db.query(updateQuery, [booking.id], (err, updateResult) => {
            if (err) return res.status(500).json({ error: err.message });
            
            res.status(200).json({ 
                message: 'Scan QR berhasil! Pelanggan telah check-in.',
                booking_data: booking
            });
        });
    });
};

// ==========================================
// --- FITUR REAL-TIME (POLLING STATUS) ---
// ==========================================
exports.getBookingStatus = (req, res) => {
    const booking_id = req.params.id;
    const query = 'SELECT status FROM bookings WHERE id = ?';
    
    db.query(query, [booking_id], (err, results) => {
        if (err) return res.status(500).json({ error: err.message });
        if (results.length === 0) return res.status(404).json({ message: 'Booking tidak ditemukan' });
        
        res.status(200).json({ status: results[0].status });
    });
};

// ==========================================
// --- FITUR NOTIFIKASI ---
// ==========================================
exports.getMyNotifications = (req, res) => {
    const user_id = req.user.id;
    const query = 'SELECT * FROM notifications WHERE user_id = ? ORDER BY created_at DESC';
    
    db.query(query, [user_id], (err, results) => {
        if (err) return res.status(500).json({ error: err.message });
        res.status(200).json({ data: results });
    });
};

// 🔥 TAMBAHAN: FUNGSI UNTUK MEMBUAT NOTIFIKASI BARU (Dipanggil oleh Flutter)
exports.createNotification = (req, res) => {
    const { judul, pesan } = req.body;
    const user_id = req.user.id;

    const query = 'INSERT INTO notifications (user_id, judul, pesan) VALUES (?, ?, ?)';
    db.query(query, [user_id, judul, pesan], (err, result) => {
        if (err) return res.status(500).json({ error: err.message });
        res.status(201).json({ 
            message: 'Notifikasi berhasil disimpan', 
            id: result.insertId 
        });
    });
};