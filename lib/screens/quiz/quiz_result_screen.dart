import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/app_colors.dart';

class QuizResultScreen extends StatefulWidget {
  final int score;
  final int totalQuestions;
  final String quizId;

  const QuizResultScreen({
    super.key, 
    required this.score, 
    required this.totalQuestions, 
    required this.quizId
  });

  @override
  State<QuizResultScreen> createState() => _QuizResultScreenState();
}

class _QuizResultScreenState extends State<QuizResultScreen> {
  bool _isSaving = true;

  @override
  void initState() {
    super.initState();
    _saveResultToServer();
  }

  Future<void> _saveResultToServer() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String uId = prefs.getString('userId') ?? "0";

    try {
      var response = await http.post(
        Uri.parse('https://techrisepk.com/mentor/quiz/submit_result.php'),
        body: {
          'student_id': uId,
          'quiz_id': widget.quizId,
          'score': widget.score.toString(),
          'total_questions': widget.totalQuestions.toString(),
        }
      );

      if(response.statusCode == 200) {
        // Success
      }
    } catch (e) {
      print("Error saving result: $e");
    } finally {
      if(mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    double percentage = (widget.score / widget.totalQuestions);
    String message = percentage >= 0.5 ? "Good Job!" : "Keep Trying!";
    Color statusColor = percentage >= 0.5 ? Colors.green : Colors.orange;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                percentage >= 0.5 ? Icons.emoji_events : Icons.sentiment_dissatisfied, 
                size: 100, 
                color: AppColors.primaryYellow
              ),
              const SizedBox(height: 20),
              
              Text(message, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              
              Text(
                "You scored ${widget.score} out of ${widget.totalQuestions}",
                style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
              ),
              
              const SizedBox(height: 40),
              
              _isSaving 
                ? const CircularProgressIndicator(color: AppColors.primaryBlack)
                : SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlack,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                      ),
                      onPressed: () {
                        Navigator.pop(context, true); // True means refresh list
                      }, 
                      child: const Text("BACK TO QUIZZES", style: TextStyle(color: AppColors.primaryYellow, fontWeight: FontWeight.bold)),
                    ),
                  )
            ],
          ),
        ),
      ),
    );
  }
}