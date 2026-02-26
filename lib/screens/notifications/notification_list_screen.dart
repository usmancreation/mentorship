import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/app_colors.dart';

class NotificationListScreen extends StatefulWidget {
  const NotificationListScreen({super.key});

  @override
  State<NotificationListScreen> createState() => _NotificationListScreenState();
}

class _NotificationListScreenState extends State<NotificationListScreen> {
  List<dynamic> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    // Check karein user Student hai ya Mentor
    String userId = prefs.getString('userId') ?? prefs.getString('mentorId') ?? "0";

    try {
      // 1. Fetch Data
      var response = await http.post(
        Uri.parse('https://techrisepk.com/mentor/notifications/get_notifications.php'),
        body: {'user_id': userId}
      );

      if (response.statusCode == 200) {
        var json = jsonDecode(response.body);
        if (json['status'] == 'success') {
          setState(() {
            _notifications = json['data'];
            _isLoading = false;
          });
          
          // 2. Mark All as Read (Background mein)
          _markAllAsRead(userId);
        }
      }
    } catch (e) {
      print("Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- Mark Read API ---
  Future<void> _markAllAsRead(String userId) async {
    try {
      await http.post(
        Uri.parse('https://techrisepk.com/mentor/notifications/mark_read.php'),
        body: {'user_id': userId}
      );
      print("All notifications marked as read");
    } catch (e) {
      print("Mark Read Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Notifications", style: TextStyle(color: AppColors.primaryYellow, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primaryBlack,
        iconTheme: const IconThemeData(color: AppColors.primaryYellow),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: AppColors.primaryBlack))
        : _notifications.isEmpty 
           ? _buildEmptyState()
           : ListView.separated(
               itemCount: _notifications.length,
               separatorBuilder: (c, i) => Divider(color: Colors.grey.shade200, height: 1),
               itemBuilder: (context, index) {
                 var item = _notifications[index];
                 bool isUnread = item['is_read'] == 0 || item['is_read'] == '0';
                 
                 return Container(
                   color: isUnread ? AppColors.primaryYellow.withOpacity(0.1) : Colors.white,
                   child: ListTile(
                     leading: CircleAvatar(
                       backgroundColor: AppColors.primaryBlack,
                       child: Icon(
                         _getIconByType(item['type']), 
                         color: AppColors.primaryYellow, 
                         size: 20
                       ),
                     ),
                     title: Text(
                       item['title'], 
                       style: TextStyle(
                         fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                         color: AppColors.primaryBlack
                       )
                     ),
                     subtitle: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         const SizedBox(height: 4),
                         Text(item['message'], maxLines: 2, overflow: TextOverflow.ellipsis),
                         const SizedBox(height: 6),
                         Text(
                           _formatDate(item['created_at']), 
                           style: TextStyle(fontSize: 10, color: Colors.grey.shade500)
                         ),
                       ],
                     ),
                     onTap: () {
                       // Future: Yahan click karke user ko Course/Quiz screen par bhej saktay hain
                     },
                   ),
                 );
               },
             ),
    );
  }

  IconData _getIconByType(String type) {
    switch (type) {
      case 'course': return Icons.video_library;
      case 'quiz': return Icons.quiz;
      case 'reply': return Icons.reply;
      default: return Icons.notifications;
    }
  }

  String _formatDate(String dateString) {
    try {
      DateTime dt = DateTime.parse(dateString);
      return DateFormat('MMM d, h:mm a').format(dt);
    } catch (e) {
      return dateString;
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 15),
          const Text("No Notifications Yet", style: TextStyle(color: Colors.grey, fontSize: 16)),
        ],
      ),
    );
  }
}