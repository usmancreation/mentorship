import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/app_colors.dart';
// [ADDED] Import Notification Service
import '../../services/notification_service.dart'; 

class CreateQuizScreen extends StatefulWidget {
  final String mentorName;
  const CreateQuizScreen({super.key, required this.mentorName});
  @override
  State<CreateQuizScreen> createState() => _CreateQuizScreenState();
}

class _CreateQuizScreenState extends State<CreateQuizScreen> {
  final _questionController = TextEditingController();
  bool _isLoading = false;

  void _uploadQuiz() async {
    if (_questionController.text.isEmpty) return;
    setState(() => _isLoading = true);
    
    // 1. Firebase mein Data Save
    await FirebaseFirestore.instance.collection('quizzes').add({
      'question': _questionController.text,
      'mentor_name': widget.mentorName,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // --- [ADDED] SEND BROADCAST NOTIFICATION ---
    // '0' ID ka matlab hai sab students ko notification milegi
    try {
      await NotificationService.sendNotification(
        senderRole: 'mentor',
        roomId: '0',  // Broadcast ID
        title: "New Quiz Alert! 📝",
        body: "Mentor ${widget.mentorName} posted a new quiz: ${_questionController.text}",
        type: 'quiz', // Type bata di taake sahi icon aye
      );
    } catch (e) {
      print("Notification Error: $e");
    }
    // -------------------------------------------

    if(!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Quiz Posted!")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Create Quiz"), backgroundColor: AppColors.primaryYellow),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(controller: _questionController, decoration: const InputDecoration(labelText: "Quiz Question", border: OutlineInputBorder())),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _uploadQuiz,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlack, padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15)),
              child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("POST QUIZ", style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }
}