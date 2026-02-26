import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_colors.dart';
import '../widgets/fade_in_slide.dart'; 
import 'login_screen.dart';
import 'mentor_registration_screen.dart';
import 'mentor_dashboard_screen.dart'; 
import 'chat_screen.dart'; 
import '../services/token_service.dart'; 
import 'features/student_courses_list.dart';
import 'quiz/student_quiz_list.dart'; 

// [ADDED] Notification Screen Import (Make sure file exists)
import 'notifications/notification_list_screen.dart'; 

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController(); 

  // --- USER DATA ---
  String userName = "Loading...";
  String userEmail = "Loading...";
  String userImage = "";
  bool isMentor = false; 
  
  // [ADDED] Notification Count Variable
  int _unreadNotificationCount = 0;

  // --- Categories ---
  final List<String> categories = ["All", "Development", "Design", "Marketing", "Business", "AI & Data"];
  int selectedCategoryIndex = 0;

  // --- MENTORS DATA ---
  List<dynamic> mentors = [];          
  List<dynamic> filteredMentors = []; 
  bool _isLoadingMentors = true;

  @override
  void initState() {
    super.initState();
    TokenService.updateTokenToServer(); 
    _loadUserData();
    _loadCachedMentors(); 
    _fetchMentorsFromApi(); 
    
    // [ADDED] App start hotay hi notification check karo
    _fetchUnreadNotifications(); 
  }

  Future<void> _loadUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      userName = prefs.getString('userName') ?? "Student";
      userEmail = prefs.getString('userEmail') ?? "student@example.com";
      userImage = prefs.getString('userImage') ?? "";
      
      String? mentorId = prefs.getString('mentorId');
      isMentor = (mentorId != null && mentorId.isNotEmpty); 
    });
  }

  // [ADDED] Notification Count Fetcher Logic
  Future<void> _fetchUnreadNotifications() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    // Jo user login hai (Student ya Mentor) uski ID uthao
    String userId = prefs.getString('userId') ?? prefs.getString('mentorId') ?? "0";

    try {
      var response = await http.post(
        Uri.parse('https://techrisepk.com/mentor/notifications/get_notifications.php'),
        body: {'user_id': userId}
      );

      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(response.body);
        if (jsonResponse['status'] == 'success') {
          if (mounted) {
            setState(() {
              _unreadNotificationCount = jsonResponse['unread_count'] ?? 0;
            });
          }
        }
      }
    } catch (e) {
      print("Notification Check Error: $e");
    }
  }

  // --- CACHE LOGIC ---
  Future<void> _loadCachedMentors() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? cachedData = prefs.getString('cachedMentors');
    if (cachedData != null) {
      if (mounted) {
        setState(() {
          mentors = json.decode(cachedData);
          filteredMentors = mentors; 
          _isLoadingMentors = false;
        });
        _runFilter(); 
      }
    }
  }

  // --- API FETCH LOGIC ---
  Future<void> _fetchMentorsFromApi() async {
    try {
      var response = await http.get(Uri.parse('https://techrisepk.com/mentor/mentorauth/get_approved_mentors.php'));
      
      if (response.statusCode == 200) {
        var jsonResponse = json.decode(response.body);
        if (jsonResponse['status'] == 'success') {
          if (mounted) {
            setState(() {
              mentors = jsonResponse['data'];
              _runFilter(); 
              _isLoadingMentors = false;
            });
          }
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString('cachedMentors', json.encode(mentors));
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingMentors = false);
    }
  }

  // --- FILTER LOGIC ---
  void _runFilter() {
    String query = _searchController.text.toLowerCase();
    String selectedCategory = categories[selectedCategoryIndex];

    setState(() {
      filteredMentors = mentors.where((mentor) {
        String name = mentor['full_name'].toString().toLowerCase();
        String skills = (mentor['skills'] ?? "").toString().toLowerCase(); 

        bool matchesCategory = (selectedCategory == "All") 
            ? true 
            : skills.contains(selectedCategory.toLowerCase());

        bool matchesSearch = query.isEmpty 
            ? true 
            : (name.contains(query) || skills.contains(query));

        return matchesCategory && matchesSearch;
      }).toList();
    });
  }

  Future<void> _logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear(); 
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginScreen()), (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      drawer: _buildDrawer(),
      body: RefreshIndicator( 
        onRefresh: () async {
          await _fetchMentorsFromApi();
          await _fetchUnreadNotifications(); // Refresh pr notification count bhi update hoga
        },
        color: AppColors.primaryYellow,
        backgroundColor: AppColors.primaryBlack,
        child: Column(
          children: [
            // --- HEADER ---
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: size.height * 0.28,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryBlack,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(40),
                      bottomRight: Radius.circular(40),
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                                icon: const Icon(Icons.menu, color: AppColors.primaryYellow, size: 28),
                              ),
                              
                              // [UPDATED] Bell Icon with Red Dot/Number
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  IconButton(
                                    onPressed: () async {
                                      // Click krne pr Notification List Screen pr jao
                                      await Navigator.push(
                                        context, 
                                        MaterialPageRoute(builder: (c) => const NotificationListScreen())
                                      );
                                      // Wapis anay par count refresh kro (Red dot hat jaye)
                                      _fetchUnreadNotifications(); 
                                    },
                                    icon: const Icon(Icons.notifications_none, color: AppColors.primaryYellow, size: 28),
                                  ),
                                  
                                  // Agar notifications hain to Red Badge dikhao
                                  if (_unreadNotificationCount > 0)
                                    Positioned(
                                      right: 11,
                                      top: 11,
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: AppColors.primaryBlack, width: 1.5)
                                        ),
                                        constraints: const BoxConstraints(
                                          minWidth: 16,
                                          minHeight: 16,
                                        ),
                                        child: Text(
                                          _unreadNotificationCount > 9 ? '9+' : '$_unreadNotificationCount',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    )
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          const FadeInSlide(delay: 0.1, child: Text("Find Your", style: TextStyle(color: Colors.white, fontSize: 24))),
                          const FadeInSlide(delay: 0.2, child: Text("Perfect Mentor", style: TextStyle(color: AppColors.primaryYellow, fontSize: 32, fontWeight: FontWeight.bold))),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -25, left: 24, right: 24,
                  child: FadeInSlide(
                    delay: 0.3,
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 5))],
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) => _runFilter(), 
                        decoration: InputDecoration(
                          hintText: "Search by Name or Skills...",
                          hintStyle: TextStyle(color: Colors.grey.shade400),
                          prefixIcon: const Icon(Icons.search, color: AppColors.primaryBlack),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 40),

            // --- BODY ---
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(), 
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- CATEGORIES ---
                    SizedBox(
                      height: 50,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        itemCount: categories.length,
                        itemBuilder: (context, index) {
                          bool isSelected = index == selectedCategoryIndex;
                          return FadeInSlide(
                            delay: 0.4 + (index * 0.1),
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  selectedCategoryIndex = index;
                                });
                                _runFilter(); 
                              },
                              child: Container(
                                margin: const EdgeInsets.only(right: 12),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.primaryBlack : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(30),
                                  border: isSelected ? Border.all(color: AppColors.primaryYellow, width: 1) : null,
                                ),
                                child: Center(
                                  child: Text(categories[index], style: TextStyle(color: isSelected ? AppColors.primaryYellow : Colors.grey.shade600, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 25),

                    // Title
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: FadeInSlide(
                        delay: 0.5,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Top Mentors", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryBlack)),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 15),

                    // --- MENTORS LIST ---
                    _isLoadingMentors 
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primaryBlack))
                    : filteredMentors.isEmpty 
                      ? const Padding(padding: EdgeInsets.all(20.0), child: Center(child: Text("No mentors found matching your skills.")))
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          itemCount: filteredMentors.length,
                          itemBuilder: (context, index) {
                            final mentor = filteredMentors[index];
                            
                            String skillsRaw = (mentor['skills'] ?? "").toString();
                            String role = "Mentor"; 
                            
                            if (skillsRaw.isNotEmpty && skillsRaw != "null") {
                                role = skillsRaw.replaceAll(',', ' • ');
                            }

                            String image = mentor['profile_image'];
                            
                            String rating = "0.0";
                            if (mentor['rating'] != null) {
                              rating = mentor['rating'].toString();
                              if(rating.length > 3) rating = rating.substring(0, 3);
                            }
                            
                            String count = mentor['response_count'] ?? "0";

                            return FadeInSlide(
                              delay: 0.6 + (index * 0.1),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: AppColors.primaryYellow, width: 2.0),
                                  boxShadow: [BoxShadow(color: Colors.grey.shade100, blurRadius: 10, offset: const Offset(0, 5))],
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center, 
                                  children: [
                                    Container(
                                      height: 70, width: 70,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(15),
                                        image: DecorationImage(image: NetworkImage(image), fit: BoxFit.cover),
                                      ),
                                    ),
                                    const SizedBox(width: 15),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(mentor['full_name'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryBlack)),
                                          const SizedBox(height: 4),
                                          
                                          Text(
                                            role, 
                                            style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.2),
                                            maxLines: 2, 
                                            overflow: TextOverflow.ellipsis, 
                                          ),
                                          
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              const Icon(Icons.star, color: AppColors.primaryYellow, size: 16),
                                              const SizedBox(width: 4),
                                              Text(rating, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                              const SizedBox(width: 10),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green.shade100)),
                                                child: Text("$count Sessions", style: TextStyle(fontSize: 10, color: Colors.green.shade800, fontWeight: FontWeight.bold)),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    
                                    // CHAT BUTTON
                                    PulsingChatButton(
                                      onTap: () {
                                          Navigator.push(context, MaterialPageRoute(
                                          builder: (context) => ChatScreen(
                                            roomId: mentor['id'].toString(), 
                                            chatTitle: mentor['full_name'], 
                                            chatImage: mentor['profile_image'],
                                          )
                                          )).then((_) async {
                                            await Future.delayed(const Duration(milliseconds: 500));
                                            _fetchMentorsFromApi();
                                          });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: AppColors.primaryBlack),
            accountName: Text(userName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryYellow)),
            accountEmail: Text(userEmail, style: const TextStyle(color: Colors.white70)),
            currentAccountPicture: CircleAvatar(
              backgroundColor: AppColors.primaryYellow,
              backgroundImage: (userImage.isNotEmpty && userImage != "null") ? NetworkImage(userImage) : null,
              child: (userImage.isEmpty || userImage == "null") ? const Icon(Icons.person, size: 40, color: AppColors.primaryBlack) : null,
            ),
          ),
          _drawerItem(Icons.dashboard_outlined, "Dashboard", () => Navigator.pop(context)),
          _drawerItem(Icons.calendar_month_outlined, "My Sessions", () {}),
          _drawerItem(Icons.menu_book_outlined, "Courses", () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const StudentCoursesList()));
          }),
          
          _drawerItem(Icons.quiz_outlined, "Quiz", () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const StudentQuizListScreen())); 
          }),
          
          _drawerItem(Icons.verified_outlined, "Apply as Mentor", () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const MentorRegistrationScreen())); 
          }),
          _drawerItem(Icons.settings_outlined, "Settings", () {}),
          const Spacer(),
          const Divider(),
          
          if (isMentor) 
            _drawerItem(Icons.workspace_premium, "Mentor Dashboard", () async {
              Navigator.pop(context);
              await Navigator.push(context, MaterialPageRoute(builder: (context) => const MentorDashboardScreen()));
              _loadUserData(); 
            }, isHighlighted: true),
            
          _drawerItem(Icons.logout, "Logout", _logout, isLogout: true),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _drawerItem(IconData icon, String title, VoidCallback onTap, {bool isLogout = false, bool isHighlighted = false}) {
    Color textColor = isLogout ? Colors.red : (isHighlighted ? AppColors.primaryYellow : AppColors.primaryBlack);
    Color iconColor = isLogout ? Colors.red : (isHighlighted ? AppColors.primaryYellow : AppColors.primaryBlack);
    return ListTile(
      tileColor: isHighlighted ? AppColors.primaryBlack : null,
      leading: Icon(icon, color: iconColor),
      title: Text(title, style: TextStyle(color: textColor, fontWeight: (isLogout || isHighlighted) ? FontWeight.bold : FontWeight.w500)),
      onTap: onTap,
    );
  }
}

// --- ANIMATED CHAT BUTTON ---
class PulsingChatButton extends StatefulWidget {
  final VoidCallback onTap;
  const PulsingChatButton({required this.onTap, super.key});

  @override
  State<PulsingChatButton> createState() => _PulsingChatButtonState();
}

class _PulsingChatButtonState extends State<PulsingChatButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          height: 50, width: 50,
          decoration: BoxDecoration(
            color: AppColors.primaryBlack,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(color: AppColors.primaryYellow.withOpacity(0.4), blurRadius: 8, spreadRadius: 1)
            ]
          ),
          child: const Icon(Icons.chat_bubble_outline, color: AppColors.primaryYellow, size: 24),
        ),
      ),
    );
  }
}