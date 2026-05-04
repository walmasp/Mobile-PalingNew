const express = require('express');
const cors = require('cors');
require('dotenv').config();

// Panggil file koneksi database tadi
const db = require('./config/database');

const app = express();
app.use(cors());
app.use(express.json()); // Biar bisa menerima data JSON dari Flutter

const path = require('path');
// Buka akses folder uploads agar bisa diakses publik
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

const authRoutes = require('./routes/authRoutes');
app.use('/api/auth', authRoutes);

const menuRoutes = require('./routes/menuRoutes');
app.use('/api/menus', menuRoutes);

const tableRoutes = require('./routes/tableRoutes');
app.use('/api/tables', tableRoutes);

const bookingRoutes = require('./routes/bookingRoutes');
app.use('/api/bookings', bookingRoutes);

const cafeRoutes = require('./routes/cafeRoutes');
app.use('/api/cafes', cafeRoutes);

app.get('/', (req, res) => {
    res.send('Halo! Server API Coffee Shop sudah jalan!');
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`Server nyala di http://localhost:${PORT}`);
});
