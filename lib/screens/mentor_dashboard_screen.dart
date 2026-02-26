import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../utils/app_colors.dart';
import 'login_screen.dart'; 
import 'chat_screen.dart'; 
import 'features/launch_course_screen.dart';
import 'features/mentor_profile_screen.dart'; 
import 'quiz/create_quiz_screen.dart';

// [ADDED] Home Screen import kiya taake logout ke baad wahan ja saken
import 'home_screen.dart'; 

class MentorDashboardScreen extends StatefulWidget {
  const MentorDashboardScreen({super.key});

  @override
  State<MentorDashboardScreen> createState() => _MentorDashboardScreenState();
}

class _MentorDashboardScreenState extends State<MentorDashboardScreen> {
  String mentorName = "Loading...";
  String mentorEmail = "";
  String mentorImage = "";
  String mentorId = "";
  String mentorSkills = ""; 
  String mentorRating = "0.0"; 

  @override
  void initState() {
    super.initState();
    _loadLocalData();
  }

  // 1. Load Local Data (Fast Display)
  Future<void> _loadLocalData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      mentorName = prefs.getString('mentorName') ?? "Mentor";
      mentorEmail = prefs.getString('email') ?? "No Email"; 
      mentorImage = prefs.getString('mentorImage') ?? "";
      mentorId = prefs.getString('mentorId') ?? "";
      // Default values pehle show hongi, phir API update kr degi
      mentorSkills = prefs.getString('mentorSkills') ?? ""; 
    });

    // Local data load honey ke foran baad API call kro
    if (mentorId.isNotEmpty) {
      _fetchDashboardData();
    }
  }

  // 2. Fetch Live Data (Skills & Rating from Database)
  Future<void> _fetchDashboardData() async {
    try {
      var url = Uri.parse("https://techrisepk.com/mentor/mentorauth/get_mentor_dashboard_data.php");
      
      var response = await http.post(url, body: {
        'mentor_id': mentorId,
      });

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        
        if (data['status'] == 'success') {
          setState(() {
            // Database se aayi hui fresh skills
            mentorSkills = data['skills']; 
            
            // Database se calculated rating (mentor_ratings table se)
            mentorRating = data['rating'].toString(); 
          });

          // Local storage ko bhi update kr do future ke liye
          SharedPreferences prefs = await SharedPreferences.getInstance();
          prefs.setString('mentorSkills', mentorSkills);
          prefs.setString('mentorRating', mentorRating);
        }
      }
    } catch (e) {
      print("Error fetching dashboard data: $e");
    }
  }

  // [UPDATED LOGIC] Sirf Mentor ka data remove hoga, Student ka nahi
  Future<void> _logout(BuildContext context) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    
    // Sirf Mentor wali keys remove kr rahe hain
    await prefs.remove('mentorId');
    await prefs.remove('mentorName');
    await prefs.remove('mentorImage');
    await prefs.remove('mentorSkills');
    await prefs.remove('mentorRating');
    
    // Agar 'email' key sirf mentor login ke waqt set hoti hai to isy bhi remove karein
    // Taake next time login required ho
    await prefs.remove('email'); 

    if (!mounted) return;
    
    // Ab user ko Home Screen par bhej rahe hain
    Navigator.pushAndRemoveUntil(
      context, 
      MaterialPageRoute(builder: (c) => const HomeScreen()), 
      (r) => false
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    // Skills List Split Logic
    List<String> skillsList = [];
    if (mentorSkills.isNotEmpty) {
      skillsList = mentorSkills.split(',').map((e) => e.trim()).toList();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- 1. HEADER SECTION ---
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 10,
                    bottom: 80 
                  ),
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryBlack,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(40),
                      bottomRight: Radius.circular(40)
                    ),
                  ),
                  child: Column(
                    children: [
                      // Top Icons
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Icon(Icons.dashboard_rounded, color: AppColors.primaryYellow),
                            IconButton(
                              onPressed: () => _logout(context), 
                              icon: const Icon(Icons.logout, color: Colors.white70)
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 10),

                      // PROFILE IMAGE & INFO
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.primaryYellow, width: 3)
                        ),
                        child: CircleAvatar(
                          radius: 45,
                          backgroundColor: Colors.grey.shade800,
                          backgroundImage: (mentorImage.isNotEmpty && mentorImage.startsWith('http')) 
                              ? NetworkImage(mentorImage) 
                              : null,
                          child: (mentorImage.isEmpty || !mentorImage.startsWith('http'))
                             ? Text(
                                  mentorName.isNotEmpty ? mentorName[0].toUpperCase() : "M", 
                                  style: const TextStyle(fontSize: 30, color: AppColors.primaryYellow, fontWeight: FontWeight.bold)
                                )
                             : null,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(mentorName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                      Text(mentorEmail, style: TextStyle(fontSize: 14, color: Colors.grey.shade400)),
                      
                      const SizedBox(height: 15),

                      // ACTIVE SKILLS CHIPS (Updated from API)
                      if (skillsList.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: skillsList.take(3).map((skill) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: AppColors.primaryYellow.withOpacity(0.3))
                                ),
                                child: Text(skill, style: const TextStyle(color: AppColors.primaryYellow, fontSize: 11, fontWeight: FontWeight.bold)),
                              );
                            }).toList(),
                          ),
                        )
                      else
                        const Text("No active skills listed", style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
                
                // --- 2. LIVE STATS CARD (Firebase & API) ---
                if (mentorId.isNotEmpty)
                  Positioned(
                    bottom: -50, left: 20, right: 20,
                    child: StreamBuilder<QuerySnapshot>(
                      // Firebase logic: Is Mentor ki chat room ke messages suno
                      stream: FirebaseFirestore.instance.collection('chat_rooms').doc(mentorId).collection('messages').snapshots(),
                      builder: (context, snapshot) {
                        String studentQueries = "0";
                        String totalMsgs = "0";
                        
                        if (snapshot.hasData) {
                          var docs = snapshot.data!.docs;
                          
                          // Logic: Total Interactions = Sab messages (Mentor + Student)
                          totalMsgs = docs.length.toString(); 

                          // Logic: Pending/Student Queries = Sirf Student ke messages (jo Mentor ne nahi bheje)
                          int studentMsgsCount = docs.where((d) {
                             // Check data exist krta ha ya nahi crash se bachne k liye
                             var data = d.data() as Map<String, dynamic>;
                             return data.containsKey('senderId') && data['senderId'] != mentorId;
                          }).length;

                          studentQueries = studentMsgsCount.toString();
                        }

                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 8))
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _statItem(totalMsgs, "Total Queries", Icons.chat_bubble_outline),
                              _verticalLine(),
                              // 'Pending' ka mtlb Students k msg
                              _statItem(studentQueries, "Pending Reply", Icons.mark_chat_unread_outlined), 
                              _verticalLine(),
                              // Rating API se aa rahi hai
                              _statItem(mentorRating, "Rating", Icons.star_rounded, isRating: true),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 70), 

            // --- 3. QUICK ACTIONS GRID (No Changes here) ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Quick Actions", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryBlack)),
                  const SizedBox(height: 15),
                  
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: size.width > 600 ? 4 : 2, 
                    crossAxisSpacing: 15,
                    mainAxisSpacing: 15,
                    childAspectRatio: 1.0,
                    children: [
                      // Chat
                      _actionCard(
                        "Go to Chat", "Reply students", Icons.forum_outlined, 
                        Colors.blue.shade50, Colors.blue.shade700,
                        () {
                          if (mentorId.isNotEmpty) {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(roomId: mentorId, chatTitle: "$mentorName's Room", chatImage: mentorImage)));
                          }
                        }
                      ),
                      // Add Course
                      _actionCard(
                        "Add Course", "Upload lectures", Icons.video_library_outlined, 
                        Colors.orange.shade50, Colors.orange.shade800,
                        () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LaunchCourseScreen()))
                      ),
                      
                      // Add Quiz
                      _actionCard(
                        "Add Quiz", "Create tests", Icons.quiz_outlined, 
                        Colors.purple.shade50, Colors.purple.shade700,
                        () => Navigator.push(context, MaterialPageRoute(builder: (context) => CreateQuizScreen(mentorName: mentorName)))
                      ),
                      
                      // Update Skills
                      _actionCard(
                        "Update Skills", "Edit Profile", Icons.settings_suggest_outlined, 
                        Colors.green.shade50, Colors.green.shade700,
                        () async {
                           await Navigator.push(context, MaterialPageRoute(builder: (context) => const MentorProfileScreen()));
                           _loadLocalData(); // Refresh on return
                           _fetchDashboardData();
                        }
                      ),
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- HELPERS ---
  
  Widget _statItem(String value, String label, IconData icon, {bool isRating = false}) {
    return Column(
      children: [
        Icon(icon, size: 24, color: isRating ? Colors.orange : AppColors.primaryYellow),
        const SizedBox(height: 5),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryBlack)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _verticalLine() => Container(height: 30, width: 1, color: Colors.grey.shade200);

  Widget _actionCard(String title, String subtitle, IconData icon, Color bgColor, Color iconColor, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.grey.shade100, blurRadius: 8, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primaryBlack)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ],
            )
          ],
        ),
      ),
    );
  }
}