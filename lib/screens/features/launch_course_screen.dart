import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../../utils/app_colors.dart';
// [ADDED] Notification Service Import
import '../../services/notification_service.dart';

class LaunchCourseScreen extends StatefulWidget {
  const LaunchCourseScreen({super.key});

  @override
  State<LaunchCourseScreen> createState() => _LaunchCourseScreenState();
}

class _LaunchCourseScreenState extends State<LaunchCourseScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _linkController = TextEditingController();
  
  bool _isLoading = false;
  bool _isNewCourse = true; 
  String? _selectedExistingCourse; 
  
  List<String> _myExistingCoursesTitles = []; // For Dropdown
  List<dynamic> _myFullUploads = []; // For Manage List
  
  @override
  void initState() {
    super.initState();
    _fetchMyCourses();
  }

  // --- 1. FETCH COURSES & POPULATE LIST ---
  Future<void> _fetchMyCourses() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String mName = prefs.getString('mentorName') ?? ""; 

    try {
      var response = await http.get(Uri.parse('https://techrisepk.com/mentor/courses/get_courses.php'));
      
      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(response.body);
        if (jsonResponse['status'] == 'success') {
          List<dynamic> allCourses = jsonResponse['data'];
          
          Set<String> uniqueTitles = {};
          List<dynamic> myUploads = [];

          // Filter courses for this mentor
          for (var c in allCourses) {
            if (c['mentor_name'].toString().toLowerCase() == mName.toLowerCase()) {
              uniqueTitles.add(c['title']);
              myUploads.add(c);
            }
          }

          if(mounted) {
            setState(() {
              _myExistingCoursesTitles = uniqueTitles.toList();
              _myFullUploads = myUploads; // Save full list for "Manage" section

              // Auto-select first course if available
              if (_myExistingCoursesTitles.isNotEmpty && _selectedExistingCourse == null) {
                _selectedExistingCourse = _myExistingCoursesTitles[0];
              }
            });
          }
        }
      }
    } catch (e) {
      print("Fetch Error: $e");
    }
  }

  // --- 2. DELETE LECTURE LOGIC (Optional) ---
  Future<void> _deleteLecture(String courseId) async {
    // Confirmation Dialog
    bool confirm = await showDialog(
      context: context, 
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Lecture?"),
        content: const Text("Are you sure you want to remove this lecture?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      )
    ) ?? false;

    if(!confirm) return;

    setState(() => _isLoading = true);
    
    // API Call to delete (Backend file required: delete_course.php)
    try {
      var response = await http.post(
        Uri.parse('https://techrisepk.com/mentor/courses/delete_course.php'),
        body: {'id': courseId}
      );

      if(response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lecture Deleted!")));
        _fetchMyCourses(); // Refresh list
      } else {
        // Fallback for UI if API is not ready
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Request sent (Backend pending)")));
        _fetchMyCourses();
      }
    } catch(e) {
      // Just refresh for demo if API fails
      _fetchMyCourses();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // --- 3. PUBLISH LOGIC ---
  Future<void> _publishCourse() async {
    if (!_isNewCourse && _myExistingCoursesTitles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No existing courses found. Please create a New Course.")));
      return;
    }

    String finalCourseTitle = _isNewCourse ? _titleController.text.trim() : _selectedExistingCourse!;
    
    if (finalCourseTitle.isEmpty || _linkController.text.trim().isEmpty || _descController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("All fields are required")));
      return;
    }

    String rawInput = _linkController.text.trim();
    String finalVideoId = YoutubePlayer.convertUrlToId(rawInput) ?? rawInput;

    if (finalVideoId.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid YouTube Link or ID!")));
      return;
    }

    setState(() => _isLoading = true);
    
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String mId = prefs.getString('mentorId') ?? "0";
    String mName = prefs.getString('mentorName') ?? "Mentor";

    try {
      var response = await http.post(
        Uri.parse('https://techrisepk.com/mentor/courses/add_course.php'),
        body: {
          'mentor_id': mId,
          'mentor_name': mName,
          'title': finalCourseTitle, 
          'description': _descController.text.trim(),
          'video_url': finalVideoId,
        }
      );
      
      if(response.statusCode == 200) {
         _descController.clear();
         _linkController.clear();
         if(_isNewCourse) _titleController.clear();
         
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lecture Added Successfully!")));
         
         // --- [UPDATED] TRIGGER NOTIFICATION ---
         // Ye code sab students ko alert bhejega
         try {
           await NotificationService.sendNotification(
             senderRole: 'mentor', 
             roomId: '0', // '0' ka matlab Broadcast (Sab students)
             title: "New Course Alert! 🎓", 
             body: "Mentor $mName just uploaded a lecture in '$finalCourseTitle'",
             type: "course"
           );
         } catch(notifError) {
           print("Notification Error: $notifError");
         }
         // -------------------------------------

         _fetchMyCourses(); // Update list immediately
      } else {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Server Error: ${response.statusCode}")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Network Error")));
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Grouping Logic for UI
    Map<String, List<dynamic>> groupedUploads = {};
    for (var item in _myFullUploads) {
      String t = item['title'];
      if (!groupedUploads.containsKey(t)) groupedUploads[t] = [];
      groupedUploads[t]!.add(item);
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Launch Content", style: TextStyle(color: AppColors.primaryYellow, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primaryBlack,
        iconTheme: const IconThemeData(color: AppColors.primaryYellow),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- HEADER ---
            const Text("UPLOAD LECTURE", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primaryBlack), textAlign: TextAlign.center),
            const SizedBox(height: 25),
            
            // --- TOGGLE SWITCH ---
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade300)),
              child: Row(
                children: [
                  Expanded(child: _toggleButton("New Course", _isNewCourse, () => setState(() => _isNewCourse = true))),
                  Expanded(child: _toggleButton("Add Existing", !_isNewCourse, () => setState(() => _isNewCourse = false))),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // --- INPUT FORMS ---
            if (_isNewCourse)
              _buildInput(_titleController, "Course Name (e.g. Flutter Mastery)", Icons.folder_open)
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50, borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: AppColors.primaryBlack)
                ),
                child: _myExistingCoursesTitles.isEmpty 
                  ? const Padding(padding: EdgeInsets.all(15), child: Center(child: Text("No courses found.", style: TextStyle(color: Colors.red))))
                  : DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _selectedExistingCourse,
                        items: _myExistingCoursesTitles.map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
                        onChanged: (val) => setState(() => _selectedExistingCourse = val),
                      ),
                    ),
              ),

            const SizedBox(height: 15),
            _buildInput(_descController, "Lecture Title (e.g. Class 1)", Icons.description),
            const SizedBox(height: 15),
            _buildInput(_linkController, "YouTube Video Link or ID", Icons.video_library),
            
            const SizedBox(height: 30),
            
            // --- PUBLISH BUTTON ---
            ElevatedButton(
              onPressed: _isLoading ? null : _publishCourse,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlack,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                elevation: 5,
              ),
              child: _isLoading 
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: AppColors.primaryYellow, strokeWidth: 2))
                : const Text("PUBLISH NOW", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryYellow, letterSpacing: 1)),
            ),

            const SizedBox(height: 40),
            const Divider(thickness: 2),
            const SizedBox(height: 20),

            // --- MANAGE COURSES SECTION ---
            Row(
              children: [
                const Icon(Icons.dashboard_customize, color: AppColors.primaryBlack),
                const SizedBox(width: 10),
                const Text("YOUR LIBRARY", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryBlack)),
                const Spacer(),
                Text("${_myFullUploads.length} Lectures", style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 15),

            // --- COURSE LIST ---
            groupedUploads.isEmpty 
            ? Container(
                padding: const EdgeInsets.all(30),
                alignment: Alignment.center,
                child: const Text("You haven't uploaded any courses yet.", style: TextStyle(color: Colors.grey)),
              )
            : ListView.builder(
                shrinkWrap: true, // Important inside SingleChildScrollView
                physics: const NeverScrollableScrollPhysics(),
                itemCount: groupedUploads.length,
                itemBuilder: (context, index) {
                  String courseTitle = groupedUploads.keys.elementAt(index);
                  List<dynamic> lectures = groupedUploads[courseTitle]!;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 15),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 5, offset: const Offset(0,3))]
                    ),
                    child: Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                        backgroundColor: Colors.transparent,
                        collapsedBackgroundColor: Colors.transparent,
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: AppColors.primaryYellow.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.folder, color: AppColors.primaryBlack),
                        ),
                        title: Text(courseTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primaryBlack)),
                        subtitle: Text("${lectures.length} Lectures", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        children: lectures.map((lecture) {
                          return Container(
                            decoration: BoxDecoration(
                              border: Border(top: BorderSide(color: Colors.grey.shade100))
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.only(left: 20, right: 10),
                              leading: const Icon(Icons.play_circle_fill, size: 20, color: Colors.grey),
                              title: Text(lecture['description'], style: const TextStyle(fontSize: 14)),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                                onPressed: () => _deleteLecture(lecture['id'].toString()),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  );
                },
              )
          ],
        ),
      ),
    );
  }

  // --- HELPERS ---
  Widget _toggleButton(String text, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primaryBlack : Colors.transparent, 
          borderRadius: BorderRadius.circular(10)
        ),
        child: Center(
          child: Text(
            text, 
            style: TextStyle(
              color: isActive ? AppColors.primaryYellow : Colors.grey, 
              fontWeight: FontWeight.bold
            )
          )
        ),
      ),
    );
  }

  Widget _buildInput(TextEditingController controller, String hint, IconData icon, {int maxLines = 1}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50, 
        borderRadius: BorderRadius.circular(15), 
        border: Border.all(color: AppColors.primaryBlack, width: 1.5)
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: AppColors.primaryBlack), 
          hintText: hint, 
          hintStyle: TextStyle(color: Colors.grey.shade400),
          border: InputBorder.none, 
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)
        ),
      ),
    );
  }
}