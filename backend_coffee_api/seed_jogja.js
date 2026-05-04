const axios = require('axios');
const db = require('./config/database');

async function seedJogjaCafes() {
    console.log('Mencari data cafe di Jogja dari OpenStreetMap... 🕵️‍♂️');

    // Query Overpass API (Cari 15 Cafe dalam radius 5km dari pusat Jogja)
    const overpassQuery = `
        [out:json];
        // around:5000 artinya radius 5000 meter (5km)
        // -7.7956, 110.3695 adalah titik koordinat pusat Jogja (area Malioboro)
        node(around:5000, -7.7956, 110.3695)["amenity"="cafe"];
        out 15;
    `;

    try {
        const response = await axios.post('https://overpass-api.de/api/interpreter', overpassQuery, {
            headers: { 
                'Content-Type': 'text/plain',
                'Accept': 'application/json',
                'User-Agent': 'CoffeeShopApp/1.0 (belajar_flutter)' 
            }
        });

        const elements = response.data.elements;
        const validCafes = elements.filter(cafe => cafe.tags && cafe.tags.name);
        
        console.log(`Mantap! Ketemu ${validCafes.length} cafe valid. Mulai memproses data... 🚀\n`);

        let insertedCount = 0;

        validCafes.forEach((cafe, index) => {
            const nama_cafe = cafe.tags.name;
            const alamat = cafe.tags['addr:street'] ? `${cafe.tags['addr:street']}, Yogyakarta` : 'Yogyakarta';
            const latitude = cafe.lat;
            const longitude = cafe.lon;

            const rating = (Math.random() * (5.0 - 4.0) + 4.0).toFixed(1);
            const foto_url = `https://loremflickr.com/400/300/cafe,coffee?random=${index + 1}`;

            const query = 'INSERT INTO cafes (nama_cafe, alamat, latitude, longitude, rating, foto_url) VALUES (?, ?, ?, ?, ?, ?)';
            
            db.query(query, [nama_cafe, alamat, latitude, longitude, rating, foto_url], (err, result) => {
                if (err) {
                    console.error(`❌ Gagal insert ${nama_cafe}:`, err.message);
                } else {
                    console.log(`✅ Berhasil: ${nama_cafe} (⭐ ${rating})`);
                }

                insertedCount++;
                if (insertedCount === validCafes.length) {
                    console.log('\n🎉 Semua data berhasil dimasukkan ke database!');
                    db.end(); 
                }
            });
        });

    } catch (error) {
        console.error('❌ Waduh, gagal narik data dari OSM:', error.message);
        db.end();
    }
}

seedJogjaCafes();
