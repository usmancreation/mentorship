import 'dart:convert';
import 'package:http/http.dart' as http;

class NotificationService {
  // --- [OLD] EXISTING DOMAIN (Do Not Change) ---
  static const String _baseUrl = 'https://techrisepk.com/mentor/mentorauth';
  
  // --- [NEW] DATABASE API URL (Added) ---
  static const String _dbUrl = 'https://techrisepk.com/mentor/notifications';

  static Future<void> sendNotification({
    required String senderRole, // 'student' or 'mentor'
    required String roomId,     // Usually the Mentor's ID
    required String title,
    required String body, required String type,
  }) async {
    try {
      // ---------------------------------------------------------
      // 1. PURANA LOGIC: Push Notification (Bina chhere wesa hi raha)
      // ---------------------------------------------------------
      final uri = Uri.parse('$_baseUrl/send_notification.php');
      
      final response = await http.post(
        uri,
        body: {
          'sender_role': senderRole,
          'room_id': roomId,
          'title': title,
          'body': body,
        },
      );

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        print("Push Notification Response: ${data.toString()}");
      } else {
        print("Push Notification Server Error: ${response.statusCode}");
      }

      // ---------------------------------------------------------
      // 2. NAYA LOGIC: Save to Database (List ke liye add kiya)
      // ---------------------------------------------------------
      try {
        final dbUri = Uri.parse('$_dbUrl/send_notification.php');
        
        await http.post(
          dbUri,
          body: {
            'user_id': roomId,       // Isko receiver ki tarah use kar rahe hain
            'sender_role': senderRole,
            'title': title,
            'message': body,         // Note: PHP mein parameter 'message' hai, 'body' nahi
            'type': 'chat',          // Type fix kar di kyunki ye chat notification hai
          },
        );
        print("Notification Saved to Database Successfully");
      } catch (dbError) {
        print("Database Save Error: $dbError");
      }
    } catch (e) {
      print("Notification Exception: $e");
    }
  }
}