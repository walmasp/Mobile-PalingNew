const db = require('../config/database'); 

exports.getRecommendations = async (req, res) => {
    try {
        const userId = req.params.userId;

        const [userBookings] = await db.promise().query(
            'SELECT COUNT(*) as total_pesanan FROM bookings WHERE user_id = ?', 
            [userId]
        );

        const totalPesanan = userBookings[0].total_pesanan;

        if (totalPesanan === 0) {
            // Ditambahkan: c.id AS cafe_id, c.nama_cafe dan JOIN cafes
            const [bestSellers] = await db.promise().query(`
                SELECT m.id, m.nama_menu, m.harga, m.foto_url, c.id AS cafe_id, c.nama_cafe, SUM(bd.jumlah) AS total_dipesan
                FROM booking_details bd
                JOIN menus m ON bd.menu_id = m.id
                JOIN cafes c ON m.cafe_id = c.id
                GROUP BY m.id, m.nama_menu, m.harga, m.foto_url, c.id, c.nama_cafe
                ORDER BY total_dipesan DESC
                LIMIT 5
            `);

            return res.status(200).json({
                success: true,
                type: 'best_seller',
                title: 'Pilihan Favorit Pelanggan 🔥', 
                data: bestSellers
            });
        } 
        else {
            // Ditambahkan: c.id AS cafe_id, c.nama_cafe dan JOIN cafes
            const [personalizedData] = await db.promise().query(`
                SELECT m.id, m.nama_menu, m.harga, m.foto_url, c.id AS cafe_id, c.nama_cafe, SUM(bd.jumlah) AS user_total_beli
                FROM bookings b
                JOIN booking_details bd ON b.id = bd.booking_id
                JOIN menus m ON bd.menu_id = m.id
                JOIN cafes c ON m.cafe_id = c.id
                WHERE b.user_id = ?
                GROUP BY m.id, m.nama_menu, m.harga, m.foto_url, c.id, c.nama_cafe
                ORDER BY user_total_beli DESC
                LIMIT 5
            `, [userId]);
            
            if (personalizedData.length === 0) {
                 const [bestSellersFallback] = await db.promise().query(`
                    SELECT m.id, m.nama_menu, m.harga, m.foto_url, c.id AS cafe_id, c.nama_cafe, SUM(bd.jumlah) AS total_dipesan
                    FROM booking_details bd
                    JOIN menus m ON bd.menu_id = m.id
                    JOIN cafes c ON m.cafe_id = c.id
                    GROUP BY m.id, m.nama_menu, m.harga, m.foto_url, c.id, c.nama_cafe
                    ORDER BY total_dipesan DESC
                    LIMIT 5
                `);
                return res.status(200).json({
                    success: true,
                    type: 'best_seller',
                    title: 'Pilihan Favorit Pelanggan 🔥', 
                    data: bestSellersFallback
                });
            }

            return res.status(200).json({
                success: true,
                type: 'personalized',
                title: 'Direkomendasikan Untukmu ✨', 
                data: personalizedData
            });
        }

    } catch (error) {
        console.error("Error Get Recommendation:", error);
        res.status(500).json({ success: false, message: 'Server Error' });
    }
};