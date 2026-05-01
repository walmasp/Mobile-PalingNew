const db = require('./config/database');

// Daftar template nama menu
const daftarKopi = ['Espresso', 'Americano', 'Cafe Latte', 'Cappuccino', 'Caramel Macchiato', 'Kopi Susu Gula Aren', 'Mocha Latte', 'Vanilla Latte'];
const daftarMakanan = ['Croissant Butter', 'Cheesecake', 'Kentang Goreng', 'Nasi Goreng Spesial', 'Spaghetti Carbonara', 'Sandwich Beef', 'Mendoan Anget'];
const daftarNonKopi = ['Matcha Latte', 'Taro Latte', 'Chocolate Ice', 'Lemon Tea', 'Lychee Tea', 'Red Velvet Latte'];

// Fungsi kecil untuk mengambil kata acak dari array di atas
function getRandomItem(arr) {
    return arr[Math.floor(Math.random() * arr.length)];
}

function seedMenus() {
    console.log('Mulai membaca data cafe dari database... 🕵️‍♂️');

    // 1. Ambil semua ID Cafe yang sudah ada di database
    db.query('SELECT id, nama_cafe FROM cafes', (err, cafes) => {
        if (err) {
            console.error('❌ Gagal mengambil data cafe:', err);
            return db.end();
        }

        if (cafes.length === 0) {
            console.log('⚠️ Belum ada data cafe! Jalankan seed_jogja.js dulu ya.');
            return db.end();
        }

        console.log(`Ketemu ${cafes.length} cafe! Mulai meracik menu... 🍳☕\n`);

        let insertedCount = 0;
        let totalMenusToInsert = 0;

        // 2. Looping setiap cafe untuk dibuatkan menu
        cafes.forEach((cafe) => {
            const cafeId = cafe.id;
            // Kita buat acak: tiap cafe punya 5 sampai 10 menu
            const jumlahMenu = Math.floor(Math.random() * 6) + 5; 
            totalMenusToInsert += jumlahMenu;

            for (let i = 0; i < jumlahMenu; i++) {
                // Tentukan probabilitas kategori secara acak
                const kategoriAcak = Math.random();
                let namaMenu, kategori, keywordFoto;

                // 50% Kopi, 30% Makanan, 20% Non-Kopi
                if (kategoriAcak < 0.5) {
                    namaMenu = getRandomItem(daftarKopi);
                    kategori = 'minuman';
                    keywordFoto = 'coffee,latte,espresso';
                } else if (kategoriAcak < 0.8) {
                    namaMenu = getRandomItem(daftarMakanan);
                    kategori = 'makanan';
                    keywordFoto = 'food,cake,dessert';
                } else {
                    namaMenu = getRandomItem(daftarNonKopi);
                    kategori = 'minuman';
                    keywordFoto = 'drink,tea,matcha';
                }

                // Harga acak kelipatan 1000 (antara Rp 15.000 sampai Rp 45.000)
                const harga = (Math.floor(Math.random() * 31) + 15) * 1000;
                const deskripsi = `Nikmati lezatnya ${namaMenu} spesial dari kami. Dibuat dengan bahan berkualitas.`;
                
                // Foto acak sesuai keyword (biar gambar kopi nggak keluar gambar nasi goreng)
                const randomNum = Math.floor(Math.random() * 1000);
                const foto_url = `https://loremflickr.com/400/300/${keywordFoto}?random=${randomNum}`;
                const stok_tersedia = 1; // 1 artinya stok ada

                const query = 'INSERT INTO menus (cafe_id, nama_menu, deskripsi, harga, kategori, stok_tersedia, foto_url) VALUES (?, ?, ?, ?, ?, ?, ?)';
                
                db.query(query, [cafeId, namaMenu, deskripsi, harga, kategori, stok_tersedia, foto_url], (err, result) => {
                    if (err) {
                        console.error(`❌ Gagal insert menu untuk ${cafe.nama_cafe}:`, err.message);
                    }
                    
                    insertedCount++;
                    // Kalau semua data sudah masuk, tutup koneksi database
                    if (insertedCount === totalMenusToInsert) {
                        console.log(`\n🎉 Mantap! ${insertedCount} menu berhasil ditambahkan ke ${cafes.length} cafe!`);
                        db.end();
                    }
                });
            }
        });
    });
}

seedMenus();