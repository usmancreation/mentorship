import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../utils/app_colors.dart';
import '../widgets/fade_in_slide.dart'; // Animation Widget
import 'login_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  final _dobController = TextEditingController();
  File? _imageFile;
  bool _isLoading = false;

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) setState(() => _imageFile = File(pickedFile.path));
  }

  Future<void> _selectDate() async {
    DateTime? picked = await showDatePicker(
      context: context, 
      initialDate: DateTime(2005), 
      firstDate: DateTime(1950), 
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryYellow, // Header background color
              onPrimary: AppColors.primaryBlack, // Header text color
              onSurface: Colors.white, // Body text color
            ),
            dialogBackgroundColor: AppColors.primaryBlack,
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _dobController.text = DateFormat('yyyy-MM-dd').format(picked));
  }

  Future<void> _registerUser() async {
    if (_nameController.text.isEmpty || _emailController.text.isEmpty || _passController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all fields")));
      return;
    }
    setState(() => _isLoading = true);
    try {
      var request = http.MultipartRequest('POST', Uri.parse('https://techrisepk.com/mentor/studentauth/signup.php'));
      request.fields['full_name'] = _nameController.text;
      request.fields['email'] = _emailController.text;
      request.fields['password'] = _passController.text;
      request.fields['dob'] = _dobController.text;
      if (_imageFile != null) request.files.add(await http.MultipartFile.fromPath('profile_image', _imageFile!.path));

      var response = await request.send();
      var respStr = await response.stream.bytesToString();
      var jsonResponse = json.decode(respStr);
      if (jsonResponse['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.green, content: Text("Account Created!")));
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: Colors.red, content: Text(jsonResponse['message'])));
      }
    } catch (e) {
      print("Error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.primaryBlack, 
      body: Stack(
        children: [
          // --- TOP YELLOW SECTION ---
          Positioned(
            top: 0, left: 0, right: 0,
            height: size.height * 0.35,
            child: Stack(
              children: [
                ClipPath(
                  clipper: TopCurveClipper(),
                  child: Container(color: AppColors.primaryYellow, height: double.infinity),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const FadeInSlide(delay: 0.1, child: Text("Existing user?", style: TextStyle(color: AppColors.primaryBlack, fontSize: 16))),
                        const SizedBox(height: 10),
                        FadeInSlide(
                          delay: 0.2,
                          child: GestureDetector(
                            onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen())),
                            child: Container(
                              width: 120, height: 40,
                              decoration: BoxDecoration(color: AppColors.primaryBlack, borderRadius: BorderRadius.circular(20)),
                              child: const Center(child: Text("LOGIN", style: TextStyle(color: AppColors.primaryYellow, fontWeight: FontWeight.bold))),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // --- BOTTOM FORM SECTION ---
          Positioned(
            top: size.height * 0.32, left: 0, right: 0, bottom: 0,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const FadeInSlide(delay: 0.3, child: Text("Sign up with", style: TextStyle(color: Colors.white70, fontSize: 14))),
                  const FadeInSlide(delay: 0.4, child: Text("MENTORSHIP", style: TextStyle(color: AppColors.primaryYellow, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 1))),
                  
                  const SizedBox(height: 30),

                  FadeInSlide(
                    delay: 0.5,
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Center(
                        child: CircleAvatar(
                          radius: 35,
                          backgroundColor: Colors.grey.shade800,
                          backgroundImage: _imageFile != null ? FileImage(_imageFile!) : null,
                          child: _imageFile == null ? const Icon(Icons.camera_alt, color: AppColors.primaryYellow) : null,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  FadeInSlide(delay: 0.6, child: _buildDarkInput(_nameController, "Full Name")),
                  const SizedBox(height: 16),
                  FadeInSlide(delay: 0.7, child: _buildDarkInput(_emailController, "Email")),
                  const SizedBox(height: 16),
                  FadeInSlide(delay: 0.8, child: GestureDetector(onTap: _selectDate, child: AbsorbPointer(child: _buildDarkInput(_dobController, "Date of Birth")))),
                  const SizedBox(height: 16),
                  FadeInSlide(delay: 0.9, child: _buildDarkInput(_passController, "Password", isPass: true)),

                  const SizedBox(height: 30),

                  FadeInSlide(
                    delay: 1.0,
                    child: GestureDetector(
                      onTap: _isLoading ? null : _registerUser,
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: AppColors.primaryYellow,
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [BoxShadow(color: AppColors.primaryYellow.withOpacity(0.3), blurRadius: 10)],
                        ),
                        child: Center(
                          child: _isLoading 
                          ? const CircularProgressIndicator(color: AppColors.primaryBlack)
                          : const Text("SIGN UP", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryBlack)),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Social Icons (Optional Placeholder)
                  const FadeInSlide(
                    delay: 1.1,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Add icons here if needed
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDarkInput(TextEditingController controller, String hint, {bool isPass = false}) {
    return TextField(
      controller: controller,
      obscureText: isPass,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.grey.withOpacity(0.15),
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold),
        // Border color matched with yellow
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: const BorderSide(color: AppColors.primaryYellow)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    );
  }
}

class TopCurveClipper extends CustomClipper<Path> {
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