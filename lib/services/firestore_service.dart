import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 1. Save User
  Future<void> saveUser({required String uid, required String email, required String role, required String name, String? image}) async {
    try {
      await _db.collection('users').doc(uid).set({
        'uid': uid,
        'email': email,
        'name': name,
        'role': role,
        'profile_image': image ?? "",
        'created_at': FieldValue.serverTimestamp(),
        'fcm_token': "", 
      });
    } catch (e) {
      print("Error saving user: $e");
    }
  }

  // 2. Get User
  Future<Map<String, dynamic>?> getUser(String uid) async {
    try {
      DocumentSnapshot doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print("Error getting user: $e");
      return null;
    }
  }

  // --- 3. YE WALA FUNCTION MISSING THA (ISAY ADD KAREIN) ---
  Future<void> updateFCMToken(String uid, String token) async {
    try {
      await _db.collection('users').doc(uid).update({
        'fcm_token': token,
        'last_active': FieldValue.serverTimestamp(),
      });
      print("FCM Token Updated in Database: $token");
    } catch (e) {
      print("Error updating token: $e");
    }
  }
}