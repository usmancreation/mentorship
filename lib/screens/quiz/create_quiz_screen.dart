import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/app_colors.dart';
import 'quiz_data.dart'; 

class CreateQuizScreen extends StatefulWidget {
  final String mentorName;
  const CreateQuizScreen({super.key, required this.mentorName});

  @override
  State<CreateQuizScreen> createState() => _CreateQuizScreenState();
}

class _CreateQuizScreenState extends State<CreateQuizScreen> {
  final _quizTitleController = TextEditingController();
  final _quizDescController = TextEditingController();

  List<QuestionModel> _questions = [];
  List<dynamic> _myPublishedQuizzes = []; // Server se aaye purane quizzes
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchMyPublishedQuizzes();
  }

  // --- 1. FETCH EXISTING QUIZZES (Library) ---
  Future<void> _fetchMyPublishedQuizzes() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    // Note: API wohi use kar rahay hain, bas filter lagayenge agar zaroorat pari
    // Ideal ye hai ke server par 'get_mentor_quizzes.php' ho, magar hum 'get_quizzes.php' use krke filter kr skty hain
    // Filhal assuming endpoint returns list.
    try {
      var response = await http.get(Uri.parse('https://techrisepk.com/mentor/quiz/get_quizzes.php'));
      if (response.statusCode == 200) {
        var json = jsonDecode(response.body);
        if (json['status'] == 'success') {
          List<dynamic> allData = json['data'];
          // Filter logic: Sirf is mentor ke quizzes show hon
          // (Agar server filter nahi kar raha to yahan check lagana behtar hai)
           /* String mId = prefs.getString('mentorId') ?? "";
           var myData = allData.where((q) => q['mentor_id'].toString() == mId).toList();
           */
          setState(() {
            _myPublishedQuizzes = allData; // Abhi ke liye sab dikha rahay hain
          });
        }
      }
    } catch (e) {
      print("Fetch Error: $e");
    }
  }

  // --- 2. DELETE EXISTING QUIZ ---
  Future<void> _deleteQuiz(String quizId) async {
    bool confirm = await _showConfirmDialog();
    if (!confirm) return;

    setState(() => _isLoading = true);
    // API Call to delete quiz (Backend file: delete_quiz.php honi chahiye)
    // Filhal UI se remove kar dete hain for demo
    try {
       // await http.post(...)
       setState(() {
         _myPublishedQuizzes.removeWhere((q) => q['id'].toString() == quizId);
       });
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Quiz Deleted!")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error deleting quiz")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<bool> _showConfirmDialog() async {
    return await showDialog(
      context: context, 
      builder: (c) => AlertDialog(
        title: const Text("Delete Quiz?"),
        content: const Text("This cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      )
    ) ?? false;
  }


  // --- 3. PROFESSIONAL ADD QUESTION DIALOG ---
  void _showAddQuestionDialog() {
    final qController = TextEditingController();
    final op1Controller = TextEditingController();
    final op2Controller = TextEditingController();
    final op3Controller = TextEditingController();
    final op4Controller = TextEditingController();
    int _selectedCorrectOption = 1; 

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Add Question", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.grey))
                        ],
                      ),
                      const Divider(),
                      const SizedBox(height: 10),

                      // Question Input
                      _buildDialogTextField(qController, "Type your question here...", Icons.help, maxLines: 2),
                      const SizedBox(height: 20),
                      
                      const Text("Options (Tap circle to mark correct)", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 10),

                      // Professional Option Rows
                      _buildModernOption(1, op1Controller, _selectedCorrectOption, (val) => setDialogState(() => _selectedCorrectOption = val)),
                      _buildModernOption(2, op2Controller, _selectedCorrectOption, (val) => setDialogState(() => _selectedCorrectOption = val)),
                      _buildModernOption(3, op3Controller, _selectedCorrectOption, (val) => setDialogState(() => _selectedCorrectOption = val)),
                      _buildModernOption(4, op4Controller, _selectedCorrectOption, (val) => setDialogState(() => _selectedCorrectOption = val)),

                      const SizedBox(height: 20),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlack,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                        ),
                        onPressed: () {
                          if (qController.text.isEmpty || op1Controller.text.isEmpty || op2Controller.text.isEmpty) return;
                          setState(() {
                            _questions.add(QuestionModel(
                              questionText: qController.text.trim(),
                              option1: op1Controller.text.trim(),
                              option2: op2Controller.text.trim(),
                              option3: op3Controller.text.trim(),
                              option4: op4Controller.text.trim(),
                              correctOption: _selectedCorrectOption,
                            ));
                          });
                          Navigator.pop(context);
                        },
                        child: const Text("ADD TO LIST", style: TextStyle(color: AppColors.primaryYellow, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- 4. PUBLISH ---
  Future<void> _publishQuiz() async {
    if (_quizTitleController.text.isEmpty || _questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Title and Questions are required")));
      return;
    }

    setState(() => _isLoading = true);
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String mId = prefs.getString('mentorId') ?? "0";

    Map<String, dynamic> requestBody = {
      'mentor_id': mId,
      'title': _quizTitleController.text.trim(),
      'description': _quizDescController.text.trim(),
      'questions': _questions.map((q) => q.toJson()).toList(),
    };

    try {
      var response = await http.post(
        Uri.parse('https://techrisepk.com/mentor/quiz/add_quiz.php'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestBody),
      );

      var json = jsonDecode(response.body);
      if (json['status'] == 'success') {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Quiz Published!"), backgroundColor: Colors.green));
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${json['message']}")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Network Error")));
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Quiz Manager", style: TextStyle(color: AppColors.primaryYellow, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primaryBlack,
        iconTheme: const IconThemeData(color: AppColors.primaryYellow),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- HEADER: CREATE NEW ---
            const Text("CREATE NEW QUIZ", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryBlack)),
            const SizedBox(height: 15),
            _buildMainInput(_quizTitleController, "Quiz Title (e.g. Flutter Basics)", Icons.title),
            const SizedBox(height: 10),
            _buildMainInput(_quizDescController, "Description (Optional)", Icons.description, maxLines: 2),
            
            const SizedBox(height: 20),

            // --- ADD QUESTION BUTTON ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("${_questions.length} Questions Added", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                ElevatedButton.icon(
                  onPressed: _showAddQuestionDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: AppColors.primaryBlack),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: 0
                  ),
                  icon: const Icon(Icons.add_circle, color: AppColors.primaryBlack),
                  label: const Text("Add Question", style: TextStyle(color: AppColors.primaryBlack)),
                )
              ],
            ),
            const SizedBox(height: 10),

            // --- QUESTIONS LIST (DRAFTS) ---
            _questions.isEmpty 
             ? Container(
                 padding: const EdgeInsets.all(30),
                 alignment: Alignment.center,
                 decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200)),
                 child: const Text("Start adding questions to build your quiz.", style: TextStyle(color: Colors.grey)),
               )
             : ListView.builder(
                 shrinkWrap: true,
                 physics: const NeverScrollableScrollPhysics(),
                 itemCount: _questions.length,
                 itemBuilder: (ctx, i) => _buildQuestionCard(i, _questions[i]),
               ),

            const SizedBox(height: 25),
            
            // PUBLISH BUTTON
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading || _questions.isEmpty ? null : _publishQuiz,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryYellow,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                ),
                child: _isLoading 
                 ? const CircularProgressIndicator(color: Colors.black)
                 : const Text("PUBLISH QUIZ NOW", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),

            const SizedBox(height: 40),
            const Divider(thickness: 2),
            const SizedBox(height: 20),

            // --- LIBRARY SECTION (PREVIOUS QUIZZES) ---
            const Text("YOUR PUBLISHED QUIZZES", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryBlack)),
            const SizedBox(height: 15),

            _myPublishedQuizzes.isEmpty
              ? const Padding(padding: EdgeInsets.all(20), child: Center(child: Text("No published quizzes yet.", style: TextStyle(color: Colors.grey))))
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _myPublishedQuizzes.length,
                  itemBuilder: (context, index) {
                    var q = _myPublishedQuizzes[index];
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: AppColors.primaryBlack.withOpacity(0.1), shape: BoxShape.circle),
                          child: const Icon(Icons.quiz, color: AppColors.primaryBlack),
                        ),
                        title: Text(q['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(q['description'] ?? "No description"),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => _deleteQuiz(q['id'].toString()),
                        ),
                      ),
                    );
                  },
                ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  // --- WIDGETS ---

  // 1. New Question Card Design
  Widget _buildQuestionCard(int index, QuestionModel q) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.grey.shade100, blurRadius: 5, offset: const Offset(0, 3))]
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
        leading: Container(
          width: 30, height: 30,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: AppColors.primaryBlack, shape: BoxShape.circle),
          child: Text("${index + 1}", style: const TextStyle(color: AppColors.primaryYellow, fontWeight: FontWeight.bold)),
        ),
        title: Text(q.questionText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text("Correct Answer: Option ${q.correctOption}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.redAccent),
          onPressed: () => setState(() => _questions.removeAt(index)),
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            color: Colors.grey.shade50,
            child: Column(
              children: [
                _buildPreviewOption(1, q.option1, q.correctOption),
                _buildPreviewOption(2, q.option2, q.correctOption),
                _buildPreviewOption(3, q.option3, q.correctOption),
                _buildPreviewOption(4, q.option4, q.correctOption),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildPreviewOption(int id, String text, int correctId) {
    bool isCorrect = id == correctId;
    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isCorrect ? Colors.green.withOpacity(0.1) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isCorrect ? Colors.green : Colors.grey.shade300)
      ),
      child: Row(
        children: [
          Icon(isCorrect ? Icons.check_circle : Icons.circle_outlined, size: 16, color: isCorrect ? Colors.green : Colors.grey),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(color: isCorrect ? Colors.green[800] : Colors.black87, fontWeight: isCorrect ? FontWeight.bold : FontWeight.normal))),
        ],
      ),
    );
  }

  // 2. Modern Dialog Option Input
  Widget _buildModernOption(int id, TextEditingController controller, int groupVal, Function(int) onTap) {
    bool isSelected = id == groupVal;
    return GestureDetector(
      onTap: () => onTap(id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryYellow.withOpacity(0.1) : Colors.grey.shade50,
          border: Border.all(color: isSelected ? AppColors.primaryYellow : Colors.grey.shade300, width: isSelected ? 2 : 1),
          borderRadius: BorderRadius.circular(12)
        ),
        child: Row(
          children: [
            // Custom Radio Circle
            Container(
              height: 20, width: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppColors.primaryYellow : Colors.white,
                border: Border.all(color: isSelected ? AppColors.primaryYellow : Colors.grey)
              ),
              child: isSelected ? const Icon(Icons.check, size: 14, color: Colors.black) : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: "Option $id",
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainInput(TextEditingController controller, String hint, IconData icon, {int maxLines = 1}) {
    return Container(
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade300)),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: AppColors.primaryBlack),
          hintText: hint,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
  
  Widget _buildDialogTextField(TextEditingController controller, String hint, IconData icon, {int maxLines=1}) {
    return Container(
       decoration: BoxDecoration(
         color: Colors.grey.shade50,
         borderRadius: BorderRadius.circular(12),
       ),
       child: TextField(
         controller: controller,
         maxLines: maxLines,
         decoration: InputDecoration(
           prefixIcon: Icon(icon, color: Colors.grey),
           hintText: hint,
           border: InputBorder.none,
           contentPadding: const EdgeInsets.all(15)
         ),
       ),
    );
  }
}