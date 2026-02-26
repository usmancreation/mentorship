import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/app_colors.dart';

class StudentQuizList extends StatelessWidget {
  const StudentQuizList({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Active Quizzes"), backgroundColor: AppColors.primaryYellow),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('quizzes').orderBy('timestamp', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          var quizzes = snapshot.data!.docs;
          return ListView.builder(
            itemCount: quizzes.length,
            padding: const EdgeInsets.all(10),
            itemBuilder: (context, index) {
              var data = quizzes[index];
              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const Icon(Icons.quiz, color: AppColors.primaryBlack),
                  title: Text(data['question'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("Posted by: ${data['mentor_name']}"),
                  trailing: ElevatedButton(onPressed: (){}, style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryYellow), child: const Text("Attempt", style: TextStyle(color: Colors.black))),
                ),
              );
            },
          );
        },
      ),
    );
  }
}