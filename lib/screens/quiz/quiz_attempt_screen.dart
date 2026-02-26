import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/app_colors.dart';
import 'quiz_result_screen.dart'; // Next step mein banayenge

class QuizAttemptScreen extends StatefulWidget {
  final String quizId;
  final String quizTitle;

  const QuizAttemptScreen({super.key, required this.quizId, required this.quizTitle});

  @override
  State<QuizAttemptScreen> createState() => _QuizAttemptScreenState();
}

class _QuizAttemptScreenState extends State<QuizAttemptScreen> {
  List<dynamic> _questions = [];
  int _currentIndex = 0;
  int _score = 0;
  bool _isLoading = true;
  
  // Logic Control Variables
  bool _isAnswerLocked = false;
  int? _selectedOption;
  int? _correctOption;

  @override
  void initState() {
    super.initState();
    _fetchQuestions();
  }

  // --- 1. FETCH QUESTIONS ---
  Future<void> _fetchQuestions() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String uId = prefs.getString('userId') ?? "0";

    try {
      var response = await http.get(Uri.parse('https://techrisepk.com/mentor/quiz/get_quiz_questions.php?quiz_id=${widget.quizId}&student_id=$uId'));
      
      if (response.statusCode == 200) {
        var json = jsonDecode(response.body);
        if (json['status'] == 'success') {
          setState(() {
            _questions = json['data'];
            _isLoading = false;
          });
        } else {
          // Agar already attempted hai ya koi error hai
          if(mounted) {
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(json['message'])));
             Navigator.pop(context);
          }
        }
      }
    } catch (e) {
      print("Error: $e");
    }
  }

  // --- 2. HANDLE ANSWER SELECTION ---
  void _submitAnswer(int selectedOption) {
    if (_isAnswerLocked) return; // Prevent multiple clicks

    int correct = int.parse(_questions[_currentIndex]['correct_option'].toString());
    
    setState(() {
      _isAnswerLocked = true;
      _selectedOption = selectedOption;
      _correctOption = correct;
      
      if (selectedOption == correct) {
        _score++; // Score barhao
      }
    });

    // --- 3. AUTO NEXT QUESTION (2 Seconds Delay) ---
    Timer(const Duration(seconds: 2), () {
      if (_currentIndex < _questions.length - 1) {
        setState(() {
          _currentIndex++;
          _isAnswerLocked = false;
          _selectedOption = null;
          _correctOption = null;
        });
      } else {
        _finishQuiz();
      }
    });
  }

  // --- 4. FINISH QUIZ ---
  void _finishQuiz() {
    Navigator.pushReplacement(
      context, 
      MaterialPageRoute(
        builder: (context) => QuizResultScreen(
          score: _score, 
          totalQuestions: _questions.length, 
          quizId: widget.quizId
        )
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.primaryBlack)));
    }

    if (_questions.isEmpty) {
      return const Scaffold(body: Center(child: Text("No questions found in this quiz.")));
    }

    var currentQ = _questions[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.quizTitle, style: const TextStyle(color: AppColors.primaryYellow)),
        backgroundColor: AppColors.primaryBlack,
        iconTheme: const IconThemeData(color: AppColors.primaryYellow),
        automaticallyImplyLeading: false, // Back button disabled during quiz
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Progress Bar
            LinearProgressIndicator(
              value: (_currentIndex + 1) / _questions.length,
              backgroundColor: Colors.grey.shade200,
              color: AppColors.primaryYellow,
              minHeight: 6,
            ),
            const SizedBox(height: 20),
            
            // Question Counter
            Text(
              "Question ${_currentIndex + 1}/${_questions.length}",
              style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            // Question Text
            Text(
              currentQ['question'],
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primaryBlack),
            ),
            const SizedBox(height: 30),

            // Options List
            Expanded(
              child: Column(
                children: [
                  _buildOptionCard(1, currentQ['option_1']),
                  _buildOptionCard(2, currentQ['option_2']),
                  _buildOptionCard(3, currentQ['option_3']),
                  _buildOptionCard(4, currentQ['option_4']),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildOptionCard(int optionId, String optionText) {
    Color bgColor = Colors.white;
    Color borderColor = Colors.grey.shade300;
    IconData? icon;
    Color iconColor = Colors.transparent;

    if (_isAnswerLocked) {
      if (optionId == _correctOption) {
        // Sahi Jawab -> Green
        bgColor = Colors.green.shade50;
        borderColor = Colors.green;
        icon = Icons.check_circle;
        iconColor = Colors.green;
      } else if (optionId == _selectedOption) {
        // Ghalat Select Kiya -> Red
        bgColor = Colors.red.shade50;
        borderColor = Colors.red;
        icon = Icons.cancel;
        iconColor = Colors.red;
      }
    }

    return GestureDetector(
      onTap: () => _submitAnswer(optionId),
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: borderColor, width: 2),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                optionText, 
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)
              ),
            ),
            if (icon != null)
              Icon(icon, color: iconColor)
          ],
        ),
      ),
    );
  }
}