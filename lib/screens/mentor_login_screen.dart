import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_colors.dart';
import '../widgets/fade_in_slide.dart';
import 'home_screen.dart';

class MentorLoginScreen extends StatefulWidget {
  const MentorLoginScreen({super.key});

  @override
  State<MentorLoginScreen> createState() => _MentorLoginScreenState();
}

class _MentorLoginScreenState extends State<MentorLoginScreen> {
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  bool _isLoading = false;

  Future<void> _loginMentor() async {
    if (_emailController.text.isEmpty || _passController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter credentials")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      var response = await http.post(
        Uri.parse('https://techrisepk.com/mentor/mentorauth/mentor_login.php'),
        body: {
          'email': _emailController.text,
          'password': _passController.text
        }
      );

      var jsonResponse = json.decode(response.body);

      if (jsonResponse['status'] == 'success') {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        var mentorData = jsonResponse['mentor'];

        // --- 1. BASIC DATA SAVE ---
        await prefs.setBool('isMentorLoggedIn', true);
        await prefs.setString('mentorId', mentorData['id'].toString());
        await prefs.setString('mentorName', mentorData['name']);
        
        // --- 2. MISSING DATA FIXED HERE ---
        // Email Save
        await prefs.setString('email', mentorData['email'] ?? '');
        
        // Skills Save
        if (mentorData['skills'] != null) {
          await prefs.setString('mentorSkills', mentorData['skills']);
        }

        // Rating Save (Handle Integer or String)
        if (mentorData['rating'] != null) {
          await prefs.setString('mentorRating', mentorData['rating'].toString());
        }

        // Image Logic (Relative Path Fix)
        String img = mentorData['image'] ?? "";
        if (img.isNotEmpty && !img.startsWith('http')) {
           img = "https://techrisepk.com/mentor/uploads/$img"; // Server path adjust karein agar zaroorat ho
        }
        await prefs.setString('mentorImage', img);


        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          backgroundColor: AppColors.primaryYellow,
          duration: Duration(seconds: 2),
          content: Text(
            "Login Successful! Redirecting...", 
            style: TextStyle(color: AppColors.primaryBlack, fontWeight: FontWeight.bold)
          ),
        ));

        Future.delayed(const Duration(milliseconds: 500), () {
            Navigator.pushAndRemoveUntil(
              context, 
              MaterialPageRoute(builder: (context) => const HomeScreen()), 
              (route) => false 
            );
        });

      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: Colors.red,
          content: Text(jsonResponse['message']),
        ));
      }

    } catch (e) {
      print("Error: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Connection Error")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: SizedBox(
          height: size.height,
          child: Stack(
            children: [
              // --- 1. BLACK HEADER ---
              Positioned(
                top: 0, left: 0, right: 0,
                height: size.height * 0.40,
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppColors.primaryBlack,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(50),
                      bottomRight: Radius.circular(50),
                    ),
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const FadeInSlide(
                          delay: 0.1,
                          child: Icon(Icons.workspace_premium, size: 60, color: AppColors.primaryYellow),
                        ),
                        const SizedBox(height: 15),
                        const FadeInSlide(
                          delay: 0.2,
                          child: Text(
                            "MENTOR PORTAL",
                            style: TextStyle(
                              fontSize: 28, 
                              fontWeight: FontWeight.bold, 
                              color: Colors.white, 
                              letterSpacing: 1.5
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        const FadeInSlide(
                          delay: 0.3,
                          child: Text(
                            "Login to manage sessions",
                            style: TextStyle(fontSize: 14, color: Colors.white54),
                          ),
                        ),
                        SizedBox(height: size.height * 0.05),
                      ],
                    ),
                  ),
                ),
              ),

              // --- 2. INPUT FIELDS ---
              Positioned(
                top: size.height * 0.35, 
                left: 24, right: 24,
                child: Column(
                  children: [
                    FadeInSlide(
                      delay: 0.4,
                      child: _buildInput(_emailController, "Email Address", Icons.email_outlined),
                    ),

                    const SizedBox(height: 20),

                    FadeInSlide(
                      delay: 0.5,
                      child: _buildInput(_passController, "Password", Icons.lock_outline, isPass: true),
                    ),

                    const SizedBox(height: 40),

                    FadeInSlide(
                      delay: 0.6,
                      child: SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _loginMentor,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryBlack,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            elevation: 5,
                            shadowColor: AppColors.primaryYellow.withOpacity(0.5),
                          ),
                          child: _isLoading 
                          ? const CircularProgressIndicator(color: AppColors.primaryYellow)
                          : const Text(
                              "SECURE LOGIN", 
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryYellow, letterSpacing: 1),
                            ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 25),

                    // --- BACK BUTTON ---
                    FadeInSlide(
                      delay: 0.7,
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (context) => const HomeScreen()),
                            (route) => false,
                          );
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.arrow_back, size: 16, color: Colors.grey),
                            SizedBox(width: 5),
                            Text(
                              "Back to Student Mode",
                              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInput(TextEditingController controller, String hint, IconData icon, {bool isPass = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30), 
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08), 
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPass,
        style: const TextStyle(color: AppColors.primaryBlack),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: AppColors.primaryBlack),
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }
}