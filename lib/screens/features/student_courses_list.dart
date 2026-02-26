import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/app_colors.dart';
import 'course_player_screen.dart';

class StudentCoursesList extends StatefulWidget {
  const StudentCoursesList({super.key});

  @override
  State<StudentCoursesList> createState() => _StudentCoursesListState();
}

class _StudentCoursesListState extends State<StudentCoursesList> {
  Map<String, List<dynamic>> groupedCourses = {};
  Map<String, Map<String, dynamic>> courseStats = {}; // Stores stats like 3/10, 30%
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLocalData(); 
    _fetchCoursesFromServer();
  }

  Future<void> _loadLocalData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? cachedData = prefs.getString('cached_courses');
    if (cachedData != null) {
      _processData(jsonDecode(cachedData));
    }
  }

  Future<void> _fetchCoursesFromServer() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String uId = prefs.getString('userId') ?? "0";

    try {
      var response = await http.get(
        Uri.parse('https://techrisepk.com/mentor/courses/get_courses.php?student_id=$uId')
      );

      if (response.statusCode == 200) {
        var json = jsonDecode(response.body);
        if (json['status'] == 'success') {
          await prefs.setString('cached_courses', response.body);
          _processData(json);
        }
      }
    } catch (e) {
      print("Network Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _processData(dynamic json) {
    List<dynamic> data = json['data'];
    Map<String, List<dynamic>> tempGroup = {};
    Map<String, Map<String, dynamic>> tempStats = {};

    // 1. Grouping by Course Title
    for (var item in data) {
      String title = item['title'];
      if (!tempGroup.containsKey(title)) tempGroup[title] = [];
      tempGroup[title]!.add(item);
    }

    // 2. Calculating Statistics (3/10, Percentage, etc.)
    tempGroup.forEach((title, lectures) {
      int total = lectures.length;
      int completed = 0;
      String mentorName = "Mentor";
      String description = "No description";

      for (var lec in lectures) {
        // Check if completed (1 or '1')
        if (lec['is_completed'] == 1 || lec['is_completed'] == '1') {
          completed++;
        }
        // Capture metadata from first lecture
        mentorName = lec['mentor_name'] ?? "Mentor";
        description = lec['description'] ?? ""; // We can use first lec desc as course desc or handle differently
      }

      double progress = total == 0 ? 0.0 : (completed / total);
      
      tempStats[title] = {
        'total': total,
        'completed': completed,
        'progress': progress,
        'mentor': mentorName,
        'desc': description, // Using simple logic for desc
      };
    });

    if (mounted) {
      setState(() {
        groupedCourses = tempGroup;
        courseStats = tempStats;
        _isLoading = false;
      });
    }
  }

  void _navigateAndRefresh(BuildContext context, dynamic lecture, String title) async {
    await Navigator.push(context, MaterialPageRoute(
      builder: (context) => CoursePlayerScreen(
        videoId: lecture['video_id'], 
        courseId: lecture['id'].toString(), 
        title: title, 
        desc: lecture['description']
      )
    ));
    _fetchCoursesFromServer();
  }

  @override
  Widget build(BuildContext context) {
    List<String> titles = groupedCourses.keys.toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("MY LEARNING", style: TextStyle(color: AppColors.primaryYellow, fontWeight: FontWeight.bold, letterSpacing: 1)),
        backgroundColor: AppColors.primaryBlack,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.primaryYellow),
      ),
      body: _isLoading && titles.isEmpty
        ? const Center(child: CircularProgressIndicator(color: AppColors.primaryBlack))
        : titles.isEmpty 
           ? const Center(child: Text("No courses enrolled yet.", style: TextStyle(color: Colors.grey)))
           : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: titles.length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 20),
              itemBuilder: (context, index) {
                String title = titles[index];
                List<dynamic> lectures = groupedCourses[title]!;
                var stats = courseStats[title]!;
                
                double progressVal = stats['progress'];
                int completedCount = stats['completed'];
                int totalCount = stats['total'];
                String mentor = stats['mentor'];
                
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
                    ]
                  ),
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                      // --- COURSE HEADER ---
                      title: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Mentor Row
                          Row(
                            children: [
                              const Icon(Icons.person_outline, size: 14, color: AppColors.primaryBlack),
                              const SizedBox(width: 5),
                              Text(mentor.toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 5),
                          // Title
                          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primaryBlack)),
                          const SizedBox(height: 8),
                          // Stats Row (3/10 and Bar)
                          Row(
                            children: [
                              Text(
                                "$completedCount/$totalCount", 
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primaryBlack)
                              ),
                              const SizedBox(width: 5),
                              Text("Lessons", style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                              const Spacer(),
                              Text(
                                "${(progressVal * 100).toInt()}%",
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryBlack)
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Linear Progress Bar
                          ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: LinearProgressIndicator(
                              value: progressVal,
                              backgroundColor: Colors.grey.shade100,
                              color: AppColors.primaryYellow,
                              minHeight: 6,
                            ),
                          )
                        ],
                      ),
                      // --- LECTURES LIST ---
                      children: lectures.map((lecture) {
                        bool isDone = lecture['is_completed'] == 1 || lecture['is_completed'] == '1';
                        
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            border: Border(top: BorderSide(color: Colors.grey.shade200))
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            onTap: () => _navigateAndRefresh(context, lecture, title),
                            // Lecture Title
                            title: Text(
                              lecture['description'],
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: isDone ? Colors.grey : AppColors.primaryBlack
                              ),
                            ),
                            // Trailing: Circle Progress Indicator for Lecture
                            trailing: Container(
                              height: 24,
                              width: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDone ? AppColors.primaryYellow : Colors.transparent,
                                border: Border.all(
                                  color: isDone ? AppColors.primaryYellow : Colors.grey.shade300,
                                  width: 2
                                )
                              ),
                              child: isDone 
                                ? const Icon(Icons.check, size: 14, color: AppColors.primaryBlack)
                                : null,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                );
              },
            ),
    );
  }
}