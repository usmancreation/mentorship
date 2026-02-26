import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class TokenService {
  // Update with your actual domain path
  static const String _apiUrl = 'https://techrisepk.com/mentor/mentorauth/update_fcm_token.php';

  static Future<void> updateTokenToServer() async {
    try {
      // 1. Firebase se naya Token lein
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      String? token = await messaging.getToken();

      if (token == null) return;

      // 2. Local Storage se User ID aur Role nikalein
      SharedPreferences prefs = await SharedPreferences.getInstance();
      
      bool isMentor = prefs.getBool('isMentorLoggedIn') ?? false;
      String role = isMentor ? 'mentor' : 'student';
      
      // ID fetch karein based on role
      String? uid = isMentor 
          ? prefs.getString('mentorId') 
          : prefs.getString('userId');

      if (uid == null) return; // Agar banda login nahi hai to return

      print("Updating Token for $role ($uid): $token");

      // 3. PHP API ko hit karein
      var response = await http.post(
        Uri.parse(_apiUrl),
        body: {
          'uid': uid,
          'token': token,
          'role': role,
        },
      );

      if (response.statusCode == 200) {
        print("Token Updated Successfully: ${response.body}");
      } else {
        print("Token Update Failed: ${response.statusCode}");
      }

    } catch (e) {
      print("Token Service Error: $e");
    }
  }
}