import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/app_colors.dart';
import 'quiz_attempt_screen.dart'; // Next step ma banayenge

class StudentQuizListScreen extends StatefulWidget {
  const StudentQuizListScreen({super.key});

  @override
  State<StudentQuizListScreen> createState() => _StudentQuizListScreenState();
}

class _StudentQuizListScreenState extends State<StudentQuizListScreen> {
  List<dynamic> _quizzes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchQuizzes();
  }

  // --- FETCH QUIZZES FROM SERVER ---
  Future<void> _fetchQuizzes() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String uId = prefs.getString('userId') ?? "0";

    try {
      // API check karegi ke student ne konsa quiz attempt kiya hai
      var response = await http.get(Uri.parse('https://techrisepk.com/mentor/quiz/get_quizzes.php?student_id=$uId'));
      
      if (response.statusCode == 200) {
        var json = jsonDecode(response.body);
        if (json['status'] == 'success') {
          setState(() {
            _quizzes = json['data'];
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print("Error: $e");
      setState(() => _isLoading = false);
    }
  }

  // --- REFRESH LOGIC (Jab wapis aye to list update ho) ---
  void _goToQuizAttempt(Map<String, dynamic> quiz) async {
    bool? result = await Navigator.push(
      context, 
      MaterialPageRoute(
        builder: (context) => QuizAttemptScreen(
          quizId: quiz['id'].toString(), 
          quizTitle: quiz['title']
        )
      )
    );

    if (result == true) {
      _fetchQuizzes(); // Refresh list to show new score
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("All Quizzes", style: TextStyle(color: AppColors.primaryYellow, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primaryBlack,
        iconTheme: const IconThemeData(color: AppColors.primaryYellow),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: AppColors.primaryBlack))
        : _quizzes.isEmpty 
           ? _buildEmptyState()
           : ListView.builder(
               padding: const EdgeInsets.all(15),
               itemCount: _quizzes.length,
               itemBuilder: (context, index) {
                 var quiz = _quizzes[index];
                 // API se 'is_attempted' (1 or 0) aur 'obtained_score' ana chahiye
                 bool isAttempted = quiz['is_attempted'] == 1 || quiz['is_attempted'] == '1';
                 String score = quiz['obtained_score'].toString();
                 String totalMarks = quiz['total_marks']?.toString() ?? "?"; // Agar API bhej rahi hai

                 return Card(
                   margin: const EdgeInsets.only(bottom: 15),
                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                   elevation: 3,
                   child: Padding(
                     padding: const EdgeInsets.all(20),
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         // Title & Badge
                         Row(
                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
                           children: [
                             Expanded(
                               child: Text(
                                 quiz['title'], 
                                 style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryBlack)
                               ),
                             ),
                             if (isAttempted)
                               Container(
                                 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                 decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(10)),
                                 child: const Text("Completed", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                               )
                             else
                               Container(
                                 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                 decoration: BoxDecoration(color: AppColors.primaryYellow.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                                 child: const Text("New", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)),
                               )
                           ],
                         ),
                         const SizedBox(height: 5),
                         Text(quiz['description'] ?? "No description", style: TextStyle(color: Colors.grey.shade600)),
                         
                         const SizedBox(height: 20),
                         const Divider(),
                         const SizedBox(height: 10),

                         // Action Button / Result
                         isAttempted 
                         ? Row(
                             children: [
                               const Icon(Icons.emoji_events, color: AppColors.primaryYellow),
                               const SizedBox(width: 10),
                               Text("Your Score: $score", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                             ],
                           )
                         : SizedBox(
                             width: double.infinity,
                             child: ElevatedButton(
                               onPressed: () => _goToQuizAttempt(quiz),
                               style: ElevatedButton.styleFrom(
                                 backgroundColor: AppColors.primaryBlack,
                                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                 padding: const EdgeInsets.symmetric(vertical: 12)
                               ),
                               child: const Text("START QUIZ", style: TextStyle(color: AppColors.primaryYellow, fontWeight: FontWeight.bold)),
                             ),
                           )
                       ],
                     ),
                   ),
                 );
               },
             ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 20),
          const Text("No Quizzes Available", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
        ],
      ),
    );
  }
}