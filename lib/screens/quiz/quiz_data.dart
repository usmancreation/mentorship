class QuestionModel {
  String questionText;
  String option1;
  String option2;
  String option3;
  String option4;
  int correctOption; // 1, 2, 3, or 4

  QuestionModel({
    required this.questionText,
    required this.option1,
    required this.option2,
    required this.option3,
    required this.option4,
    required this.correctOption,
  });

  // Server ko data bhejne ke liye JSON convert
  Map<String, dynamic> toJson() {
    return {
      'question': questionText,
      'option_1': option1,
      'option_2': option2,
      'option_3': option3,
      'option_4': option4,
      'correct_option': correctOption,
    };
  }
}