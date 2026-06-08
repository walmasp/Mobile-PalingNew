import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../data/services/booking_service.dart';

class BookingDetailScreen extends StatefulWidget {
  final int bookingId;

  const BookingDetailScreen({super.key, required this.bookingId});

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  Map<String, dynamic>? bookingData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    setState(() => isLoading = true);
    try {
      final data = await BookingService.getBookingDetails(widget.bookingId);
      setState(() {
        bookingData = data;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // --- STATUS HELPERS ---
  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return Colors.green;
      case 'menunggu_pembayaran':
        return Colors.orange;
      case 'selesai':
        return Colors.blue;
      case 'dibatalkan':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return 'Dikonfirmasi';
      case 'menunggu_pembayaran':
        return 'Menunggu Pembayaran';
      case 'selesai':
        return 'Selesai';
      case 'dibatalkan':
        return 'Dibatalkan';
      default:
        return status.toUpperCase();
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return Icons.check_circle_rounded;
      case 'menunggu_pembayaran':
        return Icons.hourglass_top_rounded;
      case 'selesai':
        return Icons.task_alt_rounded;
      case 'dibatalkan':
        return Icons.cancel_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw);
      const months = [
        '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
        'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
      ];
      const days = ['', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
      return "${days[dt.weekday]}, ${dt.day} ${months[dt.month]} ${dt.year}";
    } catch (_) {
      return raw.split('T')[0];
    }
  }

  String _formatRupiah(dynamic value) {
    if (value == null) return '0';
    final num amount = value is num ? value : num.tryParse(value.toString()) ?? 0;
    final str = amount.toStringAsFixed(0);
    final buffer = StringBuffer();
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) buffer.write('.');
      buffer.write(str[i]);
      count++;
    }
    return buffer.toString().split('').reversed.join('');
  }

  String _formatTime(String? time) {
    if (time == null) return '-';
    // Format HH:MM:SS → HH:MM
    return time.length >= 5 ? time.substring(0, 5) : time;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          "E-Ticket Caffio",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFF5F5F5),
        foregroundColor: Colors.brown[800],
        elevation: 0,
        centerTitle: true,
        actions: [
          if (bookingData != null)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _fetchDetails,
              tooltip: "Refresh",
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.brown))
          : bookingData == null
          ? _buildError()
          : _buildContent(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text("Data tidak ditemukan", style: TextStyle(color: Colors.grey[500])),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: _fetchDetails,
            icon: const Icon(Icons.refresh),
            label: const Text("Coba lagi"),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final data = bookingData!;
    final status = data['status']?.toString() ?? '';
    final statusColor = _statusColor(status);
    final statusLabel = _statusLabel(status);
    final statusIcon = _statusIcon(status);
    final items = (data['items'] as List?) ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
      child: Column(
        children: [
          // ── KARTU TIKET UTAMA ──────────────────────────────────
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.brown[800]!, Colors.brown[600]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.brown.withOpacity(0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                  child: Column(
                    children: [
                      // Icon QR
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.qr_code_2_rounded,
                          size: 56,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Nama Cafe
                      Text(
                        data['nama_cafe'] ?? 'Caffio Coffee',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      // Area
                      if (data['area'] != null)
                        Text(
                          data['area'],
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                      const SizedBox(height: 16),
                      // Status Badge (lebih menonjol)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: statusColor.withOpacity(0.5),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon, color: statusColor, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              statusLabel,
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Garis pemisah bergerigi (tiket style)
                _buildTicketDivider(),
                // Booking ID di bawah divider
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 14, 24, 20),
                  child: GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(
                        text: '#${data['id'].toString().padLeft(6, '0')}',
                      ));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Booking ID disalin!"),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "ID: #${data['id'].toString().padLeft(6, '0')}",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 12,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.copy_rounded,
                          size: 13,
                          color: Colors.white.withOpacity(0.4),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── TIMELINE STATUS ─────────────────────────────────────
          _buildStatusTimeline(status),

          const SizedBox(height: 20),

          // ── DETAIL RESERVASI ────────────────────────────────────
          _buildSection(
            title: "Detail Reservasi",
            icon: Icons.event_note_rounded,
            children: [
              _buildInfoRow(
                Icons.calendar_today_outlined,
                "Tanggal",
                _formatDate(data['tanggal_booking'].toString()),
              ),
              const SizedBox(height: 14),
              _buildInfoRow(
                Icons.access_time_outlined,
                "Waktu",
                "${_formatTime(data['jam_mulai'])} – ${_formatTime(data['jam_selesai'])}",
              ),
              const SizedBox(height: 14),
              _buildInfoRow(
                Icons.chair_alt_outlined,
                "Meja",
                "Meja ${data['nomor_meja']} • ${data['area'] ?? 'Area Umum'}",
              ),
              const SizedBox(height: 14),
              _buildInfoRow(
                Icons.people_outline,
                "Jumlah Tamu",
                "${data['jumlah_orang'] ?? 1} Orang",
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── DAFTAR PESANAN ──────────────────────────────────────
          if (items.isNotEmpty)
            _buildSection(
              title: "Pesanan Kamu",
              icon: Icons.local_cafe_outlined,
              children: [
                ...items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.brown[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            "${item['jumlah']}x",
                            style: TextStyle(
                              color: Colors.brown[700],
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item['nama_menu'] ?? '-',
                          style: TextStyle(color: Colors.grey[800], fontSize: 14),
                        ),
                      ),
                      Text(
                        "Rp ${_formatRupiah(item['harga_satuan'])}",
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Total Tagihan",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      "Rp ${_formatRupiah(data['total_harga'])}",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.brown[700],
                      ),
                    ),
                  ],
                ),
              ],
            ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ── WIDGET HELPERS ──────────────────────────────────────────────

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.brown[600], size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.brown[300], size: 18),
        const SizedBox(width: 12),
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: Colors.black87,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusTimeline(String currentStatus) {
    final steps = [
      {'key': 'menunggu_pembayaran', 'label': 'Menunggu'},
      {'key': 'confirmed', 'label': 'Dikonfirmasi'},
      {'key': 'selesai', 'label': 'Selesai'},
    ];

    // Jika dibatalkan, tampilkan pesan berbeda
    if (currentStatus.toLowerCase() == 'dibatalkan') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.cancel_rounded, color: Colors.red[400], size: 22),
            const SizedBox(width: 10),
            Text(
              "Booking ini telah dibatalkan",
              style: TextStyle(
                color: Colors.red[700],
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    final stepOrder = ['menunggu_pembayaran', 'confirmed', 'selesai'];
    final currentIndex = stepOrder.indexOf(currentStatus.toLowerCase());

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (i) {
          if (i.isOdd) {
            // Garis penghubung
            final stepIndex = i ~/ 2;
            final isDone = stepIndex < currentIndex;
            return Expanded(
              child: Container(
                height: 2,
                color: isDone ? Colors.brown[400] : Colors.grey[200],
              ),
            );
          } else {
            final stepIndex = i ~/ 2;
            final isDone = stepIndex <= currentIndex;
            final isCurrent = stepIndex == currentIndex;
            final step = steps[stepIndex];
            return Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isDone ? Colors.brown[600] : Colors.grey[200],
                    shape: BoxShape.circle,
                    border: isCurrent
                        ? Border.all(color: Colors.brown[300]!, width: 3)
                        : null,
                  ),
                  child: Icon(
                    isDone ? Icons.check : Icons.circle,
                    size: isDone ? 18 : 8,
                    color: isDone ? Colors.white : Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  step['label']!,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDone ? Colors.brown[700] : Colors.grey[400],
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            );
          }
        }),
      ),
    );
  }

  // Garis bergerigi seperti tiket fisik
  Widget _buildTicketDivider() {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            shape: BoxShape.circle,
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Flex(
                direction: Axis.horizontal,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                  (constraints.constrainWidth() / 10).floor(),
                  (index) => Container(
                    width: 5,
                    height: 1.5,
                    color: Colors.white.withOpacity(0.3),
                  ),
                ),
              );
            },
          ),
        ),
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }
}