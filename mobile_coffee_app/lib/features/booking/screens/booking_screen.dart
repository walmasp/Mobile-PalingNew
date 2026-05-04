import 'package:flutter/material.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final _formKey = GlobalKey<FormState>();

  int? jumlahOrang;
  String? mejaTerpilih;

  List<String> mejaAvailable = [
    'Meja 01 (Kapasitas 4)',
    'Meja 02 (Kapasitas 6)',
    'Meja 05 (Kapasitas 15)',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50], 
      appBar: AppBar(
        title: const Text(
          'Booking Meja',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.grey[50],
        foregroundColor: Colors.brown[800],
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Silakan isi detail reservasi:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 25),

                // INPUT JUMLAH ORANG
                TextFormField(
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Jumlah Orang',
                    hintText: 'Maksimal 15 orang',
                    prefixIcon: const Icon(Icons.people, color: Colors.brown),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(color: Colors.grey[200]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: const BorderSide(
                        color: Colors.brown,
                        width: 1.5,
                      ),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: const BorderSide(color: Colors.redAccent),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Jumlah orang wajib diisi!';
                    }
                    int? val = int.tryParse(value);
                    if (val == null || val <= 0) {
                      return 'Masukkan angka yang valid!';
                    }
                    if (val > 15) return 'Maksimal 15 orang untuk 1 reservasi.';
                    return null;
                  },
                  onChanged: (value) {
                    setState(() {
                      jumlahOrang = int.tryParse(value);
                      mejaTerpilih = null;
                    });
                  },
                ),

                const SizedBox(height: 25),

                // DROPDOWN PILIH MEJA 
                DropdownButtonFormField<String>(
                  initialValue: mejaTerpilih,
                  decoration: InputDecoration(
                    labelText: 'Pilih Meja',
                    prefixIcon: const Icon(
                      Icons.table_restaurant,
                      color: Colors.brown,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(color: Colors.grey[200]!),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: const BorderSide(color: Colors.redAccent),
                    ),
                  ),
                  icon: const Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.brown,
                  ),
                  hint: const Text('Pilih Meja Tersedia'),
                  items:
                      jumlahOrang != null &&
                          jumlahOrang! > 0 &&
                          jumlahOrang! <= 15
                      ? mejaAvailable.map((String meja) {
                          return DropdownMenuItem<String>(
                            value: meja,
                            child: Text(
                              meja,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }).toList()
                      : null, 
                  onChanged: (String? newValue) {
                    setState(() {
                      mejaTerpilih = newValue;
                    });
                  },
                  validator: (value) => value == null
                      ? 'Silakan pilih meja terlebih dahulu!'
                      : null,
                ),

                // KOTAK NOTES UNTUK ROMBONGAN > 6 ORANG
                Container(
                  margin: const EdgeInsets.only(
                    top: 25,
                  ),
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors
                        .orange[50], 
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, color: Colors.orange),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Catatan Reservasi: Kapasitas per meja maksimal 6 orang. Jika rombongan Anda lebih dari 6 orang, silakan pilih meja mana saja yang tersedia. Jangan khawatir, pelayan kami akan menggabungkan meja Anda saat tiba di lokasi.",
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.brown[800],
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),

      // TOMBOL LANJUT 
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.brown[700],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 0,
              ),
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Meja $mejaTerpilih berhasil dibooking untuk $jumlahOrang orang!',
                      ),
                      backgroundColor: Colors.brown,
                    ),
                  );
                }
              },
              child: const Text(
                'Lanjut Pilih Menu',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
