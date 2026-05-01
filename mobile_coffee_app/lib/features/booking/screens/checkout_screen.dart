import 'package:flutter/material.dart';
import 'package:mobile_coffee_app/shared/layout/main_navigation_screen.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/services/booking_service.dart';
import '../../../data/services/table_service.dart';
import '../../../data/services/notification_service.dart';
import '../../../core/utils/notification_helper.dart';

class CheckoutScreen extends StatefulWidget {
  final int cafeId;
  final List<Map<String, dynamic>> items;
  final String currency;
  final double rate;

  const CheckoutScreen({
    super.key,
    required this.cafeId,
    required this.items,
    this.currency = 'IDR',
    this.rate = 1.0,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  bool isLoading = false;
  List tables = [];
  bool isLoadingTables = true;

  int? selectedPeopleCount;
  int? selectedTableId;
  DateTime? selectedDate;
  TimeOfDay? startTime;

  String selectedPayment = 'lunas';

  @override
  void initState() {
    super.initState();
    fetchTables();
  }

  // --- LOGIKA DATA (TIDAK DIUBAH) ---
  String formatPrice(dynamic originalPrice) {
    double price = double.parse(originalPrice.toString());
    if (widget.currency == 'IDR') {
      return "Rp ${price.toInt()}";
    } else {
      double converted = price * widget.rate;
      int decimalPlaces = (widget.currency == 'JPY' || widget.currency == 'KRW')
          ? 0
          : 2;
      return "${widget.currency} ${converted.toStringAsFixed(decimalPlaces)}";
    }
  }

  Future<void> fetchTables() async {
    try {
      final data = await TableService.getTables(widget.cafeId);
      setState(() {
        tables = data;
        isLoadingTables = false;
      });
    } catch (e) {
      setState(() => isLoadingTables = false);
    }
  }

  String getConvertedTimes() {
    if (startTime == null) return "";
    int wibHour = startTime!.hour;
    int minute = startTime!.minute;
    String minStr = minute.toString().padLeft(2, '0');
    int witaHour = (wibHour + 1) % 24;
    int witHour = (wibHour + 2) % 24;
    int londonHour = (wibHour - 7) % 24;
    if (londonHour < 0) londonHour += 24;

    return "Waktu ini setara dengan:\n"
        "${witaHour.toString().padLeft(2, '0')}:$minStr WITA  |  "
        "${witHour.toString().padLeft(2, '0')}:$minStr WIT  |  "
        "${londonHour.toString().padLeft(2, '0')}:$minStr London";
  }

  Future<void> handleCheckout() async {
    if (selectedPeopleCount == null ||
        selectedTableId == null ||
        selectedDate == null ||
        startTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Mohon lengkapi semua data reservasi!"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      String formattedDate = selectedDate!.toString().split(' ')[0];
      String formattedStartTime =
          '${startTime!.hour.toString().padLeft(2, '0')}:${startTime!.minute.toString().padLeft(2, '0')}:00';
      int endHour = (startTime!.hour + 2) % 24;
      String formattedEndTime =
          '${endHour.toString().padLeft(2, '0')}:${startTime!.minute.toString().padLeft(2, '0')}:00';

      final result = await BookingService.createBooking(
        cafeId: widget.cafeId,
        tableId: selectedTableId!,
        jumlahOrang: selectedPeopleCount!,
        items: widget.items,
        tanggal: formattedDate,
        jamMulai: formattedStartTime,
        jamSelesai: formattedEndTime,
        jenisPembayaran: selectedPayment,
      );

      if (!mounted) return;

      // DIALOG PEMBAYARAN DIPERBARUI JADI LEBIH MODERN
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          bool isPaid = false;
          Timer? pollingTimer;

          return StatefulBuilder(
            builder: (context, setStateDialog) {
              pollingTimer ??= Timer.periodic(const Duration(seconds: 3), (timer) async {
                String status = await BookingService.checkStatus(
                  result['booking_id'],
                );

                // 1. Jadikan huruf kecil semua biar kebal dari salah ketik/kapital
                String statusAman = status.toLowerCase();
                print("STATUS POLLING: $statusAman"); // Buat cek di terminal

                if (statusAman == 'confirmed' || statusAman == 'selesai') {
                  timer.cancel();

                  // 2. 🔥 INI FUNGSI UNTUK MUNCULIN NOTIF POP-UP DI HP KAMU
                  await NotificationHelper.showNotification(
                    "Pembayaran Berhasil! 🎉",
                    "Booking kamu telah dikonfirmasi. Sampai jumpa di lokasi!",
                  );

                  // 3. Menyimpan riwayat ke database untuk Activity Screen
                  try {
                    await NotificationService.createNotification(
                      "Pembayaran Berhasil! 🎉",
                      "Booking kamu telah dikonfirmasi. Sampai jumpa di lokasi!",
                    );
                  } catch (e) {
                    print("Gagal simpan ke DB: $e");
                  }

                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove('cart_cafe_${widget.cafeId}');
                  
                  if (mounted) {
                    setStateDialog(() => isPaid = true);
                  }

                  Future.delayed(const Duration(seconds: 2), () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MainNavigationScreen(),
                      ),
                      (route) => false,
                    );
                  });
                }
              });

              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                backgroundColor: Colors.white,
                contentPadding: const EdgeInsets.all(30),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isPaid) ...[
                      const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 80,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        "Payment Successful!",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Pesanan Anda sedang diproses.",
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ] else ...[
                      const Text(
                        "Selesaikan Pembayaran",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 15),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 15,
                          horizontal: 20,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.brown[50],
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              "Tagihan Anda",
                              style: TextStyle(color: Colors.brown),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              formatPrice(
                                result['tagihan_sekarang'] ??
                                    result['total_harga'] ??
                                    0,
                              ),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 24,
                                color: Colors.brown,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 25),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.qr_code_2,
                          size: 150,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 25),
                      const CircularProgressIndicator(color: Colors.brown),
                      const SizedBox(height: 15),
                      Text(
                        "Menunggu pembayaran...",
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Gagal booking: $e"),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // --- UI BARU (CAFFIO APP STYLE) ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          "Checkout",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.grey[50],
        foregroundColor: Colors.brown[800],
        elevation: 0,
        centerTitle: true,
      ),
      body: isLoadingTables
          ? const Center(child: CircularProgressIndicator(color: Colors.brown))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- JUMLAH ORANG ---
                  const Text(
                    "Jumlah Orang",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.grey[200]!),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        isExpanded: true,
                        icon: const Icon(
                          Icons.keyboard_arrow_down,
                          color: Colors.brown,
                        ),
                        hint: Text(
                          "Pilih jumlah orang",
                          style: TextStyle(color: Colors.grey[400]),
                        ),
                        value: selectedPeopleCount,
                        items: List.generate(10, (index) => index + 1)
                            .map(
                              (val) => DropdownMenuItem(
                                value: val,
                                child: Text(
                                  "$val Orang",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (val) => setState(() {
                          selectedPeopleCount = val;
                          selectedTableId = null;
                        }),
                      ),
                    ),
                  ),
                  const SizedBox(height: 25),

                  // --- PILIH MEJA (Revisi Desain Ikon) ---
                  const Text(
                    "Pilih Nomor Meja Utama",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: tables.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio:
                              0.9, // Diubah agar muat ikon dan teks
                        ),
                    itemBuilder: (context, index) {
                      final table = tables[index];
                      final isSelected = selectedTableId == table['id'];
                      final kapasitas =
                          table['kapasitas'] ??
                          4; // Default 4 jika API tidak punya field ini

                      return GestureDetector(
                        onTap: () =>
                            setState(() => selectedTableId = table['id']),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 5,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.brown[600]
                                : Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.brown[600]!
                                  : Colors.grey[300]!,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: Colors.brown.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : [],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.chair_alt,
                                color: isSelected
                                    ? Colors.white
                                    : Colors.black87,
                                size: 28,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Meja ${table['nomor_meja']}",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.grey[700],
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.people,
                                    color: isSelected
                                        ? Colors.blue[200]
                                        : Colors.blue,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    "$kapasitas",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 25),

                  // --- TANGGAL & JAM ---
                  const Text(
                    "Jadwal Kedatangan",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      // Tombol Pilih Tanggal
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            final p = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate: DateTime(2030),
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: const ColorScheme.light(
                                      primary: Colors.brown,
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (p != null) setState(() => selectedDate = p);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 15,
                              horizontal: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.calendar_month,
                                  color: Colors.brown,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  selectedDate == null
                                      ? "Tanggal"
                                      : selectedDate.toString().split(' ')[0],
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: selectedDate == null
                                        ? Colors.grey[500]
                                        : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      // Tombol Pilih Jam
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            final p = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.now(),
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: const ColorScheme.light(
                                      primary: Colors.brown,
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (p != null) setState(() => startTime = p);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 15,
                              horizontal: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.access_time_filled,
                                  color: Colors.brown,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  startTime == null
                                      ? "Waktu"
                                      : startTime!.format(context),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: startTime == null
                                        ? Colors.grey[500]
                                        : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (startTime != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10.0),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey[50],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          getConvertedTimes(),
                          style: TextStyle(
                            color: Colors.blueGrey[700],
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 25),

                  // --- JENIS PEMBAYARAN ---
                  const Text(
                    "Pilih Pembayaran",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      children: [
                        RadioListTile(
                          activeColor: Colors.brown,
                          title: const Text(
                            "Lunas",
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            "Bayar penuh sekarang",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                          value: 'lunas',
                          groupValue: selectedPayment,
                          onChanged: (v) =>
                              setState(() => selectedPayment = v!),
                        ),
                        Divider(height: 1, color: Colors.grey[200]),
                        RadioListTile(
                          activeColor: Colors.brown,
                          title: const Text(
                            "DP 50%",
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            "Bayar setengah, sisanya di lokasi",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                          value: 'dp_50',
                          groupValue: selectedPayment,
                          onChanged: (v) =>
                              setState(() => selectedPayment = v!),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),

      // --- BOTTOM NAVIGATION BAR UNTUK TOMBOL KONFIRMASI ---
      bottomNavigationBar: isLoadingTables
          ? null
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
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
                  child: isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: Colors.brown),
                        )
                      : ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.brown[700],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            elevation: 0,
                          ),
                          onPressed: handleCheckout,
                          child: const Text(
                            'Konfirmasi Booking',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                ),
              ),
            ),
    );
  }
}