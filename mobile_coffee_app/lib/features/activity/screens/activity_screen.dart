import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/config/api_config.dart';
import '../../../core/utils/auth_helper.dart';
import '../../booking/screens/booking_detail_screen.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  List activities = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchActivities();
  }

  // --- LOGIKA API TETAP SAMA ---
  Future<void> fetchActivities() async {
    try {
      final headers = await getAuthHeaders();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/bookings/notifications/me'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          activities = data['data'];
          isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching activities: $e");
      setState(() => isLoading = false);
    }
  }

  // Helper: Tentukan apakah notifikasi ini terkait booking
  bool _isBookingNotification(Map activity) {
    return activity['booking_id'] != null;
  }

  // Helper: Tentukan icon berdasarkan judul notifikasi
  IconData _getActivityIcon(String? judul) {
    if (judul == null) return Icons.notifications_outlined;
    final j = judul.toLowerCase();
    if (j.contains('konfirmasi') || j.contains('berhasil') || j.contains('pembayaran')) {
      return Icons.check_circle_outline;
    } else if (j.contains('selesai') || j.contains('complete')) {
      return Icons.task_alt;
    } else if (j.contains('dibatalkan') || j.contains('cancel')) {
      return Icons.cancel_outlined;
    } else if (j.contains('booking') || j.contains('reservasi')) {
      return Icons.event_seat_outlined;
    } else if (j.contains('juara') || j.contains('game') || j.contains('hadiah')) {
      return Icons.emoji_events_outlined;
    }
    return Icons.pending_actions;
  }

  // Helper: Warna icon berdasarkan judul
  Color _getIconColor(String? judul) {
    if (judul == null) return Colors.brown;
    final j = judul.toLowerCase();
    if (j.contains('berhasil') || j.contains('konfirmasi') || j.contains('selesai')) {
      return Colors.green[700]!;
    } else if (j.contains('dibatalkan') || j.contains('cancel')) {
      return Colors.red[400]!;
    } else if (j.contains('juara') || j.contains('hadiah')) {
      return Colors.amber[700]!;
    }
    return Colors.brown;
  }

  Color _getIconBgColor(String? judul) {
    if (judul == null) return Colors.brown.shade50;
    final j = judul.toLowerCase();
    if (j.contains('berhasil') || j.contains('konfirmasi') || j.contains('selesai')) {
      return Colors.green.shade50;
    } else if (j.contains('dibatalkan') || j.contains('cancel')) {
      return Colors.red.shade50;
    } else if (j.contains('juara') || j.contains('hadiah')) {
      return Colors.amber.shade50;
    }
    return Colors.brown.shade50;
  }

  void _openBookingDetail(int bookingId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookingDetailScreen(bookingId: bookingId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          "My Activity",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.grey[50],
        foregroundColor: Colors.brown[800],
        elevation: 0,
        centerTitle: true,
        actions: [
          if (!isLoading && activities.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.brown[50],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "${activities.length}",
                    style: TextStyle(
                      color: Colors.brown[700],
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.brown))
          : activities.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.pending_actions, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    "Belum ada aktivitas terbaru",
                    style: TextStyle(color: Colors.grey[500], fontSize: 16),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: fetchActivities,
              color: Colors.brown,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                itemCount: activities.length,
                itemBuilder: (context, index) {
                  final activity = activities[index];
                  final bool isBooking = _isBookingNotification(activity);
                  final String? judul = activity['judul'];
                  final iconData = _getActivityIcon(judul);
                  final iconColor = _getIconColor(judul);
                  final iconBgColor = _getIconBgColor(judul);

                  return GestureDetector(
                    // Hanya bisa diklik jika ada booking_id
                    onTap: isBooking
                        ? () => _openBookingDetail(activity['booking_id'])
                        : null,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 15),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: isBooking
                            ? Border.all(color: Colors.brown.shade100, width: 1)
                            : null,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Ikon Activity
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: iconBgColor,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              iconData,
                              color: iconColor,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 14),

                          // Detail Activity
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  judul ?? 'Aktivitas',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  activity['pesan'] ?? '',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                    height: 1.4,
                                  ),
                                ),
                                // Timestamp
                                if (activity['created_at'] != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    _formatDate(activity['created_at']),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[400],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          // Chevron jika bisa diklik ke booking detail
                          if (isBooking)
                            Padding(
                              padding: const EdgeInsets.only(left: 8, top: 4),
                              child: Icon(
                                Icons.chevron_right_rounded,
                                color: Colors.brown[300],
                                size: 22,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  String _formatDate(String rawDate) {
    try {
      final dt = DateTime.parse(rawDate).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inDays == 0) {
        if (diff.inHours == 0) return "${diff.inMinutes} menit lalu";
        return "${diff.inHours} jam lalu";
      } else if (diff.inDays == 1) {
        return "Kemarin";
      } else if (diff.inDays < 7) {
        return "${diff.inDays} hari lalu";
      } else {
        return "${dt.day}/${dt.month}/${dt.year}";
      }
    } catch (_) {
      return '';
    }
  }
}