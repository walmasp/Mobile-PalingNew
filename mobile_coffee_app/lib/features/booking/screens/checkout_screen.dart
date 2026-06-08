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

  // ─── Design Tokens ──────────────────────────────────────
  static const _brown900 = Color(0xFF3E2723);
  static const _brown700 = Color(0xFF5D4037);
  static const _brown400 = Color(0xFF8D6E63);
  static const _cream = Color(0xFFFAF7F4);
  static const _cardBg = Color(0xFFFFFFFF);
  static const _inputBorder = Color(0xFFEEE8E4);
  static const _textHint = Color(0xFFBCAAA4);
  // ────────────────────────────────────────────────────────

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
      int decimalPlaces =
          (widget.currency == 'JPY' || widget.currency == 'KRW') ? 0 : 2;
      return "${widget.currency} ${converted.toStringAsFixed(decimalPlaces)}";
    }
  }

  int get subtotal => widget.items.fold(
        0,
        (sum, item) =>
            sum + ((item['harga'] as int) * (item['jumlah'] as int)),
      );

  int get tax => (subtotal * 0.11).round();
  int get totalAmount => subtotal + tax;

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

    return "${witaHour.toString().padLeft(2, '0')}:$minStr WITA  ·  "
        "${witHour.toString().padLeft(2, '0')}:$minStr WIT  ·  "
        "${londonHour.toString().padLeft(2, '0')}:$minStr London";
  }

  Future<void> handleCheckout() async {
    if (selectedPeopleCount == null ||
        selectedTableId == null ||
        selectedDate == null ||
        startTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Mohon lengkapi semua data reservasi!"),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
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

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          bool isPaid = false;
          Timer? pollingTimer;

          return StatefulBuilder(
            builder: (context, setStateDialog) {
              pollingTimer ??= Timer.periodic(const Duration(seconds: 3),
                  (timer) async {
                String status =
                    await BookingService.checkStatus(result['booking_id']);
                String statusAman = status.toLowerCase();
                print("STATUS POLLING: $statusAman");

                if (statusAman == 'confirmed' || statusAman == 'selesai') {
                  timer.cancel();

                  await NotificationHelper.showNotification(
                    "Pembayaran Berhasil! 🎉",
                    "Booking kamu telah dikonfirmasi. Sampai jumpa di lokasi!",
                  );

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
                          builder: (context) => const MainNavigationScreen()),
                      (route) => false,
                    );
                  });
                }
              });

              return Dialog(
                backgroundColor: _cardBg,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28)),
                insetPadding: const EdgeInsets.symmetric(horizontal: 32),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isPaid) ...[
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check_rounded,
                              color: Colors.green, size: 40),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          "Pembayaran Berhasil!",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: _brown900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Pesanan Anda sedang diproses.",
                          style: TextStyle(color: _brown400, fontSize: 14),
                        ),
                      ] else ...[
                        const Text(
                          "Selesaikan Pembayaran",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: _brown900,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              vertical: 16, horizontal: 20),
                          decoration: BoxDecoration(
                            color: _cream,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: _inputBorder, width: 1.5),
                          ),
                          child: Column(
                            children: [
                              Text(
                                "Total Tagihan",
                                style: TextStyle(
                                    color: _brown400, fontSize: 13),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                formatPrice(result['tagihan_sekarang'] ??
                                    result['total_harga'] ??
                                    0),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 26,
                                  color: _brown900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _cream,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: _inputBorder, width: 1.5),
                          ),
                          child: const Icon(Icons.qr_code_2_rounded,
                              size: 140, color: _brown900),
                        ),
                        const SizedBox(height: 20),
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: _brown700,
                            strokeWidth: 2.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "Menunggu konfirmasi pembayaran...",
                          style:
                              TextStyle(color: _textHint, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
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
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        title: const Text(
          "Checkout",
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: _brown900,
            fontSize: 18,
          ),
        ),
        backgroundColor: _cream,
        foregroundColor: _brown900,
        elevation: 0,
        centerTitle: true,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _inputBorder, width: 1.5),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 15, color: _brown900),
          ),
        ),
      ),
      body: isLoadingTables
          ? const Center(
              child: CircularProgressIndicator(color: _brown700))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Order Summary ──────────────────────────
                  _buildSectionTitle("Ringkasan Pesanan"),
                  const SizedBox(height: 12),
                  _buildOrderSummaryCard(),
                  const SizedBox(height: 24),

                  // ── Jumlah Orang ───────────────────────────
                  _buildSectionTitle("Jumlah Tamu"),
                  const SizedBox(height: 12),
                  _buildPeoplePicker(),
                  const SizedBox(height: 24),

                  // ── Pilih Meja ─────────────────────────────
                  _buildSectionTitle("Pilih Meja"),
                  const SizedBox(height: 12),
                  _buildTableGrid(),
                  const SizedBox(height: 24),

                  // ── Jadwal ─────────────────────────────────
                  _buildSectionTitle("Jadwal Kedatangan"),
                  const SizedBox(height: 12),
                  _buildSchedulePicker(),
                  const SizedBox(height: 24),

                  // ── Pembayaran ─────────────────────────────
                  _buildSectionTitle("Metode Pembayaran"),
                  const SizedBox(height: 12),
                  _buildPaymentOptions(),
                ],
              ),
            ),

      // ── Bottom Bar ─────────────────────────────────────────
      bottomNavigationBar: isLoadingTables
          ? null
          : _buildBottomBar(),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: _brown900,
      ),
    );
  }

  Widget _buildOrderSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _inputBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: _brown900.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Item list
          ...widget.items.map((item) {
            int lineTotal = (item['harga'] as int) * (item['jumlah'] as int);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: _cream,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${item['jumlah']}x',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _brown700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item['nama_menu'],
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _brown900,
                      ),
                    ),
                  ),
                  Text(
                    formatPrice(lineTotal),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _brown700,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),

          Divider(color: _inputBorder, height: 24, thickness: 1),

          // Subtotal row
          _buildPriceRow("Subtotal", formatPrice(subtotal)),
          const SizedBox(height: 8),
          _buildPriceRow("PPN 11%", formatPrice(tax),
              isSecondary: true),
          const SizedBox(height: 12),
          Divider(color: _inputBorder, height: 1, thickness: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Total",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _brown900,
                ),
              ),
              Text(
                formatPrice(
                  selectedPayment == 'dp_50'
                      ? (totalAmount * 0.5).round()
                      : totalAmount,
                ),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _brown700,
                ),
              ),
            ],
          ),
          if (selectedPayment == 'dp_50') ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                "Sisa ${formatPrice((totalAmount * 0.5).round())} dibayar di lokasi",
                style: TextStyle(color: _brown400, fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, String value,
      {bool isSecondary = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isSecondary ? _brown400 : _brown900,
            fontWeight: isSecondary ? FontWeight.normal : FontWeight.w600,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            color: isSecondary ? _brown400 : _brown900,
            fontWeight: isSecondary ? FontWeight.normal : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildPeoplePicker() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _inputBorder, width: 1.5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: _brown700),
          hint: Text(
            "Pilih jumlah tamu",
            style: TextStyle(color: _textHint, fontSize: 14),
          ),
          value: selectedPeopleCount,
          style: const TextStyle(
              fontWeight: FontWeight.w600, color: _brown900, fontSize: 14),
          dropdownColor: _cardBg,
          items: List.generate(10, (index) => index + 1)
              .map((val) => DropdownMenuItem(
                    value: val,
                    child: Text("$val Orang"),
                  ))
              .toList(),
          onChanged: (val) => setState(() {
            selectedPeopleCount = val;
            selectedTableId = null;
          }),
        ),
      ),
    );
  }

  Widget _buildTableGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tables.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.92,
      ),
      itemBuilder: (context, index) {
        final table = tables[index];
        final isSelected = selectedTableId == table['id'];
        final kapasitas = table['kapasitas'] ?? 4;

        return GestureDetector(
          onTap: () => setState(() => selectedTableId = table['id']),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding:
                const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
            decoration: BoxDecoration(
              color: isSelected ? _brown900 : _cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? _brown900 : _inputBorder,
                width: 1.5,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: _brown900.withOpacity(0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      )
                    ]
                  : [],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chair_alt_rounded,
                  color: isSelected ? Colors.white : _brown400,
                  size: 26,
                ),
                const SizedBox(height: 8),
                Text(
                  "Meja ${table['nomor_meja']}",
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: isSelected ? Colors.white : _brown900,
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
                      Icons.people_alt_rounded,
                      color: isSelected
                          ? Colors.white.withOpacity(0.7)
                          : _brown400,
                      size: 13,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      "$kapasitas",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? Colors.white.withOpacity(0.9)
                            : _brown400,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSchedulePicker() {
    return Column(
      children: [
        Row(
          children: [
            // Date button
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  final p = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2030),
                    builder: (context, child) => Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: const ColorScheme.light(
                            primary: _brown700),
                      ),
                      child: child!,
                    ),
                  );
                  if (p != null) setState(() => selectedDate = p);
                },
                child: _buildPickerTile(
                  icon: Icons.calendar_month_rounded,
                  text: selectedDate == null
                      ? "Pilih Tanggal"
                      : selectedDate!.toString().split(' ')[0],
                  hasValue: selectedDate != null,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Time button
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  final p = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                    builder: (context, child) => Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: const ColorScheme.light(
                            primary: _brown700),
                      ),
                      child: child!,
                    ),
                  );
                  if (p != null) setState(() => startTime = p);
                },
                child: _buildPickerTile(
                  icon: Icons.access_time_rounded,
                  text: startTime == null
                      ? "Pilih Waktu"
                      : startTime!.format(context),
                  hasValue: startTime != null,
                ),
              ),
            ),
          ],
        ),
        if (startTime != null) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: _cream,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _inputBorder, width: 1.5),
            ),
            child: Row(
              children: [
                const Icon(Icons.public_rounded,
                    size: 16, color: _brown400),
                const SizedBox(width: 8),
                Text(
                  getConvertedTimes(),
                  style:
                      const TextStyle(color: _brown400, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPickerTile({
    required IconData icon,
    required String text,
    required bool hasValue,
  }) {
    return Container(
      padding:
          const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
      decoration: BoxDecoration(
        color: hasValue ? _brown900 : _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasValue ? _brown900 : _inputBorder,
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon,
              color: hasValue ? Colors.white : _brown400, size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: hasValue ? Colors.white : _textHint,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOptions() {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _inputBorder, width: 1),
      ),
      child: Column(
        children: [
          _buildPaymentTile(
            value: 'lunas',
            title: 'Bayar Lunas',
            subtitle: 'Bayar penuh sekarang',
            icon: Icons.payments_outlined,
          ),
          Divider(height: 1, color: _inputBorder),
          _buildPaymentTile(
            value: 'dp_50',
            title: 'DP 50%',
            subtitle: 'Bayar setengah, sisanya di lokasi',
            icon: Icons.account_balance_wallet_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentTile({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = selectedPayment == value;
    return InkWell(
      onTap: () => setState(() => selectedPayment = value),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isSelected ? _brown900 : _cream,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon,
                  color: isSelected ? Colors.white : _brown400,
                  size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: isSelected ? _brown900 : _brown900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style:
                        const TextStyle(color: _brown400, fontSize: 12),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? _brown900 : Colors.transparent,
                border: Border.all(
                  color: isSelected ? _brown900 : _inputBorder,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded,
                      size: 13, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: _brown900.withOpacity(0.07),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Price summary row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Total Pembayaran",
                      style:
                          TextStyle(fontSize: 12, color: _brown400),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatPrice(selectedPayment == 'dp_50'
                          ? (totalAmount * 0.5).round()
                          : totalAmount),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: _brown900,
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  width: 170,
                  height: 52,
                  child: isLoading
                      ? Container(
                          decoration: BoxDecoration(
                            color: _brown400,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            ),
                          ),
                        )
                      : ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _brown900,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          onPressed: handleCheckout,
                          child: const Text(
                            "Konfirmasi",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}