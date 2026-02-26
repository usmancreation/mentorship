import 'mentor_login_screen.dart'; // <--- YE IMPORT ADD KAREIN
import 'dart:io'; // Image File ke liye
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // Image Picker
import 'package:http/http.dart' as http; // API Request ke liye
import '../utils/app_colors.dart';
import '../widgets/fade_in_slide.dart';

class MentorRegistrationScreen extends StatefulWidget {
  const MentorRegistrationScreen({super.key});

  @override
  State<MentorRegistrationScreen> createState() => _MentorRegistrationScreenState();
}

class _MentorRegistrationScreenState extends State<MentorRegistrationScreen> {
  // Controllers
  final _fullNameController = TextEditingController();
  final _rollNoController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _customSkillController = TextEditingController(); // For 'Other' input

  File? _imageFile; // Image Variable
  bool _isLoading = false;
  bool _showCustomSkillInput = false; // Toggle for Other Input

  // --- SKILLS DATA ---
  final List<String> _allSkills = ["Flutter", "Web Dev", "Graphic Design", "SEO", "Marketing", "Content Writing", "AI/ML", "Cyber Security"];
  final List<String> _selectedSkills = [];

  // --- IMAGE PICKER ---
  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) setState(() => _imageFile = File(pickedFile.path));
  }

  // --- SUBMIT LOGIC (REAL API) ---
  Future<void> _registerMentor() async {
    // 1. Validation
    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please upload a profile picture")));
      return;
    }
    if (_fullNameController.text.isEmpty || _rollNoController.text.isEmpty || _emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all fields")));
      return;
    }

    // Skills Merging (Selected Chips + Custom Input)
    List<String> finalSkills = List.from(_selectedSkills);
    if (_customSkillController.text.isNotEmpty) {
      finalSkills.add(_customSkillController.text);
    }

    if (finalSkills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Select at least one skill")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 2. API Request
      // NOTE: Make sure URL is correct according to your folder structure
      var uri = Uri.parse('https://techrisepk.com/mentor/mentorauth/mentor_register.php');
      var request = http.MultipartRequest('POST', uri);

      // Add Text Fields
      request.fields['full_name'] = _fullNameController.text;
      request.fields['roll_no'] = _rollNoController.text;
      request.fields['email'] = _emailController.text;
      request.fields['password'] = _passwordController.text;
      request.fields['skills'] = finalSkills.join(', '); // Convert List to String

      // Add Image File
      var pic = await http.MultipartFile.fromPath('profile_image', _imageFile!.path);
      request.files.add(pic);

      // Send Request
      var response = await request.send();
      var respStr = await response.stream.bytesToString();

      print("Server Response: $respStr"); // Debugging ke liye

      if (response.statusCode == 200) {
        setState(() => _isLoading = false);
        
        // Check if PHP returned success
        if (respStr.contains("success")) {
           _showSuccessDialog();
        } else {
           // Server returned 200 but logic failed (e.g., db error)
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Registration Failed: $respStr")));
        }
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Server Error. Try again later.")));
      }

    } catch (e) {
      print("Error: $e");
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Connection Error. Check Internet.")));
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.primaryBlack,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Icon(Icons.check_circle, color: AppColors.primaryYellow, size: 60),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text("Registration Successful", style: TextStyle(color: AppColors.primaryYellow, fontWeight: FontWeight.bold, fontSize: 20)),
            SizedBox(height: 10),
            Text(
              "Your application has been received. You will receive a confirmation message on your email once approved.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
        actions: [
          Center(
            child: TextButton(
              onPressed: () {
                Navigator.pop(context); // Close Dialog
                Navigator.pop(context); // Go Back to Home
              },
              child: const Text("OK, GOT IT", style: TextStyle(color: AppColors.primaryYellow, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBlack, // Dark Theme
      body: Stack(
        children: [
          // --- YELLOW HEADER CURVE ---
          Positioned(
            top: 0, left: 0, right: 0,
            height: MediaQuery.of(context).size.height * 0.25,
            child: ClipPath(
              clipper: HeaderCurveClipper(),
              child: Container(
                color: AppColors.primaryYellow,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Icon(Icons.arrow_back, color: AppColors.primaryBlack),
                        ),
                        const Spacer(),
                        const Text("Become a Mentor", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primaryBlack)),
                        const Text("Join the elite team of mentors", style: TextStyle(fontSize: 16, color: AppColors.primaryBlack)),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // --- FORM SECTION ---
          Positioned.fill(
            top: MediaQuery.of(context).size.height * 0.22,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  
                  // 1. Image Picker
                  const SizedBox(height: 10),
                  FadeInSlide(
                    delay: 0.1,
                    child: Center(
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundColor: Colors.grey.withOpacity(0.2),
                              backgroundImage: _imageFile != null ? FileImage(_imageFile!) : null,
                              child: _imageFile == null 
                                  ? const Icon(Icons.person, size: 50, color: Colors.grey) 
                                  : null,
                            ),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(color: AppColors.primaryYellow, shape: BoxShape.circle),
                              child: const Icon(Icons.camera_alt, size: 20, color: AppColors.primaryBlack),
                            )
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 25),

                  // 2. Basic Info
                  FadeInSlide(delay: 0.2, child: _buildDarkInput(_fullNameController, "Full Name", Icons.person)),
                  const SizedBox(height: 15),
                  FadeInSlide(delay: 0.3, child: _buildDarkInput(_rollNoController, "Student Roll No", Icons.badge)),
                  const SizedBox(height: 15),
                  FadeInSlide(delay: 0.4, child: _buildDarkInput(_emailController, "Valid Email Address", Icons.email)),
                  const SizedBox(height: 15),
                  FadeInSlide(delay: 0.5, child: _buildDarkInput(_passwordController, "Set Password", Icons.lock, isPass: true)),

                  const SizedBox(height: 25),

                  // 3. Skills Section (Custom Chips)
                  const FadeInSlide(
                    delay: 0.6, 
                    child: Text("Select Your Expertise", style: TextStyle(color: AppColors.primaryYellow, fontWeight: FontWeight.bold, fontSize: 16))
                  ),
                  const SizedBox(height: 12),
                  
                  FadeInSlide(
                    delay: 0.7,
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        ..._allSkills.map((skill) => _buildCustomChip(skill)),
                        _buildOtherChip(), // "Other" option
                      ],
                    ),
                  ),

                  // 4. Custom Skill Input
                  if (_showCustomSkillInput) ...[
                    const SizedBox(height: 15),
                    FadeInSlide(
                      delay: 0.1, 
                      child: _buildDarkInput(_customSkillController, "Type your skill here...", Icons.edit)
                    ),
                  ],

                  const SizedBox(height: 40),

                  // 5. Register Button
                  FadeInSlide(
                    delay: 0.8,
                    child: GestureDetector(
                      onTap: _isLoading ? null : _registerMentor,
                      child: Container(
                        height: 55,
                        decoration: BoxDecoration(
                          color: AppColors.primaryYellow,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [BoxShadow(color: AppColors.primaryYellow.withOpacity(0.3), blurRadius: 10)],
                        ),
                        child: Center(
                          child: _isLoading 
                          ? const CircularProgressIndicator(color: AppColors.primaryBlack)
                          : const Text("REGISTER AS MENTOR", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryBlack)),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 6. Already Registered Option
                 // ... (File ka neechay wala hissa)

                  // 6. Already Registered Option
                  FadeInSlide(
                    delay: 0.9,
                    child: Center(
                      child: GestureDetector(
                        onTap: () {
                          // --- YE LOGIC UPDATE KAREIN ---
                          // Pehle hum sirf pop kr rahy thy, ab hum Login Screen par bhejen gay
                          Navigator.pushReplacement(
                            context, 
                            MaterialPageRoute(builder: (context) => const MentorLoginScreen())
                          );
                        },
                        child: const Text(
                          "Already a Mentor? Login Here", 
                          style: TextStyle(color: Colors.grey, decoration: TextDecoration.underline)
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
// ...
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- CUSTOM WIDGETS ---

  Widget _buildDarkInput(TextEditingController controller, String hint, IconData icon, {bool isPass = false}) {
    return TextField(
      controller: controller,
      obscureText: isPass,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.grey.withOpacity(0.15),
        prefixIcon: Icon(icon, color: Colors.grey),
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade600),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide(color: AppColors.primaryYellow.withOpacity(0.5))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: const BorderSide(color: Colors.white24)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: const BorderSide(color: AppColors.primaryYellow)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    );
  }

  // Custom Chip Widget
  Widget _buildCustomChip(String label) {
    bool isSelected = _selectedSkills.contains(label);
    
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedSkills.remove(label);
          } else {
            _selectedSkills.add(label);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryYellow : Colors.grey.withOpacity(0.15),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isSelected ? AppColors.primaryYellow : Colors.transparent,
            width: 1
          )
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.primaryBlack : Colors.white70,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  // Other Chip Logic
  Widget _buildOtherChip() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showCustomSkillInput = !_showCustomSkillInput; // Toggle Input
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: _showCustomSkillInput ? AppColors.primaryYellow.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: AppColors.primaryYellow),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Other +", 
              style: TextStyle(
                color: AppColors.primaryYellow, 
                fontWeight: FontWeight.bold
              )
            ),
          ],
        ),
      ),
    );
  }
}

class HeaderCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.lineTo(0, size.height - 50);
    path.quadraticBezierTo(size.width / 2, size.height + 20, size.width, size.height - 50);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }
  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}